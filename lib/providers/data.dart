import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/dates.dart';
import '../models/models.dart';
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

// ── dashboard ───────────────────────────────────────────────────────────────

final dashboardProvider = FutureProvider.autoDispose<PartnerDashboard>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/dashboard');
  return PartnerDashboard(Map<String, dynamic>.from(data as Map));
});

// ── properties and rooms ────────────────────────────────────────────────────

final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/properties');
  return mapListOf(data).map(Property.fromJson).toList();
});

typedef PropertyRoom = ({Property property, Room room});

/// Every active room the partner owns, flattened — the calendar and the walk-in
/// form both need a room list without caring which property it sits on.
final allRoomsProvider = FutureProvider<List<PropertyRoom>>((ref) async {
  final properties = await ref.watch(propertiesProvider.future);
  return [
    for (final p in properties)
      for (final r in p.rooms.where((r) => r.isActive)) (property: p, room: r),
  ];
});

// ── bookings ────────────────────────────────────────────────────────────────

/// Which status chip the bookings list is filtered by. Null means all.
final bookingFilterProvider =
    NotifierProvider<BookingFilter, String?>(BookingFilter.new);

class BookingFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? status) => state = status;
}

final bookingsProvider = FutureProvider.autoDispose<Paged<BookingSummary>>((ref) async {
  final status = ref.watch(bookingFilterProvider);
  final data = await ref.watch(apiClientProvider).get<dynamic>(
        '/partner/bookings',
        query: {'limit': 50, if (status != null) 'status': status},
      );
  return Paged.fromJson(Map<String, dynamic>.from(data as Map), BookingSummary.fromJson);
});

final bookingCountsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/bookings/status-counts');
  return Map<String, dynamic>.from(data as Map).map((k, v) => MapEntry(k, intOf(v)));
});

final bookingDetailProvider =
    FutureProvider.autoDispose.family<BookingDetail, String>((ref, id) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/bookings/$id');
  return BookingDetail(Map<String, dynamic>.from(data as Map));
});

// ── payouts and reviews ─────────────────────────────────────────────────────

typedef PayoutSummary = ({
  List<Payout> items,
  int pendingCount,
  int pendingTotal,
  int paidTotal,
});

final payoutsProvider = FutureProvider.autoDispose<PayoutSummary>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/payouts');
  final j = Map<String, dynamic>.from(data as Map);
  return (
    items: mapListOf(j['items']).map(Payout.fromJson).toList(),
    pendingCount: intOf(j['pendingCount']),
    pendingTotal: intOf(j['pendingTotal']),
    paidTotal: intOf(j['paidTotal']),
  );
});

typedef ReviewSummary = ({List<Review> items, int total, double? averageStars});

final reviewsProvider = FutureProvider.autoDispose<ReviewSummary>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/reviews');
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

final notificationsProvider = FutureProvider.autoDispose<NotificationFeed>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/notifications');
  final j = Map<String, dynamic>.from(data as Map);
  return (
    items: mapListOf(j['items']).map(AppNotification.fromJson).toList(),
    unread: intOf(j['unread']),
  );
});

// ── chat ────────────────────────────────────────────────────────────────────

final unreadChatProvider = FutureProvider.autoDispose<int>((ref) async {
  final data = await ref.watch(apiClientProvider).get<dynamic>('/partner/chat/unread');
  return intOf(Map<String, dynamic>.from(data as Map)['total']);
});

/// One booking's conversation, polled while the screen is open.
///
/// The cursor is the last message **id**, not a timestamp: two messages written
/// in the same millisecond would make a time cursor either skip one or repeat
/// it. Only messages past the cursor come back, so a long conversation is
/// fetched once and then extended a few rows at a time.
final chatProvider =
    AsyncNotifierProvider.autoDispose.family<ChatNotifier, List<ChatMessage>, String>(
  ChatNotifier.new,
);

class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  ChatNotifier(this.bookingId);

  final String bookingId;

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
      '/partner/chat/bookings/$bookingId/messages',
      query: {if (since != null && since > 0) 'since': since},
    );
    final j = Map<String, dynamic>.from(data as Map);
    final messages = mapListOf(j['messages']).map(ChatMessage.fromJson).toList();
    if (messages.isNotEmpty) _cursor = messages.last.seq;
    return messages;
  }

  Future<void> _poll() async {
    try {
      final fresh = await _fetch(since: _cursor);
      if (fresh.isEmpty) return;
      state = AsyncData([...?state.value, ...fresh]);
    } on ApiException {
      // A dropped poll is not worth an error banner — the next tick retries and
      // the messages already on screen are still valid.
    }
  }

  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;

    final data = await _api.post<dynamic>(
      '/partner/chat/bookings/$bookingId/messages',
      body: {'body': text},
    );
    final sent = ChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
    _cursor = sent.seq;
    state = AsyncData([...?state.value, sent]);
    ref.invalidate(unreadChatProvider);
  }

  Future<void> markRead() async {
    try {
      await _api.patch<dynamic>('/partner/chat/bookings/$bookingId/read');
      ref.invalidate(unreadChatProvider);
    } on ApiException {
      // Cosmetic only.
    }
  }
}

