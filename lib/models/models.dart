/// API models.
///
/// **Every id is a `String`.** The database uses `int8` throughout and the
/// backend's BigIntInterceptor serialises them as strings, because a booking id
/// past 2^53 cannot survive a JSON number. Parsing them into `int` here would
/// reintroduce exactly the bug that interceptor exists to prevent.
///
/// **Every amount is an `int` of whole kip.** No doubles.
library;

/// Reads a value the API may send as a number or a numeric string.
int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round() ?? fallback;
  return fallback;
}

int? _intOrNull(Object? v) => v == null ? null : _int(v);

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _str(Object? v, [String fallback = '']) => v?.toString() ?? fallback;
String? _strOrNull(Object? v) => v?.toString();

bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

List<Map<String, dynamic>> _mapList(Object? v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// `properties.photos` / `rooms.photos` hold either plain URL strings (seeded
/// data) or `{url, key, width, height}` objects (uploaded through the API).
List<String> photoUrls(Object? v) {
  if (v is! List) return const [];
  return v
      .map((e) {
        if (e is String) return e;
        if (e is Map && e['url'] is String) return e['url'] as String;
        return null;
      })
      .whereType<String>()
      .toList();
}

class Partner {
  Partner({
    required this.id,
    required this.email,
    required this.ownerName,
    required this.phone,
    required this.status,
    this.bankName,
    this.bankAccount,
    this.commissionRate,
    this.propertyCount = 0,
  });

  final String id;
  final String email;
  final String ownerName;
  final String phone;
  final String status;
  final String? bankName;

  /// Masked by the server (`***1234`) — the full number never leaves it.
  final String? bankAccount;
  final double? commissionRate;
  final int propertyCount;

  bool get isVerified => status == 'verified';
  bool get isPending => status == 'pending';

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: _str(j['id']),
        email: _str(j['email']),
        ownerName: _str(j['ownerName']),
        phone: _str(j['phone']),
        status: _str(j['status'], 'pending'),
        bankName: _strOrNull(j['bankName']),
        bankAccount: _strOrNull(j['bankAccount']),
        commissionRate: _double(j['commissionRate']),
        propertyCount: _int(j['propertyCount']),
      );
}

class Room {
  Room({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.bedType,
    required this.basePrice,
    required this.capacity,
    required this.qty,
    required this.isActive,
    required this.hasAc,
    this.roomNo,
    this.photos = const [],
  });

  final String id;
  final String propertyId;
  final String name;
  final String? roomNo;
  final bool hasAc;
  final String bedType;
  final int basePrice;
  final int capacity;
  final int qty;
  final bool isActive;
  final List<String> photos;

  String get label => roomNo?.isNotEmpty == true ? '$name · $roomNo' : name;

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: _str(j['id']),
        propertyId: _str(j['propertyId'] ?? j['property_id']),
        name: _str(j['name']),
        roomNo: _strOrNull(j['roomNo'] ?? j['room_no']),
        hasAc: _bool(j['hasAc'] ?? j['has_ac'], true),
        bedType: _str(j['bedType'] ?? j['bed_type']),
        basePrice: _int(j['basePrice'] ?? j['base_price']),
        capacity: _int(j['capacity'], 1),
        qty: _int(j['qty'], 1),
        isActive: _bool(j['isActive'] ?? j['is_active'], true),
        photos: photoUrls(j['photos']),
      );
}

class Property {
  Property({
    required this.id,
    required this.name,
    required this.type,
    required this.province,
    required this.address,
    required this.rooms,
    this.rating,
    this.reviewCount = 0,
    this.photos = const [],
    this.bookingCount = 0,
  });

  final String id;
  final String name;
  final String type;
  final String province;
  final String address;
  final double? rating;
  final int reviewCount;
  final List<String> photos;
  final List<Room> rooms;
  final int bookingCount;

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: _str(j['id']),
        name: _str(j['name']),
        type: _str(j['type']),
        province: _str(j['province']),
        address: _str(j['address']),
        rating: _double(j['rating']),
        reviewCount: _int(j['reviewCount'] ?? j['review_count']),
        photos: photoUrls(j['photos']),
        rooms: _mapList(j['rooms']).map(Room.fromJson).toList(),
        bookingCount: _int(j['bookingCount']),
      );
}

class BookingSummary {
  BookingSummary({
    required this.id,
    required this.code,
    required this.property,
    required this.guest,
    required this.guestPhone,
    required this.room,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.guests,
    required this.total,
    required this.status,
    required this.source,
    this.paymentStatus,
    this.createdAt,
  });

