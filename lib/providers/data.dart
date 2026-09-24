import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/dates.dart';
import '../models/models.dart';
import '../theme/report_specs.dart';
import 'auth.dart';

/// Server state.
///
/// Each provider owns one endpoint and exposes `AsyncValue`, which is the same
/// loading / error / data shape the WebAdmin gets from TanStack Query — the two
/// clients stay easy to compare. Mutations call `ref.invalidate` on whatever
/// they changed rather than patching local copies, so the screen always shows
/// what the server actually stored.
///
/// Riverpod 3 dropped `StateProvider`, so the few pieces of view state below
/// are plain `Notifier`s.

/// The result of [PartnerActions.createRooms]: some numbers may have landed
/// while others 400'd (almost always a duplicate room number) — both are
/// normal outcomes, not something to throw over, so the caller decides how to
/// tell the partner about a partial batch.
typedef BulkRoomResult = ({List<RoomUnit> created, Map<String, String> failed});

// ── dashboard ───────────────────────────────────────────────────────────────

final dashboardProvider = FutureProvider.autoDispose<PartnerDashboard>((
  ref,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/dashboard');
  return PartnerDashboard(Map<String, dynamic>.from(data as Map));
});

// ── locations ───────────────────────────────────────────────────────────────

/// Provinces and districts for the sign-up form.
///
/// Both endpoints are public, which matters: this runs before the applicant
/// has an account, so there is no token to send.
final provincesProvider = FutureProvider<List<Province>>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/locations/provinces');
  return mapListOf(data).map(Province.fromJson).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

final districtsProvider = FutureProvider.family<List<District>, String>((
  ref,
  provinceId,
) async {
  if (provinceId.isEmpty) return const [];
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/locations/districts', query: {'provinceId': provinceId});
  return mapListOf(data).map(District.fromJson).toList();
});

// ── properties and room types ───────────────────────────────────────────────

final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/properties');
  return mapListOf(data).map(Property.fromJson).toList();
});

typedef PropertyRoomType = ({Property property, RoomType roomType});

/// Every active room type the partner owns, flattened — the calendar and the
/// walk-in form both need the list without caring which property it sits on.
final allRoomTypesProvider = FutureProvider<List<PropertyRoomType>>((
  ref,
) async {
  final properties = await ref.watch(propertiesProvider.future);
  return [
    for (final p in properties)
      for (final rt in p.roomTypes.where((rt) => rt.isActive))
        (property: p, roomType: rt),
  ];
});

// ── bookings ────────────────────────────────────────────────────────────────

/// Which status chip the bookings list is filtered by. Null means all.
final bookingFilterProvider = NotifierProvider<BookingFilter, String?>(
  BookingFilter.new,
);

class BookingFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? status) => state = status;
}

final bookingsProvider = FutureProvider.autoDispose<Paged<BookingSummary>>((
  ref,
) async {
  final status = ref.watch(bookingFilterProvider);
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>(
        '/partner/bookings',
        query: {'limit': 50, if (status != null) 'status': status},
      );
  return Paged.fromJson(
    Map<String, dynamic>.from(data as Map),
    BookingSummary.fromJson,
  );
});

final bookingCountsProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/bookings/status-counts');
  return Map<String, dynamic>.from(
    data as Map,
  ).map((k, v) => MapEntry(k, intOf(v)));
});

final bookingDetailProvider = FutureProvider.autoDispose
    .family<BookingDetail, String>((ref, id) async {
      final data = await ref
          .watch(apiClientProvider)
          .get<dynamic>('/partner/bookings/$id');
      return BookingDetail(Map<String, dynamic>.from(data as Map));
    });

