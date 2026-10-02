/// A numbered physical room under a room type — "204", "206".
///
/// Once a room type has numbered rooms, the rooms in service (available or
/// needing cleaning — not maintenance or inactive) are a second sale ceiling
/// beside `RoomType.totalRooms`: the API never sells more nights than there
/// are rooms to sleep in, and refuses a nightly count above them. The one place a room's number reaches
/// a guest is when its room type has `allowRoomSelection` on, letting them pick
/// a specific number at booking time instead of just a type.
///
/// Kept in its own file and named `RoomUnit` rather than `Room` on purpose:
/// this app's models otherwise use `RoomType` for the sellable category, and a
/// `Room` here would invite the same type-vs-unit confusion the customer app
/// hit with its old naming.
class RoomUnit {
  RoomUnit({
    required this.id,
    required this.roomNumber,
    required this.status,
    this.floor,
  });

  final String id;
  final String roomNumber;
  final String? floor;

  /// `available` · `maintenance` · `inactive` · `needs_cleaning`. `maintenance`
  /// is how a partner pulls one physical room off sale without touching the
  /// room type's aggregate count; `inactive` is where a room with booking
  /// history lands once "deleted" — the server deactivates it rather than
  /// removing the row; `needs_cleaning` is set automatically after checkout
  /// and cleared by the partner marking it clean.
  final String status;

  bool get isAvailable => status == 'available';
  bool get isMaintenance => status == 'maintenance';
  bool get isInactive => status == 'inactive';
  bool get isNeedsCleaning => status == 'needs_cleaning';

  factory RoomUnit.fromJson(Map<String, dynamic> j) => RoomUnit(
    id: j['id']?.toString() ?? '',
    roomNumber: j['roomNumber']?.toString() ?? '',
    floor: j['floor']?.toString(),
    status: j['status']?.toString() ?? 'available',
  );
}

List<RoomUnit> roomUnitsOf(Object? v) {
  if (v is! List) return const [];
  return v
      .whereType<Map>()
      .map((e) => RoomUnit.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// `GET /partner/bookings/:id/available-rooms` — the room-picker list for
/// assigning a specific room to a booking that doesn't have one yet (or
/// changing the one it does). Rooms here are already filtered to what's free
/// for the booking's own dates, with whatever it currently holds included
/// rather than hidden (see `currentRoomIds`) — every room in [rooms] is a
/// valid pick, none need a separate "unavailable" state in the UI.
class BookingRoomOptions {
  BookingRoomOptions({
    required this.quantity,
    required this.currentRoomIds,
    required this.rooms,
  });

  /// How many rooms this booking needs — 1 for the overwhelming majority of
  /// bookings, more only when a guest booked several rooms of the same type
  /// at once. A save must select exactly this many, or none at all to clear.
  final int quantity;
  final List<String> currentRoomIds;
  final List<RoomUnit> rooms;

  factory BookingRoomOptions.fromJson(Map<String, dynamic> j) =>
      BookingRoomOptions(
        quantity: int.tryParse('${j['quantity']}') ?? 1,
        currentRoomIds:
            (j['currentRoomIds'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        rooms: roomUnitsOf(j['rooms']),
      );
}

class FloorGroup {
  const FloorGroup(this.label, this.rooms);
  final String label;
  final List<RoomUnit> rooms;
}

/// Groups rooms by floor and orders both the floors and the rooms within each
/// the way a person reads a building, not the way a database returns rows:
/// numeric floors ascend (1, 2, 3…), named ones follow alphabetically, and
/// rooms with no floor set trail last as their own group. Within a floor,
/// "2" sorts before "10" — plain string sorting would not.
///
/// Shared between the room-type management screen (every numbered room) and
/// the booking-detail "assign a room" sheet (only the ones free for one
/// stay's dates) — both want the same reading order, just over different
/// subsets of rooms.
List<FloorGroup> groupRoomsByFloor(List<RoomUnit> rooms) {
  const noFloor = '';
  final groups = <String, List<RoomUnit>>{};
  for (final room in rooms) {
    final floor = room.floor?.trim();
    final key = (floor == null || floor.isEmpty) ? noFloor : floor;
    groups.putIfAbsent(key, () => []).add(room);
  }
  for (final list in groups.values) {
    list.sort((a, b) => _naturalCompare(a.roomNumber, b.roomNumber));
  }
  final keys =
      groups.keys.toList()..sort((a, b) {
        if (a == noFloor) return 1;
        if (b == noFloor) return -1;
        final an = int.tryParse(a);
        final bn = int.tryParse(b);
        if (an != null && bn != null) return an.compareTo(bn);
        if (an != null) return -1;
        if (bn != null) return 1;
        return a.compareTo(b);
      });
  return [for (final key in keys) FloorGroup(key, groups[key]!)];
}

int _naturalCompare(String a, String b) {
  final an = int.tryParse(a);
  final bn = int.tryParse(b);
  if (an != null && bn != null) return an.compareTo(bn);
  return a.compareTo(b);
}

/// A future night that, after a room left service (maintenance, deactivated,
/// deleted), has more guests booked than rooms left to put them in. The API
/// never cancels a guest to fix it — it reports the night so the property can:
/// reopen a room, move a guest, or contact them.
class OverbookedNight {
  const OverbookedNight({required this.date, required this.rooms, required this.sold});

  /// `YYYY-MM-DD`.
  final String date;
  final int rooms;
  final int sold;

  factory OverbookedNight.fromJson(Map<String, dynamic> j) => OverbookedNight(
    date: j['date']?.toString() ?? '',
    rooms: (j['rooms'] as num?)?.toInt() ?? 0,
    sold: (j['sold'] as num?)?.toInt() ?? 0,
  );

  /// The `overbooked` list a room update or delete answers with; empty when
  /// the response has none.
  static List<OverbookedNight> listFrom(Object? data) {
    final raw = data is Map ? data['overbooked'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => OverbookedNight.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