  final String id;
  final String code;
  final String property;
  final String guest;
  final String guestPhone;
  final String room;
  final String checkIn;
  final String checkOut;
  final int nights;
  final int guests;
  final int total;
  final String status;
  final String source;
  final String? paymentStatus;
  final String? createdAt;

  bool get isWalkIn => source == 'walk_in';

  factory BookingSummary.fromJson(Map<String, dynamic> j) => BookingSummary(
        id: _str(j['id']),
        code: _str(j['code']),
        property: _str(j['property']),
        guest: _str(j['guest']),
        guestPhone: _str(j['guestPhone']),
        room: _str(j['room']),
        checkIn: _str(j['checkIn']),
        checkOut: _str(j['checkOut']),
        nights: _int(j['nights']),
        guests: _int(j['guests'], 1),
        total: _int(j['total']),
        status: _str(j['status']),
        source: _str(j['source'], 'app'),
        paymentStatus: _strOrNull(j['paymentStatus']),
        createdAt: _strOrNull(j['createdAt']),
      );
}

/// The detail response keeps the raw database shape (snake_case, nested
/// relations), so it is held as a map with typed accessors rather than mirrored
/// field by field — the screen reads a handful of values from it.
class BookingDetail {
  BookingDetail(this.raw);
  final Map<String, dynamic> raw;

  String get id => _str(raw['id']);
  String get code => _str(raw['code']);
  String get status => _str(raw['status']);
  String get source => _str(raw['source'], 'app');
  String get checkIn => _str(raw['check_in']);
  String get checkOut => _str(raw['check_out']);
  int get nights => _int(raw['nights']);
  int get guests => _int(raw['guests'], 1);
  int get subtotal => _int(raw['subtotal']);
  int get fee => _int(raw['fee']);
  int get discount => _int(raw['discount']);
  int get total => _int(raw['total']);
  bool get isWalkIn => source == 'walk_in';

  Map<String, dynamic> get _guest =>
      Map<String, dynamic>.from(raw['users'] as Map? ?? const {});
  String get guestName => _str(_guest['full_name']);
  String get guestPhone => _str(_guest['phone']);
  String get guestEmail => _str(_guest['email']);
  String? get guestTier => _strOrNull(_guest['tier']);

  Map<String, dynamic> get _room =>
      Map<String, dynamic>.from(raw['rooms'] as Map? ?? const {});
  String get roomName => _str(_room['name']);
  String? get roomNo => _strOrNull(_room['room_no']);

  Map<String, dynamic> get _property =>
      Map<String, dynamic>.from(raw['properties'] as Map? ?? const {});
  String get propertyName => _str(_property['name']);

  List<Map<String, dynamic>> get payments => _mapList(raw['payments']);
  String? get paymentStatus =>
      payments.isEmpty ? null : _strOrNull(payments.first['status']);
  int get paidAmount => payments
      .where((p) => p['status'] == 'paid')
      .fold(0, (sum, p) => sum + _int(p['amount']));

  List<Map<String, dynamic>> get cancellations => _mapList(raw['cancellations']);
  List<Map<String, dynamic>> get reviews => _mapList(raw['reviews']);
  Map<String, dynamic>? get promo =>
      raw['promos'] is Map ? Map<String, dynamic>.from(raw['promos'] as Map) : null;

  /// The one-way ladder the backend enforces. Anything else is a 400, so the
  /// UI offers exactly these and nothing more.
  String? get nextStatus => switch (status) {
        'pending' => 'confirmed',
        'confirmed' => 'staying',
        'staying' => 'done',
        _ => null,
      };

  String? get nextStatusLabel => switch (nextStatus) {
        'confirmed' => 'ຢືນຢັນການຈອງ',
        'staying' => 'ເຊັກອິນ (ເຂົ້າພັກ)',
        'done' => 'ເຊັກເອົາ (ພັກຈົບ)',
        _ => null,
      };

  bool get canCancel => status != 'cancelled' && status != 'done';
}

class PartnerDashboard {
  PartnerDashboard(this.raw);
  final Map<String, dynamic> raw;

  Map<String, dynamic> get _today =>
      Map<String, dynamic>.from(raw['today'] as Map? ?? const {});
  List<Map<String, dynamic>> get arrivals => _mapList(_today['arrivals']);
  int get arrivalCount => _int(_today['arrivalCount']);
  int get departureCount => _int(_today['departureCount']);
  int get stayingCount => _int(_today['stayingCount']);

  int get pendingBookings => _int(raw['pendingBookings']);

  Map<String, dynamic> get _occupancy =>
      Map<String, dynamic>.from(raw['occupancy'] as Map? ?? const {});
  int get occupancyPercent => _int(_occupancy['percent']);
  int get soldTonight => _int(_occupancy['soldTonight']);
  int get capacity => _int(_occupancy['capacity']);