/// The room-picker list for the "assign a room" sheet on a booking's detail
/// screen — fetched fresh each time the sheet opens, not kept warm, since a
/// room someone else grabbed a minute ago must not still look free.
final bookingRoomOptionsProvider = FutureProvider.autoDispose
    .family<BookingRoomOptions, String>((ref, bookingId) async {
      final data = await ref
          .watch(apiClientProvider)
          .get<dynamic>('/partner/bookings/$bookingId/available-rooms');
      return BookingRoomOptions.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
    });

// ── payouts and reviews ─────────────────────────────────────────────────────

typedef PayoutSummary =
    ({List<Payout> items, int pendingCount, int pendingTotal, int paidTotal});

final payoutsProvider = FutureProvider.autoDispose<PayoutSummary>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/payouts');
  final j = Map<String, dynamic>.from(data as Map);
  return (
    items: mapListOf(j['items']).map(Payout.fromJson).toList(),
    pendingCount: intOf(j['pendingCount']),
    pendingTotal: intOf(j['pendingTotal']),
    paidTotal: intOf(j['paidTotal']),
  );
});

/// The bookings behind one payout — the reconciliation view. Every payout row
/// must equal the sum of these, which is a database CHECK, not a hope.
final payoutItemsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
      final data = await ref
          .watch(apiClientProvider)
          .get<dynamic>('/partner/payouts/$id/items');
      return mapListOf(Map<String, dynamic>.from(data as Map)['items']);
    });

typedef ReviewSummary = ({List<Review> items, int total, double? averageStars});

final reviewsProvider = FutureProvider.autoDispose<ReviewSummary>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/reviews');
  final j = Map<String, dynamic>.from(data as Map);
  final avg = j['averageStars'];
  return (
    items: mapListOf(j['items']).map(Review.fromJson).toList(),
    total: intOf(j['total']),
    averageStars: avg is num ? avg.toDouble() : null,
  );
});

// ── notifications ───────────────────────────────────────────────────────────

typedef NotificationFeed = ({List<AppNotification> items, int unread});

final notificationsProvider = FutureProvider.autoDispose<NotificationFeed>((
  ref,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/notifications');
  final j = Map<String, dynamic>.from(data as Map);
  return (
    items: mapListOf(j['items']).map(AppNotification.fromJson).toList(),
    unread: intOf(j['unread']),
  );
});

// ── chat ────────────────────────────────────────────────────────────────────

typedef ConversationList = ({List<Conversation> items, int unreadTotal});

final conversationsProvider = FutureProvider.autoDispose<ConversationList>((
  ref,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/conversations');
  final j = Map<String, dynamic>.from(data as Map);
  return (
    items: mapListOf(j['items']).map(Conversation.fromJson).toList(),
    unreadTotal: intOf(j['unreadTotal']),
  );
});

/// The badge on the chat tab. Cheap enough to poll while the app is open.
final unreadChatProvider = FutureProvider.autoDispose<int>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>('/partner/conversations/unread');
  return intOf(Map<String, dynamic>.from(data as Map)['total']);
});

/// One thread, polled while the screen is open.
///
/// The cursor is the last message **id**, not a timestamp: two messages written
/// in the same millisecond would make a time cursor either skip one or repeat
/// it. Only messages past the cursor come back, so a long conversation is
/// fetched once and then extended a few rows at a time.
final chatProvider = AsyncNotifierProvider.autoDispose
    .family<ChatNotifier, List<ChatMessage>, String>(ChatNotifier.new);

