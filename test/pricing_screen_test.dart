import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/dates.dart';
import 'package:partner_app/models/models.dart';
import 'package:partner_app/providers/data.dart';
import 'package:partner_app/screens/pricing_screen.dart';
import 'package:partner_app/theme/tokens.dart';

/// Records what the pricing screens ask the API to do, instead of doing it.
class _FakeActions extends PartnerActions {
  _FakeActions(super.ref, this.calls);

  final List<String> calls;

  @override
  Future<int> setAvailability({
    required String roomTypeId,
    required DateTime from,
    required DateTime to,
    int? price,
    String? status,
  }) async {
    calls.add('set ${apiDay(from)}..${apiDay(to)} price=$price status=$status');
    return to.difference(from).inDays;
  }

  @override
  Future<int> clearPrices({
    required String roomTypeId,
    required DateTime from,
    required DateTime to,
  }) async {
    calls.add('clear ${apiDay(from)}..${apiDay(to)}');
    return to.difference(from).inDays;
  }

  @override
  Future<void> setBasePrice(RoomType roomType, int price) async {
    calls.add('base $price');
  }
}

final _property = Property.fromJson({
  'id': '6',
  'name': 'Kuang Si Stays',
  'roomTypes': [
    {
      'id': '11',
      'propertyId': '6',
      'name': 'Garden Room',
      'bedType': 'double',
      'basePrice': 350000,
      'maxOccupancy': 2,
      'totalRooms': 5,
      'specialPriceNights': 2,
    },
  ],
});

/// Next month, so every night on screen is in the future whatever today is:
/// the 10th and 11th carry a special price, everything else the base rate.
RoomCalendar _calendar(DateTime month) {
  final days = DateTime.utc(month.year, month.month + 1, 0).day;
  return RoomCalendar(
    roomTypeId: '11',
    days: [
      for (var d = 1; d <= days; d++)
        CalendarDay(
          date: apiDay(DateTime.utc(month.year, month.month, d)),
          price: d == 10 || d == 11 ? 450000 : 350000,
          special: d == 10 || d == 11,
          total: 5,
          held: 0,
          booked: 2,
          available: 3,
          onSale: true,
        ),
    ],
  );
}

/// Pumps [home] on a 360-wide phone and returns the list every API call made
/// from it lands in.
Future<List<String>> _pump(WidgetTester tester, Widget home) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final calls = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        propertiesProvider.overrideWith((ref) async => [_property]),
        roomCalendarProvider.overrideWith((ref, key) async => _calendar(key.month)),
        actionsProvider.overrideWith((ref) => _FakeActions(ref, calls)),
      ],
      child: MaterialApp(theme: buildTheme(), home: home),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

String _nextMonthDay(int day) {
  final t = todayUtc();
  return apiDay(DateTime.utc(t.year, t.month + 1, day));
}

Future<void> _openNextMonth(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_right).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the list shows each base rate and its special nights', (tester) async {
    await _pump(tester, const PricingScreen());

    expect(find.text('ລາຄາຫ້ອງ'), findsOneWidget);
    expect(find.text('Garden Room'), findsOneWidget);
    expect(find.textContaining('₭350,000'), findsOneWidget);
    expect(find.text('ມີລາຄາພິເສດ 2 ຄືນທີ່ຈະມາເຖິງ'), findsOneWidget);
  });

  testWidgets('editing the base rate with a quick +10% saves ₭385,000', (tester) async {
    final calls = await _pump(tester, const PricingScreen());

    await tester.tap(find.text('ແກ້ລາຄາ'));
    await tester.pumpAndSettle();
    expect(find.text('350,000'), findsOneWidget);

    await tester.tap(find.text('+10%'));
    await tester.pumpAndSettle();
    expect(find.text('385,000'), findsOneWidget);

    await tester.tap(find.text('ບັນທຶກ'));
    await tester.pumpAndSettle();
    expect(calls, ['base 385000']);
  });

  testWidgets('tap the first night, tap the last, then price the range', (tester) async {
    final calls = await _pump(tester, const RoomPricingScreen(roomTypeId: '11'));
    await _openNextMonth(tester);

    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.text('ແຕະວັນສຸດທ້າຍ ເພື່ອເລືອກເປັນຊ່ວງ'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.textContaining('· 3 ຄືນ'), findsOneWidget);

    await tester.tap(find.text('ຕັ້ງລາຄາ / ປິດຂາຍ'));
    await tester.pumpAndSettle();
    // All three nights are at the base rate, so it is prefilled.
    expect(find.text('350,000'), findsOneWidget);

    await tester.tap(find.text('+20%'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ບັນທຶກ'));
    await tester.pumpAndSettle();

    // Nights 3–5 inclusive: `to` is the 6th, exclusive like a check-out.
    expect(calls, ['set ${_nextMonthDay(3)}..${_nextMonthDay(6)} price=420000 status=null']);
  });

  testWidgets('back to the base rate removes the special price', (tester) async {
    final calls = await _pump(tester, const RoomPricingScreen(roomTypeId: '11'));
    await _openNextMonth(tester);

    await tester.tap(find.text('10'));
    await tester.pump();
    await tester.tap(find.text('11'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ຕັ້ງລາຄາ / ປິດຂາຍ'));
    await tester.pumpAndSettle();
    expect(find.text('450,000'), findsOneWidget);

    // The chip in the sheet, not the base-rate bar behind it.
    await tester.tap(find.text('ລາຄາປົກກະຕິ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ບັນທຶກ'));
    await tester.pumpAndSettle();

    expect(calls, ['clear ${_nextMonthDay(10)}..${_nextMonthDay(12)}']);
  });

  testWidgets('closing nights alone leaves their price untouched', (tester) async {
    final calls = await _pump(tester, const RoomPricingScreen(roomTypeId: '11'));
    await _openNextMonth(tester);

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ຕັ້ງລາຄາ / ປິດຂາຍ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ບັນທຶກ'));
    await tester.pumpAndSettle();

    expect(calls, ['set ${_nextMonthDay(20)}..${_nextMonthDay(21)} price=null status=closed']);
  });
}
