/// The Partner Calendar: a month of per-day totals
/// (`GET /partner/properties/:id/calendar-month`) and one day broken down room
/// type by room type, room by room (`GET /partner/properties/:id/board`).
///
/// Dates stay as the raw `YYYY-MM-DDT00:00:00.000Z` strings the API sends,
/// like `CalendarDay.date` in `models.dart` — read them with `parseDay()` from
/// `core/dates.dart`, never `DateTime.parse`, so a stay never slides a day
/// across the UTC boundary.
library;

import '../core/dates.dart';

/// One day on the month grid.
class CalendarMonthDay {
  CalendarMonthDay({
    required this.date,
    required this.total,
    required this.booked,
    required this.held,
    required this.onSale,
    required this.arrivals,
    required this.departures,
  });

  final String date;

  /// Rooms on sale across every room type that night.
  final int total;
  final int booked;

  /// Rooms held for a checkout that has not paid yet.
  final int held;
  final bool onSale;
  final int arrivals;
  final int departures;

  int get taken => booked + held;
  bool get hasInventory => total > 0;
  bool get isFull => hasInventory && taken >= total;
  double get fill => hasInventory ? (taken / total).clamp(0.0, 1.0) : 0;

  factory CalendarMonthDay.fromJson(Map<String, dynamic> j) => CalendarMonthDay(
    date: j['date']?.toString() ?? '',
    total: _int(j['total']),
    booked: _int(j['booked']),
    held: _int(j['held']),
    onSale: j['onSale'] == true,
    arrivals: _int(j['arrivals']),
    departures: _int(j['departures']),
  );
}

/// A guest's stay as it appears on a day's room list.
class DayBooking {
  DayBooking({
    required this.bookingId,
    required this.code,
    required this.guestName,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.guests,
    required this.status,
    this.guestPhone,
    this.paymentStatus,
    this.missingRooms = 0,
  });

  final String bookingId;
  final String code;
  final String guestName;
  final String? guestPhone;
  final String checkIn;
  final String checkOut;
  final int nights;
  final int guests;

  /// `bookings.status`.
  final String status;

  /// Latest `payments.status`, or null when nothing was ever paid or attempted.
  final String? paymentStatus;

  /// Only set on an "unassigned" entry: how many of the booked rooms still
  /// have no room number.
  final int missingRooms;

  bool arrivesOn(DateTime day) => parseDay(checkIn) == day;
  bool departsOn(DateTime day) => parseDay(checkOut) == day;

  factory DayBooking.fromJson(Map<String, dynamic> j) => DayBooking(
    bookingId: j['bookingId']?.toString() ?? '',
    code: j['code']?.toString() ?? '',
    guestName: j['guestName']?.toString() ?? 'Guest',
    guestPhone: _phone(j['guestPhone']),
    checkIn: j['checkIn']?.toString() ?? '',
    checkOut: j['checkOut']?.toString() ?? '',
    nights: _int(j['nights']),
    guests: _int(j['guests'], 1),
    status: j['status']?.toString() ?? '',
    paymentStatus: j['paymentStatus']?.toString(),
    missingRooms: _int(j['missingRooms']),
  );
}

/// What a numbered room is doing on the day being viewed. Ordered by which
/// rule wins when several apply.
enum RoomDayState {
  /// A guest is staying through tonight.
  occupied,

  /// Same as [occupied], and they check in today.
  arriving,

  /// Someone leaves this morning and nobody arrives after them.
  departing,

  /// Someone leaves this morning and someone else arrives.
  turnover,
  needsCleaning,
  maintenance,
  inactive,
  available,
}

class DayRoom {
  DayRoom({
    required this.roomId,
    required this.roomNumber,
    required this.status,
    this.floor,
    this.occupant,
    this.departure,
  });

  final String roomId;
  final String roomNumber;
  final String? floor;

  /// `rooms.status` as the server resolved it for this day — `needs_cleaning`
  /// never appears for a future date.
  final String status;

  /// The stay covering tonight, if any.
  final DayBooking? occupant;

  /// The stay that ends this morning, if any.
  final DayBooking? departure;