class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  ChatNotifier(this.conversationId);

  final String conversationId;

  Timer? _timer;
  int _cursor = 0;

  @override
  Future<List<ChatMessage>> build() async {
    ref.onDispose(() => _timer?.cancel());

    final first = await _fetch(since: null);
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.chatPollInterval, (_) => _poll());
    return first;
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<List<ChatMessage>> _fetch({int? since}) async {
    final data = await _api.get<dynamic>(
      '/partner/conversations/$conversationId/messages',
      query: {if (since != null && since > 0) 'since': since},
    );
    final j = Map<String, dynamic>.from(data as Map);
    final messages = mapListOf(j['items']).map(ChatMessage.fromJson).toList();
    if (messages.isNotEmpty) _cursor = messages.last.seq;
    return messages;
  }

  Future<void> _poll() async {
    try {
      final fresh = await _fetch(since: _cursor);
      if (fresh.isEmpty) return;
      state = AsyncData([...?state.value, ...fresh]);
      // New messages arrived while the thread is open, so they are read the
      // moment they land.
      await markRead();
    } on ApiException {
      // A dropped poll is not worth an error banner — the next tick retries and
      // what is already on screen is still valid.
    }
  }

  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;

    final data = await _api.post<dynamic>(
      '/partner/conversations/$conversationId/messages',
      body: {'text': text},
    );
    final sent = ChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
    _cursor = sent.seq;
    state = AsyncData([...?state.value, sent]);
    ref.invalidate(conversationsProvider);
  }

  Future<void> deleteMessage(String messageId) async {
    await _api.delete<dynamic>(
      '/partner/conversations/$conversationId/messages/$messageId',
    );
    state = AsyncData([
      for (final m in state.value ?? const <ChatMessage>[])
        if (m.id == messageId)
          ChatMessage(
            id: m.id,
            senderId: m.senderId,
            senderName: m.senderName,
            mine: m.mine,
            type: m.type,
            text: null,
            isDeleted: true,
            isEdited: m.isEdited,
            replyToId: m.replyToId,
            createdAt: m.createdAt,
          )
        else
          m,
    ]);
    ref.invalidate(conversationsProvider);
  }

  Future<void> markRead() async {
    try {
      await _api.post<dynamic>('/partner/conversations/$conversationId/read');
      ref.invalidate(unreadChatProvider);
      ref.invalidate(conversationsProvider);
    } on ApiException {
      // Cosmetic only — the cursor moves again on the next read.
    }
  }
}

// ── calendar ────────────────────────────────────────────────────────────────

/// Which room type the calendar screen is showing.
final selectedRoomTypeProvider = NotifierProvider<SelectedRoomType, String?>(
  SelectedRoomType.new,
);

class SelectedRoomType extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? roomTypeId) => state = roomTypeId;
}

/// The month the calendar is scrolled to, as UTC midnight on the 1st.
final calendarMonthProvider = NotifierProvider<CalendarMonth, DateTime>(
  CalendarMonth.new,
);

class CalendarMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final t = todayUtc();
    return DateTime.utc(t.year, t.month, 1);
  }

  void shift(int months) =>
      state = DateTime.utc(state.year, state.month + months, 1);
}

typedef CalendarKey = ({String roomTypeId, DateTime month});

final roomCalendarProvider = FutureProvider.autoDispose
    .family<RoomCalendar, CalendarKey>((ref, key) async {
      final from = DateTime.utc(key.month.year, key.month.month, 1);
      final to = DateTime.utc(key.month.year, key.month.month + 1, 1);

      final data = await ref
          .watch(apiClientProvider)
          .get<dynamic>(
            '/partner/room-types/${key.roomTypeId}/calendar',
            query: {'from': apiDay(from), 'to': apiDay(to)},
          );
      return RoomCalendar.fromJson(Map<String, dynamic>.from(data as Map));
    });

// ── calendar: month grid & day detail ───────────────────────────────────────

/// Which property the Calendar is showing. Rooms belong to one property — a
/// floor plan does not span buildings — so unlike the pricing screen (which
/// lists room types across every property) this is a single selection. Null
/// means the first property until a partner who owns several picks another.
final selectedPropertyProvider = NotifierProvider<SelectedProperty, String?>(
  SelectedProperty.new,
);

class SelectedProperty extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? propertyId) => state = propertyId;
}

/// The month the Calendar is scrolled to, as UTC midnight on the 1st.
final occupancyMonthProvider = NotifierProvider<OccupancyMonth, DateTime>(
  OccupancyMonth.new,
);

class OccupancyMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final t = todayUtc();
    return DateTime.utc(t.year, t.month, 1);
  }

  void set(DateTime month) => state = DateTime.utc(month.year, month.month, 1);
  void shift(int months) =>
      state = DateTime.utc(state.year, state.month + months, 1);
}

typedef MonthKey = ({String propertyId, DateTime month});

/// Every day of one month, for the grid: how full it is, arrivals, departures.
final monthSummaryProvider = FutureProvider.autoDispose
    .family<List<CalendarMonthDay>, MonthKey>((ref, key) async {
      final from = DateTime.utc(key.month.year, key.month.month, 1);
      final to = DateTime.utc(key.month.year, key.month.month + 1, 1);
      final data = await ref
          .watch(apiClientProvider)
          .get<dynamic>(
            '/partner/properties/${key.propertyId}/calendar-month',
            query: {'from': apiDay(from), 'to': apiDay(to)},
          );
      return mapListOf(
        Map<String, dynamic>.from(data as Map)['days'],
      ).map(CalendarMonthDay.fromJson).toList();
    });

typedef BoardKey = ({String propertyId, DateTime date});

/// One day, room type by room type and room by room.
final dayBoardProvider = FutureProvider.autoDispose.family<DayBoard, BoardKey>((
  ref,
  key,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>(
        '/partner/properties/${key.propertyId}/board',
        query: {'date': apiDay(key.date)},
      );
  return DayBoard.fromJson(Map<String, dynamic>.from(data as Map));
});

// ── reports ─────────────────────────────────────────────────────────────────

/// The date range every report screen shares — switching between reports
/// keeps the range instead of re-asking, per the hub's persistent context bar.
/// Defaults to the trailing 7 days, the same window `/partner/dashboard`
/// already shows, so the hub opens on numbers the partner has already seen.
final reportRangeProvider =
    NotifierProvider<ReportRangeNotifier, ({DateTime from, DateTime to})>(
      ReportRangeNotifier.new,
    );

class ReportRangeNotifier extends Notifier<({DateTime from, DateTime to})> {
  @override
  ({DateTime from, DateTime to}) build() {
    final today = todayUtc();
    return (from: addDays(today, -6), to: addDays(today, 1));
  }

  void set(DateTime from, DateTime to) => state = (from: from, to: to);
}

final reportBucketProvider = NotifierProvider<ReportBucketNotifier, String>(
  ReportBucketNotifier.new,
);

class ReportBucketNotifier extends Notifier<String> {
  @override
  String build() => 'day';

  void set(String bucket) => state = bucket;
}

/// Null means every property the partner owns. Only meaningful once a
/// partner can own more than one, but the plumbing is ready either way.
final reportPropertyFilterProvider =
    NotifierProvider<ReportPropertyFilterNotifier, String?>(
      ReportPropertyFilterNotifier.new,
    );

class ReportPropertyFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? propertyId) => state = propertyId;
}

typedef ReportKey =
    ({
      ReportType type,
      DateTime from,
      DateTime to,
      String bucket,
      String? propertyId,
    });

final reportProvider = FutureProvider.autoDispose
    .family<ReportResult, ReportKey>((ref, key) async {
      final data = await ref
          .watch(apiClientProvider)
          .get<dynamic>(
            '/partner/reports/${key.type.path}',
            query: {
              'from': apiDay(key.from),
              'to': apiDay(key.to),
              'bucket': key.bucket,
              if (key.propertyId != null) 'propertyId': key.propertyId,
            },
          );
      return ReportResult(Map<String, dynamic>.from(data as Map));
    });

// ── profile ─────────────────────────────────────────────────────────────────

final profileProvider = FutureProvider.autoDispose<Partner>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/me');
  return Partner.fromJson(Map<String, dynamic>.from(data as Map));
});

// ── mutations ───────────────────────────────────────────────────────────────

