/// A numbered physical room under a room type — "204", "206".
///
/// `RoomType.totalRooms` stays the nightly sale ceiling regardless of how many
/// of these exist or what their statuses are — numbering is bookkeeping under
/// that count, not a replacement for it. The one place a room's number reaches
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

  /// `available` · `maintenance` · `inactive`. `maintenance` is how a partner
  /// pulls one physical room off sale without touching the room type's
  /// aggregate count; `inactive` is where a room with booking history lands
  /// once "deleted" — the server deactivates it rather than removing the row.
  final String status;

  bool get isAvailable => status == 'available';
  bool get isMaintenance => status == 'maintenance';
  bool get isInactive => status == 'inactive';

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
