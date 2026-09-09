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
/// Excluded from the default run, so `flutter test` stays hermetic and green on
/// a machine with no backend. To run them:
///
///   flutter test --tags live --run-skipped
///
/// `--run-skipped` is not optional: the `skip` in dart_test.yaml is what keeps
/// them out of the default run, and selecting the tag does not override it.
/// They also self-skip if nothing answers on $baseUrl.
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

    // One login endpoint serves everyone, so the response carries the account
    // and its role — the business comes from /partner/me.
    final user = Map<String, dynamic>.from(res['user'] as Map);
    expect(user['role'], 'PARTNER');
    expect(user['email'], partnerEmail);

    final raw = await api.get<dynamic>('/partner/me');
    final partner = Partner.fromJson(Map<String, dynamic>.from(raw as Map));
    expect(partner.email, partnerEmail);
    expect(partner.isVerified, isTrue);
    expect(partner.businessName, isNotEmpty);
    // Ids travel as strings; parsing one into an int is the bug this guards.
    expect(int.tryParse(partner.id), isNotNull);
  });

  test('the dashboard parses and its money adds up', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/dashboard');
    final d = PartnerDashboard(Map<String, dynamic>.from(raw as Map));

    expect(d.occupancyPercent, inInclusiveRange(0, 100));
    expect(d.soldTonight, lessThanOrEqualTo(d.capacity),
        reason: 'more rooms sold than exist would be an oversell');
    // The same identity the backend's smoke suite asserts on payouts.
    expect(d.weekGross, d.weekCommission + d.weekNet,
        reason: 'gross must equal commission + net, exactly');
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
      (b) => b.status == 'completed',
      orElse: () => page.items.first,
    );

    final raw = await api.get<dynamic>('/partner/bookings/${done.id}');
    final detail = BookingDetail(Map<String, dynamic>.from(raw as Map));

    expect(detail.code, done.code);
    expect(
      detail.subtotal +
          detail.serviceFee +
          detail.tax +
          detail.cleaningFee -
          detail.discount,
      detail.total,
      reason: 'the booking total must equal the sum of its parts',
    );
    expect(detail.total - detail.commission, detail.payout,
        reason: 'payout must be total minus commission, exactly');

    if (detail.status == 'completed' || detail.status == 'cancelled') {
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
      for (final rt in p.roomTypes) {
        expect(rt.basePrice, greaterThan(0));
        expect(rt.totalRooms, greaterThan(0));
        expect(rt.maxOccupancy, greaterThan(0));
        // Numbered rooms are optional and independent of totalRooms — a room
        // type need not have any — but every one that comes back must carry a
        // real id, number and a known status. A renamed field would otherwise
        // parse silently into an empty string rather than fail loudly here.
        for (final room in rt.rooms) {
          expect(room.id, isNotEmpty);
          expect(room.roomNumber, isNotEmpty);
          expect(['available', 'maintenance', 'inactive'], contains(room.status));
        }
      }
    }
  });

  test('the pricing calendar returns one entry per night', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/properties');
    final roomType = mapListOf(raw)
        .map(Property.fromJson)
        .expand((p) => p.roomTypes)
        .firstWhere((rt) => rt.isActive);

    final from = todayUtc();
    final to = addDays(from, 7);
    final calRaw = await api.get<dynamic>(
      '/partner/room-types/${roomType.id}/calendar',
      query: {'from': apiDay(from), 'to': apiDay(to)},
    );
    final cal = RoomCalendar.fromJson(Map<String, dynamic>.from(calRaw as Map));

    expect(cal.days.length, 7, reason: 'gaps must be filled, not omitted');
    expect(cal.days.first.date, apiDay(from));
    // The last night is the day before `to` — the range is half-open, like a stay.
    expect(cal.days.last.date, apiDay(addDays(to, -1)));

    // The counters the whole booking flow rests on. `available` is a generated
    // column, so this is really checking that it arrived intact rather than
    // that the server can subtract.
    for (final day in cal.days) {
      expect(day.held + day.booked, lessThanOrEqualTo(day.total),
          reason: '${day.date} is oversold');
      expect(day.available, day.total - day.held - day.booked,
          reason: '${day.date}: available must agree with its parts');
      expect(day.price, greaterThan(0), reason: '${day.date} has no price');
    }
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

  // Chat is not in the API yet, so there is nothing here to check — the app's
  // chat tab says as much rather than polling an endpoint that does not exist.
  test('notifications answer', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final feed = await api.get<dynamic>('/partner/notifications');
    final items = mapListOf(Map<String, dynamic>.from(feed as Map)['items'])
        .map(AppNotification.fromJson)
        .toList();
    for (final n in items) {
      expect(n.title, isNotEmpty);
      expect(n.body, isNotEmpty, reason: 'the message field is `message`, not `body`');
    }
  });

  test('chat threads, messages and the unread cursor', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/conversations');
    final j = Map<String, dynamic>.from(raw as Map);
    final threads = mapListOf(j['items']).map(Conversation.fromJson).toList();

    expect(threads, isNotEmpty, reason: 'the seed opens conversations for this partner');

    for (final t in threads) {
      expect(int.tryParse(t.id), isNotNull, reason: 'ids travel as strings');
      expect(t.counterpartName, isNotEmpty);
      expect(t.unread, greaterThanOrEqualTo(0));
    }

    // The badge must be the same number the list adds up to, not a second
    // count computed a different way.
    final badge = await api.get<dynamic>('/partner/conversations/unread');
    final total = intOf(Map<String, dynamic>.from(badge as Map)['total']);
    expect(total, threads.fold<int>(0, (sum, t) => sum + t.unread),
        reason: 'the badge must equal the sum of the per-thread counts');

    final thread = threads.first;
    final msgRaw = await api.get<dynamic>('/partner/conversations/${thread.id}/messages');
    final messages = mapListOf(Map<String, dynamic>.from(msgRaw as Map)['items'])
        .map(ChatMessage.fromJson)
        .toList();

    expect(messages, isNotEmpty);
    // Reading order, oldest first — the bubbles are rendered in list order.
    for (var i = 1; i < messages.length; i++) {
      expect(messages[i].seq, greaterThan(messages[i - 1].seq),
          reason: 'messages must arrive in id order');
    }

    // `since` is an id cursor: asking past the newest returns nothing.
    final newest = messages.last.seq;
    final none = await api.get<dynamic>(
      '/partner/conversations/${thread.id}/messages',
      query: {'since': newest},
    );
    expect(mapListOf(Map<String, dynamic>.from(none as Map)['items']), isEmpty,
        reason: 'polling past the newest message must return nothing');
  });

  test("another partner's conversation is not visible", () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/conversations');
    final threads =
        mapListOf(Map<String, dynamic>.from(raw as Map)['items']).map(Conversation.fromJson);
    if (threads.isEmpty) return markTestSkipped('no conversations to check against');

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

    // 404 rather than 403 — a 403 would confirm the id exists, which is enough
    // to enumerate other partners' threads.
    try {
      await other.get<dynamic>('/partner/conversations/${threads.first.id}/messages');
      fail("partner B read partner A's conversation");
    } on ApiException catch (e) {
      expect(e.statusCode, 404, reason: 'must be 404, not 403');
    }
  });

  test('payouts reconcile against their items', () async {
    if (!reachable) return markTestSkipped('backend not running');

    final raw = await api.get<dynamic>('/partner/payouts');
    final j = Map<String, dynamic>.from(raw as Map);
    final payouts = mapListOf(j['items']).map(Payout.fromJson).toList();

    for (final p in payouts) {
      expect(p.gross, p.commission + p.net,
          reason: 'payout ${p.id}: gross must equal commission + net');

      // And the payout must equal the bookings it was built from. This is the
      // number a partner would query, so it has to survive the round trip.
      final itemsRaw = await api.get<dynamic>('/partner/payouts/${p.id}/items');
      final items = mapListOf(Map<String, dynamic>.from(itemsRaw as Map)['items']);
      expect(items, isNotEmpty, reason: 'payout ${p.id} has no items');
      expect(
        items.fold<int>(0, (sum, i) => sum + intOf(i['net'])),
        p.net,
        reason: 'payout ${p.id} must equal the sum of its bookings',
      );
    }
  });
}
