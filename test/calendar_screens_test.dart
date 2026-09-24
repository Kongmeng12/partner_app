import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/dates.dart';
import 'package:partner_app/models/models.dart';
import 'package:partner_app/providers/data.dart';
import 'package:partner_app/screens/calendar_screen.dart';
import 'package:partner_app/screens/day_detail_screen.dart';
import 'package:partner_app/theme/tokens.dart';

/// The fixtures are real responses captured from the live API for the Kuang Si
/// test property on 2026-09-24: an arrival (G1), a turnover (G2 — one guest
/// leaving, another arriving), a mid-stay guest (G3), a room in maintenance
/// (G4), one booking with no room number, and an unnumbered room type.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

class _FixedMonth extends OccupancyMonth {
  @override
  DateTime build() => DateTime.utc(2026, 9, 1);
}

Widget _app(Widget home) {
  final property = Property.fromJson({'id': '6', 'name': 'Kuang Si Stays'});
  return ProviderScope(
    overrides: [
      propertiesProvider.overrideWith((ref) async => [property]),
      occupancyMonthProvider.overrideWith(_FixedMonth.new),
      monthSummaryProvider.overrideWith(
        (ref, key) async => (_fixture('calendar_month_2026_09.json')['days'] as List)
            .map((e) => CalendarMonthDay.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      ),
      dayBoardProvider.overrideWith(
        (ref, key) async => DayBoard.fromJson(_fixture('day_board_2026_09_24.json')),
      ),
    ],
    child: MaterialApp(theme: buildTheme(), home: home),
  );
}

void main() {
  group('DayBoard model', () {
    final board = DayBoard.fromJson(_fixture('day_board_2026_09_24.json'));
    final day = DateTime.utc(2026, 9, 24);
    final garden = board.roomTypes.first;

    test('resolves each numbered room to the right state', () {
      RoomDayState stateOf(String number) =>
          garden.rooms.firstWhere((r) => r.roomNumber == number).stateOn(day);

      expect(stateOf('G1'), RoomDayState.arriving);
      expect(stateOf('G2'), RoomDayState.turnover);
      expect(stateOf('G3'), RoomDayState.occupied);
      expect(stateOf('G4'), RoomDayState.maintenance);
    });

    test('the same guest reads as staying, not arriving, the next night', () {
      final g1 = garden.rooms.firstWhere((r) => r.roomNumber == 'G1');
      expect(g1.stateOn(DateTime.utc(2026, 9, 25)), RoomDayState.occupied);
    });

    test('flags the booking with no room number and the unnumbered type', () {
      expect(garden.unassigned.single.missingRooms, 1);
      final river = board.roomTypes.last;
      expect(river.hasRoomNumbers, isFalse);
      expect(river.rooms, isEmpty);
      expect(river.bookings.single.guestName, isNotEmpty);
    });
  });

  group('Calendar month screen', () {
    testWidgets('shows how full each day is, with arrivals and departures', (tester) async {
      await tester.pumpWidget(_app(const CalendarScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ກັນຍາ 2026'), findsOneWidget);
      // 24 Sep: 5 of 7 rooms taken.
      expect(find.text('5/7'), findsOneWidget);
      // One tappable cell per day of September.
      expect(find.byType(InkWell), findsAtLeastNWidgets(30));
    });
  });

  group('Day detail screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const DayDetailScreen(date: '2026-09-24')));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every room type and each room with its state', (tester) async {
      await open(tester);

      expect(find.text('Garden Fan Room'), findsOneWidget);
      expect(find.text('Riverview Room'), findsOneWidget);
      for (final number in ['G1', 'G2', 'G3', 'G4']) {
        expect(find.text(number), findsOneWidget);
      }
      // Arrival, mid-stay, and both halves of the turnover.
      expect(find.text('ທ້າວ ສົມຊາຍ ພົມມະຈັນ'), findsOneWidget);
      expect(find.text('ນາງ ດາລາ ຈັນທະວົງ'), findsOneWidget);
      expect(find.text('ອອກ · ນາງ ນົກ ແກ້ວມະນີ'), findsOneWidget);
      expect(find.text('ເຂົ້າ · ທ້າວ ບຸນ ສີວົງ'), findsOneWidget);
      expect(find.text('ບຳລຸງຮັກສາ'), findsOneWidget);
    });

    testWidgets('warns about the booking with no room number', (tester) async {
      await open(tester);

      expect(find.text('ຍັງບໍ່ໄດ້ກຳນົດເບີຫ້ອງ (1)'), findsOneWidget);
      expect(find.text('ຈັດຫ້ອງ'), findsOneWidget);
    });

    testWidgets('an unnumbered room type lists its guests instead of rooms', (tester) async {
      await open(tester);

      expect(find.text('ນາງ ແກ້ວ ວົງດາລາ'), findsOneWidget);
      expect(find.textContaining('ຍັງບໍ່ໄດ້ຕັ້ງເບີຫ້ອງ'), findsOneWidget);
    });

    testWidgets('tapping the departures chip narrows the list to the turnover room', (tester) async {
      await open(tester);

      await tester.tap(find.text('ອອກ').first);
      await tester.pumpAndSettle();

      expect(find.text('G2'), findsOneWidget);
      expect(find.text('G1'), findsNothing);
      expect(find.text('G4'), findsNothing);
      expect(find.text('ຍັງບໍ່ໄດ້ກຳນົດເບີຫ້ອງ (1)'), findsNothing);

      // Tapping again clears the filter.
      await tester.tap(find.text('ອອກ').first);
      await tester.pumpAndSettle();
      expect(find.text('G1'), findsOneWidget);
    });
  });
}