/// Writes live here rather than in the widgets, so a screen never has to
/// remember which providers a change invalidates.
class PartnerActions {
  PartnerActions(this.ref);
  final Ref ref;

  ApiClient get _api => ref.read(apiClientProvider);

  void _invalidateCalendar() {
    ref.invalidate(monthSummaryProvider);
    ref.invalidate(dayBoardProvider);
  }

  void _invalidateBookings() {
    _invalidateCalendar();
    ref.invalidate(bookingsProvider);
    ref.invalidate(bookingCountsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> setBookingStatus(String bookingId, String status) async {
    await _api.patch<dynamic>(
      '/partner/bookings/$bookingId/status',
      body: {'status': status},
    );
    ref.invalidate(bookingDetailProvider(bookingId));
    _invalidateBookings();
  }

  /// Sets, replaces or clears which physical room(s) a booking holds. Pass an
  /// empty list to clear — the API treats "assign no room" as a real choice,
  /// not an error, since letting the property decide later is the default for
  /// every booking whose room type doesn't offer guest self-selection.
  Future<void> assignRoom(String bookingId, List<String> roomIds) async {
    await _api.patch<dynamic>(
      '/partner/bookings/$bookingId/room',
      body: {'roomIds': roomIds},
    );
    ref.invalidate(bookingDetailProvider(bookingId));
    ref.invalidate(bookingRoomOptionsProvider(bookingId));
    _invalidateBookings();
  }

  Future<void> cancelBooking(String bookingId, String? reason) async {
    await _api.post<dynamic>(
      '/partner/bookings/$bookingId/cancel',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    ref.invalidate(bookingDetailProvider(bookingId));
    _invalidateBookings();
    // Cancelling frees the nights, so any calendar on screen is now stale.
    ref.invalidate(roomCalendarProvider);
  }

  Future<Map<String, dynamic>> createWalkIn({
    required String roomTypeId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required String guestName,
    required String guestPhone,
    String? guestEmail,
    int quantity = 1,
  }) async {
    final data = await _api.post<dynamic>(
      '/partner/bookings/walk-in',
      body: {
        'roomTypeId': roomTypeId,
        'checkIn': apiDay(checkIn),
        'checkOut': apiDay(checkOut),
        'guests': guests,
        'quantity': quantity,
        'guestName': guestName,
        'guestPhone': guestPhone,
        if (guestEmail != null && guestEmail.isNotEmpty)
          'guestEmail': guestEmail,
      },
    );
    _invalidateBookings();
    ref.invalidate(roomCalendarProvider);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Sets price and/or open-closed over a date range. `to` is exclusive, like a
  /// stay's check-out.
  ///
  /// Two endpoints back this, not one: price lives in `room_prices` and
  /// open/closed in `room_inventory`, and they are deliberately separate —
  /// closing a night must not disturb the rate it will reopen at. The screen
  /// still asks for one thing, so the split is handled here.
  ///
  /// Returns the number of nights changed. When both are set they cover the
  /// same range, so either count is the answer.
  Future<int> setAvailability({
    required String roomTypeId,
    required DateTime from,
    required DateTime to,
    int? price,
    String? status,
  }) async {
    final range = {'from': apiDay(from), 'to': apiDay(to)};
    var nights = 0;

    if (price != null) {
      final data = await _api.patch<dynamic>(
        '/partner/room-types/$roomTypeId/prices',
        body: {...range, 'price': price},
      );
      nights = intOf(Map<String, dynamic>.from(data as Map)['nights']);
    }

    if (status != null) {
      final data = await _api.patch<dynamic>(
        '/partner/room-types/$roomTypeId/inventory',
        body: {...range, 'status': status},
      );
      nights = intOf(Map<String, dynamic>.from(data as Map)['nights']);
    }

    ref.invalidate(roomCalendarProvider);
    return nights;
  }

  /// Changes how many rooms of this type exist on those nights.
  ///
  /// The database refuses a count below what is already sold — those guests are
  /// booked — and the API turns that into a message rather than a 500.
  Future<int> setRoomCount({
    required String roomTypeId,
    required DateTime from,
    required DateTime to,
    required int totalCount,
  }) async {
    final data = await _api.patch<dynamic>(
      '/partner/room-types/$roomTypeId/inventory',
      body: {'from': apiDay(from), 'to': apiDay(to), 'totalCount': totalCount},
    );
    ref.invalidate(roomCalendarProvider);
    ref.invalidate(propertiesProvider);
    return intOf(Map<String, dynamic>.from(data as Map)['nights']);
  }

  Future<void> saveRoomType({
    String? roomTypeId,
    String? propertyId,
    required Map<String, dynamic> body,
  }) async {
    if (roomTypeId != null) {
      await _api.patch<dynamic>('/partner/room-types/$roomTypeId', body: body);
    } else {
      await _api.post<dynamic>(
        '/partner/properties/$propertyId/room-types',
        body: body,
      );
    }
    ref.invalidate(propertiesProvider);
  }

  /// The API deactivates rather than deletes a room type that carries history,
  /// and says which it did — the caller shows the honest message.
  Future<bool> deleteRoomType(String roomTypeId) async {
    final data = await _api.delete<dynamic>('/partner/room-types/$roomTypeId');
    ref.invalidate(propertiesProvider);
    final j = Map<String, dynamic>.from(data as Map);
    return j['deleted'] == true;
  }

  /// Adds one numbered room under a room type. The API 400s if `roomNumber` is
  /// already taken within that type — the caller shows the API's own message.
  Future<RoomUnit> createRoom(
    String roomTypeId,
    String roomNumber, {
    String? floor,
  }) async {
    final data = await _api.post<dynamic>(
      '/partner/room-types/$roomTypeId/rooms',
      body: {
        'roomNumber': roomNumber,
        if (floor != null && floor.isNotEmpty) 'floor': floor,
      },
    );
    ref.invalidate(propertiesProvider);
    return RoomUnit.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Adds several numbered rooms at once — e.g. a generated range like
  /// 301..310 — so a partner with a 20-room floor is not stuck tapping "add"
  /// twenty times. There is no bulk endpoint on the API, so this fires the
  /// requests concurrently and lets one duplicate-number 400 fail on its own
  /// rather than aborting the rest; the caller gets back exactly which numbers
  /// landed and which didn't, with the API's own message for each failure.
  Future<BulkRoomResult> createRooms(
    String roomTypeId,
    List<String> roomNumbers, {
    String? floor,
  }) async {
    final results = await Future.wait(
      roomNumbers.map((number) async {
        try {
          final data = await _api.post<dynamic>(
            '/partner/room-types/$roomTypeId/rooms',
            body: {
              'roomNumber': number,
              if (floor != null && floor.isNotEmpty) 'floor': floor,
            },
          );
          return (
            number: number,
            room: RoomUnit.fromJson(Map<String, dynamic>.from(data as Map)),
            error: null as String?,
          );
        } on ApiException catch (e) {
          return (number: number, room: null as RoomUnit?, error: e.message);
        }
      }),
    );
    ref.invalidate(propertiesProvider);
    return (
      created: [
        for (final r in results)
          if (r.room != null) r.room!,
      ],
      failed: {
        for (final r in results)
          if (r.error != null) r.number: r.error!,
      },
    );
  }

  /// `status` is `available` · `maintenance` · `inactive` — `maintenance` is
  /// how a partner pulls this one room off sale without touching the room
  /// type's aggregate count. Every field is optional so the caller sends only
  /// what changed.
  Future<RoomUnit> updateRoom(
    String roomId, {
    String? roomNumber,
    String? floor,
    String? status,
  }) async {
    final data = await _api.patch<dynamic>(
      '/partner/rooms/$roomId',
      body: {
        if (roomNumber != null) 'roomNumber': roomNumber,
        if (floor != null) 'floor': floor,
        if (status != null) 'status': status,
      },
    );
    ref.invalidate(propertiesProvider);
    _invalidateCalendar();
    return RoomUnit.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Same deactivate-instead-of-delete shape as [deleteRoomType]: a room with
  /// booking history comes back `deactivated: true` rather than gone, and that
  /// counts as success. Either way the refreshed property list already shows
  /// the resulting state, so the caller only needs this for the message.
  Future<bool> deleteRoom(String roomId) async {
    final data = await _api.delete<dynamic>('/partner/rooms/$roomId');
    ref.invalidate(propertiesProvider);
    final j = Map<String, dynamic>.from(data as Map);
    return j['deleted'] == true;
  }

  Future<void> updateProperty(
    String propertyId,
    Map<String, dynamic> body,
  ) async {
    await _api.patch<dynamic>('/partner/properties/$propertyId', body: body);
    ref.invalidate(propertiesProvider);
  }

  Future<void> uploadPropertyPhoto(
    String propertyId,
    MultipartFile file,
  ) async {
    await _api.upload<dynamic>(
      '/partner/properties/$propertyId/photos',
      file: file,
    );
    ref.invalidate(propertiesProvider);
  }

  /// Applies a full front-to-back photo order in one call — `photoIds.first`
  /// becomes the cover. See UploadsService.reorderPhotos on the backend.
  Future<void> reorderPropertyPhotos(
    String propertyId,
    List<String> photoIds,
  ) async {
    await _api.patch<dynamic>(
      '/partner/properties/$propertyId/photos/order',
      body: {'photoIds': photoIds},
    );
    ref.invalidate(propertiesProvider);
  }

  /// Photos are rows now, so they are addressed by id. Deleting by position was
  /// only ever safe while they lived in an ordered jsonb array.
  Future<void> deletePropertyPhoto(String propertyId, String imageId) async {
    await _api.delete<dynamic>(
      '/partner/properties/$propertyId/photos/$imageId',
    );
    ref.invalidate(propertiesProvider);
  }

  Future<void> setPropertyCover(String propertyId, String imageId) async {
    await _api.patch<dynamic>(
      '/partner/properties/$propertyId/photos/$imageId/cover',
    );
    ref.invalidate(propertiesProvider);
  }

  Future<void> uploadRoomTypePhoto(
    String roomTypeId,
    MultipartFile file,
  ) async {
    await _api.upload<dynamic>(
      '/partner/room-types/$roomTypeId/photos',
      file: file,
    );
    ref.invalidate(propertiesProvider);
  }

  Future<void> deleteRoomTypePhoto(String roomTypeId, String imageId) async {
    await _api.delete<dynamic>(
      '/partner/room-types/$roomTypeId/photos/$imageId',
    );
    ref.invalidate(propertiesProvider);
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    await _api.patch<dynamic>('/partner/me', body: body);
    ref.invalidate(profileProvider);
    await ref.read(authProvider.notifier).refreshPartner();
  }

  Future<void> addBankAccount(Map<String, dynamic> body) async {
    await _api.post<dynamic>('/partner/bank-accounts', body: body);
    ref.invalidate(profileProvider);
    await ref.read(authProvider.notifier).refreshPartner();
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post<dynamic>('/partner/notifications/read-all');
    ref.invalidate(notificationsProvider);
    ref.invalidate(dashboardProvider);
  }

  /// Clears the housekeeping flag once the room has actually been cleaned.
  /// The API 400s if the room isn't currently `needs_cleaning`.
  Future<void> markRoomClean(String roomId) async {
    await _api.patch<dynamic>('/partner/rooms/$roomId/clean');
    _invalidateCalendar();
  }
}

final actionsProvider = Provider<PartnerActions>(PartnerActions.new);