  RoomDayState stateOn(DateTime day) {
    if (occupant != null && departure != null) return RoomDayState.turnover;
    if (occupant != null) {
      return occupant!.arrivesOn(day)
          ? RoomDayState.arriving
          : RoomDayState.occupied;
    }
    if (departure != null) return RoomDayState.departing;
    return switch (status) {
      'maintenance' => RoomDayState.maintenance,
      'inactive' => RoomDayState.inactive,
      'needs_cleaning' => RoomDayState.needsCleaning,
      _ => RoomDayState.available,
    };
  }

  factory DayRoom.fromJson(Map<String, dynamic> j) => DayRoom(
    roomId: j['roomId']?.toString() ?? '',
    roomNumber: j['roomNumber']?.toString() ?? '',
    floor: j['floor']?.toString(),
    status: j['status']?.toString() ?? 'available',
    occupant: _booking(j['occupant']),
    departure: _booking(j['departure']),
  );
}

/// One room type's block on the day screen.
class DayRoomTypeSection {
  DayRoomTypeSection({
    required this.roomTypeId,
    required this.roomTypeName,
    required this.hasRoomNumbers,
    required this.price,
    required this.onSale,
    required this.total,
    required this.booked,
    required this.held,
    required this.rooms,
    required this.unassigned,
    required this.bookings,
  });

  final String roomTypeId;
  final String roomTypeName;

  /// False when the type has no `rooms` rows at all — nothing to list per
  /// room, so [bookings] carries the day's guests instead.
  final bool hasRoomNumbers;
  final int price;
  final bool onSale;
  final int total;
  final int booked;
  final int held;
  final List<DayRoom> rooms;

  /// Bookings holding this type tonight that have no room number yet.
  final List<DayBooking> unassigned;

  /// Only filled when [hasRoomNumbers] is false.
  final List<DayBooking> bookings;

  int get taken => booked + held;

  factory DayRoomTypeSection.fromJson(Map<String, dynamic> j) =>
      DayRoomTypeSection(
        roomTypeId: j['roomTypeId']?.toString() ?? '',
        roomTypeName: j['roomTypeName']?.toString() ?? '',
        hasRoomNumbers: j['hasRoomNumbers'] == true,
        price: _int(j['price']),
        onSale: j['onSale'] == true,
        total: _int(j['total']),
        booked: _int(j['booked']),
        held: _int(j['held']),
        rooms: _list(j['rooms']).map(DayRoom.fromJson).toList(),
        unassigned: _list(j['unassigned']).map(DayBooking.fromJson).toList(),
        bookings: _list(j['bookings']).map(DayBooking.fromJson).toList(),
      );
}

class DaySummary {
  DaySummary({
    required this.total,
    required this.taken,
    required this.arrivals,
    required this.departures,
    required this.needsCleaning,
    required this.unassigned,
  });

  final int total;
  final int taken;
  final int arrivals;
  final int departures;
  final int needsCleaning;
  final int unassigned;

  int get free => (total - taken).clamp(0, total);

  factory DaySummary.fromJson(Map<String, dynamic> j) => DaySummary(
    total: _int(j['total']),
    taken: _int(j['taken']),
    arrivals: _int(j['arrivals']),
    departures: _int(j['departures']),
    needsCleaning: _int(j['needsCleaning']),
    unassigned: _int(j['unassigned']),
  );
}

/// `GET /partner/properties/:id/board?date=`.
class DayBoard {
  DayBoard({
    required this.date,
    required this.summary,
    required this.roomTypes,
  });

  final String date;
  final DaySummary summary;
  final List<DayRoomTypeSection> roomTypes;

  factory DayBoard.fromJson(Map<String, dynamic> j) => DayBoard(
    date: j['date']?.toString() ?? '',
    summary: DaySummary.fromJson(
      Map<String, dynamic>.from(j['summary'] as Map? ?? const {}),
    ),
    roomTypes: _list(j['roomTypes']).map(DayRoomTypeSection.fromJson).toList(),
  );
}

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String? _phone(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

DayBooking? _booking(Object? v) =>
    v is Map ? DayBooking.fromJson(Map<String, dynamic>.from(v)) : null;

List<Map<String, dynamic>> _list(Object? v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
