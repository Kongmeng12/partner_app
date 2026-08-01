@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/api_client.dart';
import 'package:partner_app/core/dates.dart';
import 'package:partner_app/core/token_store.dart';
import 'package:partner_app/models/models.dart';

/// End-to-end checks against a **running** backend.
///
/// The other test files use a scripted server, which proves the client behaves
/// — but not that it agrees with the real API. These drive the app's own
/// ApiClient and models against `npm run dev`, so a field renamed on the server
/// shows up here rather than as an empty screen on a partner's phone.
///
/// Skipped automatically when the API is not running, so `flutter test` stays
/// green on a machine with no backend. To run only these:
///
///   flutter test --tags live
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3100/api',
);

const partnerEmail = 'vintage@laostay.la';
const partnerPassword = 'Partner@2026';

Future<bool> _apiIsUp() async {
  try {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      validateStatus: (_) => true,
    ));
    final res = await dio.get<dynamic>('$baseUrl/health');
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  late ApiClient api;
  var reachable = false;

  setUpAll(() async {
    reachable = await _apiIsUp();
    api = ApiClient(
      tokens: TokenStore(storage: InMemoryKeyValueStore()),
      baseUrl: baseUrl,
    );
    await api.tokens.load();
  });

  test('the API is reachable', () async {
    if (!reachable) {
      markTestSkipped('backend not running at $baseUrl — start it with `npm run dev`');
      return;
    }
    expect(reachable, isTrue);
  });

  test('a partner can sign in and the identity parses', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final res = await api.partnerLogin(partnerEmail, partnerPassword);
    await api.tokens.save(
      access: res['accessToken'] as String,
      refresh: res['refreshToken'] as String,
    );

    final partner = Partner.fromJson(Map<String, dynamic>.from(res['partner'] as Map));
    expect(partner.email, partnerEmail);
    expect(partner.isVerified, isTrue);
    // Ids travel as strings; parsing one into an int is the bug this guards.
    expect(int.tryParse(partner.id), isNotNull);
  });

  test('the dashboard parses and its money adds up', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/dashboard');
    final d = PartnerDashboard(Map<String, dynamic>.from(raw as Map));

    expect(d.occupancyPercent, inInclusiveRange(0, 100));
    // The same identity the backend's smoke suite asserts on payouts.
    expect(d.weekGmv, d.weekCommission + d.weekNet,
        reason: 'gmv must equal commission + net, exactly');
  });

  test('bookings parse, and every total balances', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/bookings', query: {'limit': 50});
    final page = Paged.fromJson(
      Map<String, dynamic>.from(raw as Map),
      BookingSummary.fromJson,
    );

    expect(page.items, isNotEmpty, reason: 'the seed creates bookings for this partner');

    for (final b in page.items) {
      expect(b.code, startsWith('STL-'));
      expect(b.nights, greaterThan(0));
      // Dates are `date` columns: read as UTC, they must produce the same night
      // count the server sent.
      expect(nightsBetween(b.checkIn, b.checkOut), b.nights,
          reason: 'client and server disagree on the length of ${b.code}');
    }
  });

  test('a booking detail exposes only the transitions the API allows', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final list = await api.get<dynamic>('/partner/bookings', query: {'limit': 50});
    final page = Paged.fromJson(
      Map<String, dynamic>.from(list as Map),
      BookingSummary.fromJson,
    );
    final done = page.items.firstWhere(
      (b) => b.status == 'done',
      orElse: () => page.items.first,
    );

    final raw = await api.get<dynamic>('/partner/bookings/${done.id}');
    final detail = BookingDetail(Map<String, dynamic>.from(raw as Map));

    expect(detail.code, done.code);
    expect(detail.subtotal + detail.fee - detail.discount, detail.total,
        reason: 'subtotal + fee - discount must equal total');

    if (detail.status == 'done' || detail.status == 'cancelled') {
      expect(detail.nextStatus, isNull, reason: 'a finished stay has nowhere to go');
      expect(detail.canCancel, isFalse);
    }
  });

  test('properties and their rooms parse', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/properties');
    final properties = mapListOf(raw).map(Property.fromJson).toList();

    expect(properties, isNotEmpty);
    for (final p in properties) {
      expect(p.name, isNotEmpty);
      for (final r in p.rooms) {
        expect(r.basePrice, greaterThan(0));
        expect(r.qty, greaterThan(0));
      }
    }
  });

  test('the pricing calendar returns one entry per night', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/properties');
    final room = mapListOf(raw)
        .map(Property.fromJson)
        .expand((p) => p.rooms)
        .firstWhere((r) => r.isActive);

    final from = todayUtc();
    final to = addDays(from, 7);
    final calRaw = await api.get<dynamic>(
      '/partner/rooms/${room.id}/availability',
      query: {'from': apiDay(from), 'to': apiDay(to)},
    );
    final cal = RoomCalendar.fromJson(Map<String, dynamic>.from(calRaw as Map));

    expect(cal.days.length, 7, reason: 'gaps must be filled, not omitted');
    expect(cal.days.first.date, apiDay(from));
    // The last night is the day before `to` — the range is half-open, like a stay.
    expect(cal.days.last.date, apiDay(addDays(to, -1)));
  });

  test("another partner's booking is not visible", () async {
    if (!reachable) return markTestSkipped('backend not running');

    // Sign in as partner B and try to read partner A's booking.
    final other = ApiClient(
      tokens: TokenStore(storage: InMemoryKeyValueStore()),
      baseUrl: baseUrl,
    );
    await other.tokens.load();
    final res = await other.partnerLogin('homsabay@laostay.la', partnerPassword);
    await other.tokens.save(
      access: res['accessToken'] as String,
      refresh: res['refreshToken'] as String,
    );

    final mine = Paged.fromJson(
      Map<String, dynamic>.from(
          await api.get<dynamic>('/partner/bookings', query: {'limit': 1}) as Map),
      BookingSummary.fromJson,
    );

    await expectLater(
      other.get<dynamic>('/partner/bookings/${mine.items.first.id}'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('chat and notifications answer', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final unread = await api.get<dynamic>('/partner/chat/unread');
    expect(intOf(Map<String, dynamic>.from(unread as Map)['total']), greaterThanOrEqualTo(0));

    final feed = await api.get<dynamic>('/partner/notifications');
    final items = mapListOf(Map<String, dynamic>.from(feed as Map)['items'])
        .map(AppNotification.fromJson)
        .toList();
    for (final n in items) {
      expect(n.title, isNotEmpty);
    }
  });
}
