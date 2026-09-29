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

/// The day-board fixture with how each booking was made and paid filled in —
/// it was captured before the API sent `source`. Keyed by booking id:
/// G1's arrival and the unassigned booking are walk-ins; the rest are online,
/// G2's arriving guest and G3 have paid, G2's departing guest and the
/// Riverview guest have not.
Map<String, dynamic> _boardWithSources() {
  const sources = {
    '285': ('walk_in', null),
    '286': ('app', 'pending'),
    '287': ('app', 'paid'),
    '288': ('app', 'paid'),
    '289': ('walk_in', null),
    '290': ('app', 'pending'),
  };
  void visit(Object? node) {
    if (node is Map) {
      final entry = sources[node['bookingId']?.toString()];
      if (entry != null) {
        node['source'] = entry.$1;
        node['paymentStatus'] = entry.$2;
      }
      node.values.forEach(visit);
    } else if (node is List) {
      node.forEach(visit);
    }
  }

  final json = _fixture('day_board_2026_09_24.json');
  visit(json);
  return json;
}

Widget _app(Widget home, {Map<String, dynamic>? board}) {
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
        (ref, key) async => DayBoard.fromJson(board ?? _fixture('day_board_2026_09_24.json')),
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

  group('Day detail filters', () {
    // A small phone: 360dp wide.
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const DayDetailScreen(date: '2026-09-24'), board: _boardWithSources()),
      );
      await tester.pumpAndSettle();
    }

    // The second row of chips scrolls sideways when it does not fit.
    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('each guest shows how they booked, and the chips count them', (tester) async {
      await open(tester);

      // G2 (both guests), G3 and Riverview booked online; G1 walked in. The
      // unassigned walk-in is counted but its warning card carries no badge.
      expect(find.text('ຈອງ Online'), findsNWidgets(4));
      expect(find.text('Walk-in'), findsOneWidget);
      expect(find.text('ຈອງ Online · 4'), findsOneWidget);
      expect(find.text('Walk-in · 2'), findsOneWidget);
    });

    testWidgets('the walk-in chip keeps only walk-in guests', (tester) async {
      await open(tester);

      await tester.tap(find.text('Walk-in · 2'));
      await tester.pumpAndSettle();

      expect(find.text('G1'), findsOneWidget);
      expect(find.text('ຍັງບໍ່ໄດ້ກຳນົດເບີຫ້ອງ (1)'), findsOneWidget);
      for (final gone in ['G2', 'G3', 'G4', 'Riverview Room']) {
        expect(find.text(gone), findsNothing);
      }
    });

    testWidgets('"not paid" leaves out walk-ins, then search narrows by phone', (tester) async {
      await open(tester);

      await tapChip(tester, 'ການຈ່າຍ');
      await tester.tap(find.text('ຍັງບໍ່ຈ່າຍ').last);
      await tester.pumpAndSettle();

      // Online and unpaid: G2's departing guest and the Riverview guest.
      expect(find.text('G2'), findsOneWidget);
      expect(find.text('Riverview Room'), findsOneWidget);
      expect(find.text('G1'), findsNothing); // walk-in: payment unknown
      expect(find.text('G3'), findsNothing); // paid

      await tapChip(tester, 'ຄົ້ນຫາ');
      await tester.enterText(find.byType(TextField), '020 5550 1006');
      await tester.pumpAndSettle();

      expect(find.text('Riverview Room'), findsOneWidget);
      expect(find.text('G2'), findsNothing);
    });

    testWidgets('a filter with no match offers to clear everything', (tester) async {
      await open(tester);

      await tester.tap(find.text('Walk-in · 2'));
      await tester.pumpAndSettle();
      await tapChip(tester, 'ຄົ້ນຫາ');
      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pumpAndSettle();

      expect(find.text('ບໍ່ມີລາຍການທີ່ຕົງກັບຕົວກອງນີ້'), findsOneWidget);
      await tester.tap(find.text('ລ້າງຕົວກອງທັງໝົດ'));
      await tester.pumpAndSettle();

      for (final number in ['G1', 'G2', 'G3', 'G4']) {
        expect(find.text(number), findsOneWidget);
      }
      expect(find.byType(TextField), findsNothing);
    });
  });
}