// ── calendar ────────────────────────────────────────────────────────────────

/// Which room the calendar screen is showing.
final selectedRoomProvider =
    NotifierProvider<SelectedRoom, String?>(SelectedRoom.new);

class SelectedRoom extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? roomId) => state = roomId;
}

/// The month the calendar is scrolled to, as UTC midnight on the 1st.
final calendarMonthProvider =
    NotifierProvider<CalendarMonth, DateTime>(CalendarMonth.new);

class CalendarMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final t = todayUtc();
    return DateTime.utc(t.year, t.month, 1);
  }

  void shift(int months) =>
      state = DateTime.utc(state.year, state.month + months, 1);
}

typedef CalendarKey = ({String roomId, DateTime month});

final roomCalendarProvider =
    FutureProvider.autoDispose.family<RoomCalendar, CalendarKey>((ref, key) async {
  final from = DateTime.utc(key.month.year, key.month.month, 1);
  final to = DateTime.utc(key.month.year, key.month.month + 1, 1);

  final data = await ref.watch(apiClientProvider).get<dynamic>(
        '/partner/rooms/${key.roomId}/availability',
        query: {'from': apiDay(from), 'to': apiDay(to)},
      );
  return RoomCalendar.fromJson(Map<String, dynamic>.from(data as Map));
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

  void _invalidateBookings() {
    ref.invalidate(bookingsProvider);
    ref.invalidate(bookingCountsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> setBookingStatus(String bookingId, String status) async {
    await _api.patch<dynamic>('/partner/bookings/$bookingId/status', body: {'status': status});
    ref.invalidate(bookingDetailProvider(bookingId));
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
    required String roomId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    required String guestName,
    required String guestPhone,
    String? guestEmail,
  }) async {
    final data = await _api.post<dynamic>(
      '/partner/bookings/walk-in',
      body: {
        'roomId': roomId,
        'checkIn': apiDay(checkIn),
        'checkOut': apiDay(checkOut),
        'guests': guests,
        'guestName': guestName,
        'guestPhone': guestPhone,
        if (guestEmail != null && guestEmail.isNotEmpty) 'guestEmail': guestEmail,
      },
    );
    _invalidateBookings();
    ref.invalidate(roomCalendarProvider);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Sets price and/or status over a date range. `to` is exclusive, like a
  /// stay's check-out.
  Future<int> setAvailability({
    required String roomId,
    required DateTime from,
    required DateTime to,
    int? price,
    String? status,
  }) async {
    final data = await _api.patch<dynamic>(
      '/partner/rooms/$roomId/availability',
      body: {
        'from': apiDay(from),
        'to': apiDay(to),
        if (price != null) 'price': price,
        if (status != null) 'status': status,
      },
    );
    ref.invalidate(roomCalendarProvider);
    return intOf(Map<String, dynamic>.from(data as Map)['updated']);
  }

  Future<void> saveRoom({
    String? roomId,
    String? propertyId,
    required Map<String, dynamic> body,
  }) async {
    if (roomId != null) {
      await _api.patch<dynamic>('/partner/properties/rooms/$roomId', body: body);
    } else {
      await _api.post<dynamic>('/partner/properties/$propertyId/rooms', body: body);
    }
    ref.invalidate(propertiesProvider);
  }

  /// The API deactivates rather than deletes a room that carries history, and
  /// says which it did — the caller shows the honest message.
  Future<bool> deleteRoom(String roomId) async {
    final data = await _api.delete<dynamic>('/partner/properties/rooms/$roomId');
    ref.invalidate(propertiesProvider);
    final j = Map<String, dynamic>.from(data as Map);
    return j['deleted'] == true;
  }

  Future<void> updateProperty(String propertyId, Map<String, dynamic> body) async {
    await _api.patch<dynamic>('/partner/properties/$propertyId', body: body);
    ref.invalidate(propertiesProvider);
  }

  Future<void> uploadPropertyPhoto(String propertyId, MultipartFile file) async {
    await _api.upload<dynamic>('/partner/properties/$propertyId/photos', file: file);
    ref.invalidate(propertiesProvider);
  }

  Future<void> deletePropertyPhoto(String propertyId, int index) async {
    await _api.delete<dynamic>('/partner/properties/$propertyId/photos/$index');
    ref.invalidate(propertiesProvider);
  }

  Future<void> uploadRoomPhoto(String roomId, MultipartFile file) async {
    await _api.upload<dynamic>('/partner/rooms/$roomId/photos', file: file);
    ref.invalidate(propertiesProvider);
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    await _api.patch<dynamic>('/partner/me', body: body);
    ref.invalidate(profileProvider);
    await ref.read(authProvider.notifier).refreshPartner();
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post<dynamic>('/partner/notifications/read-all');
    ref.invalidate(notificationsProvider);
    ref.invalidate(dashboardProvider);
  }
}

final actionsProvider = Provider<PartnerActions>(PartnerActions.new);