  Map<String, dynamic> get _week =>
      Map<String, dynamic>.from(raw['week'] as Map? ?? const {});
  int get weekBookings => _int(_week['bookings']);
  int get weekGmv => _int(_week['gmv']);
  int get weekCommission => _int(_week['commission']);
  int get weekNet => _int(_week['net']);
  String? get weekStart => _strOrNull(_week['start']);
  String? get weekEnd => _strOrNull(_week['end']);

  Map<String, dynamic> get _payout =>
      Map<String, dynamic>.from(raw['payoutPending'] as Map? ?? const {});
  int get payoutPendingCount => _int(_payout['count']);
  int get payoutPendingAmount => _int(_payout['amount']);

  int get unreadNotifications => _int(raw['unreadNotifications']);
}

class Payout {
  Payout({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.gmv,
    required this.commission,
    required this.netAmount,
    required this.status,
    this.paidAt,
  });

  final String id;
  final String periodStart;
  final String periodEnd;
  final int gmv;
  final int commission;
  final int netAmount;
  final String status;
  final String? paidAt;

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        id: _str(j['id']),
        periodStart: _str(j['periodStart']),
        periodEnd: _str(j['periodEnd']),
        gmv: _int(j['gmv']),
        commission: _int(j['commission']),
        netAmount: _int(j['netAmount']),
        status: _str(j['status']),
        paidAt: _strOrNull(j['paidAt']),
      );
}

class Review {
  Review({
    required this.id,
    required this.stars,
    required this.property,
    required this.guest,
    this.text,
    this.bookingId,
  });

  final String id;
  final int stars;
  final String property;
  final String guest;
  final String? text;
  final String? bookingId;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: _str(j['id']),
        stars: _int(j['stars']),
        property: _str(j['property']),
        guest: _str(j['guest']),
        text: _strOrNull(j['text']),
        bookingId: _strOrNull(j['bookingId']),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderType,
    required this.body,
    required this.mine,
    this.sentAt,
    this.readAt,
  });

  final String id;
  final String senderType;
  final String body;
  final bool mine;
  final String? sentAt;
  final String? readAt;

  /// Ids arrive as strings but are monotonic integers; sorting and cursor
  /// comparison need the numeric value.
  int get seq => int.tryParse(id) ?? 0;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _str(j['id']),
        senderType: _str(j['senderType']),
        body: _str(j['body']),
        mine: _bool(j['mine']),
        sentAt: _strOrNull(j['sentAt']),
        readAt: _strOrNull(j['readAt']),
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _str(j['id']),
        title: _str(j['title']),
        body: _str(j['body']),
        type: _str(j['type']),
        isRead: _bool(j['is_read']),
        createdAt: _strOrNull(j['created_at']),
      );
}

/// One night on the pricing calendar.
class CalendarDay {
  CalendarDay({
    required this.date,
    required this.price,
    required this.status,
    required this.overridden,
  });

  final String date;
  final int price;
  final String status;

  /// False when the night has no `room_availability` row and is simply on sale
  /// at the room's base price.
  final bool overridden;

  bool get isBooked => status == 'booked';
  bool get isClosed => status == 'closed';

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        date: _str(j['date']),
        price: _int(j['price']),
        status: _str(j['status'], 'available'),
        overridden: _bool(j['overridden']),
      );
}

class RoomCalendar {
  RoomCalendar({
    required this.roomId,
    required this.basePrice,
    required this.qty,
    required this.days,
  });

  final String roomId;
  final int basePrice;
  final int qty;
  final List<CalendarDay> days;

  factory RoomCalendar.fromJson(Map<String, dynamic> j) => RoomCalendar(
        roomId: _str(j['roomId']),
        basePrice: _int(j['basePrice']),
        qty: _int(j['qty'], 1),
        days: _mapList(j['days']).map(CalendarDay.fromJson).toList(),
      );
}

/// `{items, total, page, limit, pages}` from the backend's `paged()` helper.
class Paged<T> {
  Paged({required this.items, required this.total, required this.page, required this.pages});

  final List<T> items;
  final int total;
  final int page;
  final int pages;

  bool get hasMore => page < pages;

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) =>
      Paged(
        items: _mapList(j['items']).map(item).toList(),
        total: _int(j['total']),
        page: _int(j['page'], 1),
        pages: _int(j['pages'], 1),
      );
}

int intOf(Object? v, [int fallback = 0]) => _int(v, fallback);
int? intOrNullOf(Object? v) => _intOrNull(v);
String strOf(Object? v, [String fallback = '']) => _str(v, fallback);
List<Map<String, dynamic>> mapListOf(Object? v) => _mapList(v);
