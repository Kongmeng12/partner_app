/// API models.
///
/// **Every id is a `String`.** The database uses `int8` throughout and the
/// backend's BigIntInterceptor serialises them as strings, because a booking id
/// past 2^53 cannot survive a JSON number. Parsing them into `int` here would
/// reintroduce exactly the bug that interceptor exists to prevent.
///
/// **Every amount is an `int` of whole kip.** Money is `bigint` in Postgres and
/// the view mappers convert it with `kipOf()` before it leaves the server, so
/// what arrives is a plain number of kip. No doubles, no minor unit.
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

/// One photo. v1 kept these as a jsonb array on the parent row; v2 gives them
/// their own tables, so each carries an id and can be deleted or promoted to
/// cover by that id rather than by position in a list.
class PhotoRef {
  PhotoRef({required this.id, required this.url, required this.isCover});

  final String id;
  final String url;
  final bool isCover;

  factory PhotoRef.fromJson(Map<String, dynamic> j) => PhotoRef(
        id: _str(j['id']),
        url: _str(j['url']),
        isCover: _bool(j['isCover']),
      );
}

List<PhotoRef> _photos(Object? v) => _mapList(v).map(PhotoRef.fromJson).toList();

/// A bank account, as `/partner/me` returns it — the number always masked.
class BankAccount {
  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.account,
    required this.isDefault,
  });

  final String id;
  final String bankName;
  final String accountName;

  /// `***1234`. The full number never leaves the server.
  final String account;
  final bool isDefault;

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: _str(j['id']),
        bankName: _str(j['bankName']),
        accountName: _str(j['accountName']),
        account: _str(j['account']),
        isDefault: _bool(j['isDefault']),
      );
}

/// `GET /partner/me`.
class Partner {
  Partner({
    required this.id,
    required this.businessName,
    required this.email,
    required this.ownerName,
    required this.phone,
    required this.status,
    this.businessType,
    this.taxId,
    this.verifiedAt,
    this.commissionRate,
    this.walkinCommissionRate,
    this.propertyCount = 0,
    this.bankAccounts = const [],
  });

  final String id;
  final String businessName;
  final String email;
  final String ownerName;
  final String phone;

  /// `partner_status`: pending · verified · rejected · suspended.
  final String status;
  final String? businessType;
  final String? taxId;
  final String? verifiedAt;

  /// Percentages, e.g. 5 for 5%.
  final double? commissionRate;
  final double? walkinCommissionRate;
  final int propertyCount;
  final List<BankAccount> bankAccounts;

  bool get isVerified => status == 'verified';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';

  BankAccount? get defaultBank => bankAccounts.isEmpty
      ? null
      : bankAccounts.firstWhere((b) => b.isDefault, orElse: () => bankAccounts.first);

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: _str(j['id']),
        businessName: _str(j['businessName']),
        email: _str(j['email']),
        ownerName: _str(j['ownerName']),
        phone: _str(j['contactPhone']),
        status: _str(j['status'], 'pending'),
        businessType: _strOrNull(j['businessType']),
        taxId: _strOrNull(j['taxId']),
        verifiedAt: _strOrNull(j['verifiedAt']),
        commissionRate: _double(j['commissionRate']),
        walkinCommissionRate: _double(j['walkinCommissionRate']),
        propertyCount: _int(j['propertyCount']),
        bankAccounts: _mapList(j['bankAccounts']).map(BankAccount.fromJson).toList(),
      );
}

/// A category of room, not a single room.
///
/// v1 modelled each physical room with its own number; v2 models the type —
/// "Standard AC" — with `totalRooms` of them. Availability is therefore a count
/// per night rather than a booked/free flag, which is what makes it possible to
/// sell the last of eight identical rooms without tracking which one.
class RoomType {
  RoomType({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.bedType,
    required this.basePrice,
    required this.maxOccupancy,
    required this.totalRooms,
    required this.minNights,
    required this.isActive,
    required this.hasAc,
    this.description,
    this.sizeSqm,
    this.extraGuestFee = 0,
    this.photos = const [],
  });

  final String id;
  final String propertyId;
  final String name;
  final String? description;
  final bool hasAc;
  final String bedType;
  final int basePrice;
  final int maxOccupancy;

  /// How many rooms of this type exist — the nightly ceiling.
  final int totalRooms;
  final int minNights;
  final int extraGuestFee;
  final int? sizeSqm;
  final bool isActive;
  final List<PhotoRef> photos;

  String get label => '$name × $totalRooms';

  factory RoomType.fromJson(Map<String, dynamic> j) => RoomType(
        id: _str(j['id']),
        propertyId: _str(j['propertyId']),
        name: _str(j['name']),
        description: _strOrNull(j['description']),
        hasAc: _bool(j['hasAc'], true),
        bedType: _str(j['bedType']),
        basePrice: _int(j['basePrice']),
        maxOccupancy: _int(j['maxOccupancy'], 1),
        totalRooms: _int(j['totalRooms'], 1),
        minNights: _int(j['minNights'], 1),
        extraGuestFee: _int(j['extraGuestFee']),
        sizeSqm: _intOrNull(j['sizeSqm']),
        isActive: _bool(j['isActive'], true),
        photos: _photos(j['images']),
      );
}

class Property {
  Property({
    required this.id,
    required this.name,
    required this.type,
    required this.roomTypes,
    this.description,
    this.phone,
    this.province,
    this.district,
    this.address,
    this.lat,
    this.lng,
    this.rating,
    this.reviewCount = 0,
    this.status = 'draft',
    this.amenityIds = const [],
    this.photos = const [],
    this.bookingCount = 0,
  });

  final String id;
  final String name;
  final String type;
  final String? description;
  final String? phone;
  final String? province;
  final String? district;
  final String? address;
  final double? lat;
  final double? lng;
  final double? rating;
  final int reviewCount;

  /// `property_status`: draft · active · suspended. A property stays `draft`
  /// until the partner is approved, and is invisible in search until then.
  final String status;
  final List<String> amenityIds;
  final List<PhotoRef> photos;
  final List<RoomType> roomTypes;
  final int bookingCount;

  bool get isActive => status == 'active';

  String get location =>
      [district, province].where((s) => s != null && s.isNotEmpty).join(', ');

  factory Property.fromJson(Map<String, dynamic> j) => Property(
        id: _str(j['id']),
        name: _str(j['name']),
        type: _str(j['type']),
        description: _strOrNull(j['description']),
        phone: _strOrNull(j['phone']),
        province: _strOrNull(j['province']),
        district: _strOrNull(j['district']),
        address: _strOrNull(j['address']),
        lat: _double(j['lat']),
        lng: _double(j['lng']),
        rating: _double(j['rating']),
        reviewCount: _int(j['reviewCount']),
        status: _str(j['status'], 'draft'),
        amenityIds: (j['amenityIds'] as List?)?.map(_str).toList() ?? const [],
        photos: _photos(j['images']),
        roomTypes: _mapList(j['roomTypes']).map(RoomType.fromJson).toList(),
        bookingCount: _int(j['bookingCount']),
      );
}

class BookingSummary {
  BookingSummary({
    required this.id,
    required this.code,
    required this.property,
    required this.guest,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.guests,
    required this.total,
    required this.payout,
    required this.status,
    required this.source,
    this.propertyId,
    this.guestPhone,
    this.roomType,
    this.quantity = 1,
    this.paymentStatus,
    this.createdAt,
  });

  final String id;
  final String code;
  final String? propertyId;
  final String property;
  final String guest;
  final String? guestPhone;
  final String? roomType;
  final int quantity;
  final String checkIn;
  final String checkOut;
  final int nights;
  final int guests;
  final int total;

  /// What the property keeps once commission is taken.
  final int payout;
  final String status;
  final String source;
  final String? paymentStatus;
  final String? createdAt;

  bool get isWalkIn => source == 'walk_in';

  factory BookingSummary.fromJson(Map<String, dynamic> j) => BookingSummary(
        id: _str(j['id']),
        code: _str(j['code']),
        propertyId: _strOrNull(j['propertyId']),
        property: _str(j['property']),
        guest: _str(j['guest']),
        guestPhone: _strOrNull(j['guestPhone']),
        roomType: _strOrNull(j['roomType']),
        quantity: _int(j['quantity'], 1),
        checkIn: _str(j['checkIn']),
        checkOut: _str(j['checkOut']),
        nights: _int(j['nights']),
        guests: _int(j['guests'], 1),
        total: _int(j['total']),
        payout: _int(j['payout']),
        status: _str(j['status']),
        source: _str(j['source'], 'app'),
        paymentStatus: _strOrNull(j['paymentStatus']),
        createdAt: _strOrNull(j['createdAt']),
      );
}

/// `GET /partner/bookings/:id` — camelCase and flat, unlike v1's raw row.
class BookingDetail {
  BookingDetail(this.raw);
  final Map<String, dynamic> raw;

  String get id => _str(raw['id']);
  String get code => _str(raw['code']);
  String get status => _str(raw['status']);
  String get source => _str(raw['source'], 'app');
  String get checkIn => _str(raw['checkIn']);
  String get checkOut => _str(raw['checkOut']);
  int get nights => _int(raw['nights']);
  int get guests => _int(raw['guests'], 1);
  int get subtotal => _int(raw['subtotal']);
  int get serviceFee => _int(raw['serviceFee']);
  int get tax => _int(raw['tax']);
  int get cleaningFee => _int(raw['cleaningFee']);
  int get discount => _int(raw['discount']);
  int get total => _int(raw['total']);
  int get commission => _int(raw['commission']);
  double get commissionRate => _double(raw['commissionRate']) ?? 0;

  /// What the property is owed for this stay.
  int get payout => _int(raw['payout']);
  String? get specialRequest => _strOrNull(raw['specialRequest']);
  String? get createdAt => _strOrNull(raw['createdAt']);
  String? get holdExpiresAt => _strOrNull(raw['holdExpiresAt']);
  bool get isWalkIn => source == 'walk_in';

  Map<String, dynamic> get _guest =>
      Map<String, dynamic>.from(raw['guest'] as Map? ?? const {});
  String get guestName => _str(_guest['name'], '—');
  String get guestPhone => _str(_guest['phone']);
  String get guestEmail => _str(_guest['email']);

  Map<String, dynamic>? get _roomType =>
      raw['roomType'] is Map ? Map<String, dynamic>.from(raw['roomType'] as Map) : null;
  String get roomTypeName => _str(_roomType?['name'], '—');
  int get roomQuantity => _int(_roomType?['quantity'], 1);
  int get pricePerNight => _int(_roomType?['pricePerNight']);

  Map<String, dynamic> get _property =>
      Map<String, dynamic>.from(raw['property'] as Map? ?? const {});
  String get propertyName => _str(_property['name']);

  List<Map<String, dynamic>> get payments => _mapList(raw['payments']);
  String? get paymentStatus =>
      payments.isEmpty ? null : _strOrNull(payments.first['status']);
  int get paidAmount => payments
      .where((p) => p['status'] == 'paid')
      .fold(0, (sum, p) => sum + _int(p['amount']));

  /// The one-way ladder the backend enforces. Anything else is a 400, so the
  /// UI offers exactly these and nothing more.
  String? get nextStatus => switch (status) {
        'pending' => 'confirmed',
        'confirmed' => 'staying',
        'staying' => 'completed',
        _ => null,
      };

  String? get nextStatusLabel => switch (nextStatus) {
        'confirmed' => 'ຢືນຢັນການຈອງ',
        'staying' => 'ເຊັກອິນ (ເຂົ້າພັກ)',
        'completed' => 'ເຊັກເອົາ (ພັກຈົບ)',
        _ => null,
      };

  /// A finished or already-cancelled stay cannot be cancelled; the API refuses
  /// both with a 400.
  bool get canCancel =>
      status != 'cancelled' && status != 'completed' && status != 'no_show';
}

/// `GET /partner/dashboard`.
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
  int get weekGross => _int(_week['gross']);
  int get weekCommission => _int(_week['commission']);
  int get weekNet => _int(_week['net']);

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
    required this.gross,
    required this.commission,
    required this.net,
    required this.status,
    required this.bookings,
    this.paidAt,
    this.bankName,
    this.bankAccount,
  });

  final String id;
  final String periodStart;
  final String periodEnd;
  final int gross;
  final int commission;
  final int net;

  /// `payout_status`: pending · processing · paid · failed.
  final String status;

  /// How many bookings this payout covers — one `payout_item` each.
  final int bookings;
  final String? paidAt;
  final String? bankName;
  final String? bankAccount;

  bool get isPaid => status == 'paid';

  factory Payout.fromJson(Map<String, dynamic> j) {
    final bank = j['bank'] is Map ? Map<String, dynamic>.from(j['bank'] as Map) : null;
    return Payout(
      id: _str(j['id']),
      periodStart: _str(j['periodStart']),
      periodEnd: _str(j['periodEnd']),
      gross: _int(j['gross']),
      commission: _int(j['commission']),
      net: _int(j['net']),
      status: _str(j['status']),
      bookings: _int(j['bookings']),
      paidAt: _strOrNull(j['paidAt']),
      bankName: _strOrNull(bank?['name']),
      bankAccount: _strOrNull(bank?['account']),
    );
  }
}

class Review {
  Review({
    required this.id,
    required this.stars,
    required this.property,
    required this.guest,
    this.title,
    this.comment,
    this.createdAt,
  });

  final String id;
  final int stars;
  final String property;
  final String guest;
  final String? title;
  final String? comment;
  final String? createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: _str(j['id']),
        stars: _int(j['stars']),
        property: _str(j['property']),
        guest: _str(j['guest']),
        title: _strOrNull(j['title']),
        comment: _strOrNull(j['comment']),
        createdAt: _strOrNull(j['createdAt']),
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
        body: _str(j['message']),
        type: _str(j['type']),
        isRead: _bool(j['isRead']),
        createdAt: _strOrNull(j['createdAt']),
      );
}

/// One night on the calendar.
///
/// The three counters are what the database holds: `total` rooms of this type,
/// `held` waiting on a checkout that has not paid, `booked` sold. `available`
/// is generated from them, so it is read rather than computed here.
class CalendarDay {
  CalendarDay({
    required this.date,
    required this.price,
    required this.total,
    required this.held,
    required this.booked,
    required this.available,
    required this.onSale,
  });

  final String date;
  final int price;
  final int total;
  final int held;
  final int booked;
  final int available;

  /// False when the night is closed, or was never opened for sale at all.
  final bool onSale;

  bool get isFull => onSale && available <= 0;
  bool get isClosed => !onSale;

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        date: _str(j['date']),
        price: _int(j['price']),
        total: _int(j['total']),
        held: _int(j['held']),
        booked: _int(j['booked']),
        available: _int(j['available']),
        onSale: _bool(j['onSale']),
      );
}

class RoomCalendar {
  RoomCalendar({required this.roomTypeId, required this.days});

  final String roomTypeId;
  final List<CalendarDay> days;

  factory RoomCalendar.fromJson(Map<String, dynamic> j) => RoomCalendar(
        roomTypeId: _str(j['roomTypeId']),
        days: _mapList(j['days']).map(CalendarDay.fromJson).toList(),
      );
}

/// One guest ↔ property thread.
///
/// A conversation belongs to a **property**, not to a booking: `bookingId` is
/// optional because a guest asking a question before booking is exactly the
/// conversation worth having. Only a guest can open one, so this app never
/// creates them — it answers.
class Conversation {
  Conversation({
    required this.id,
    required this.propertyId,
    required this.property,
    required this.counterpartName,
    required this.status,
    required this.unread,
    this.bookingId,
    this.bookingCode,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageMine = false,
  });

  final String id;
  final String propertyId;
  final String property;

  /// Whichever side we are not — the guest, from this app.
  final String counterpartName;
  final String status;
  final int unread;
  final String? bookingId;
  final String? bookingCode;

  /// Null when the newest message was deleted; the row stays, the text goes.
  final String? lastMessage;
  final String? lastMessageAt;
  final bool lastMessageMine;

  bool get isClosed => status == 'closed';

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: _str(j['id']),
        propertyId: _str(j['propertyId']),
        property: _str(j['property']),
        counterpartName: _str(j['counterpartName']),
        status: _str(j['status'], 'open'),
        unread: _int(j['unread']),
        bookingId: _strOrNull(j['bookingId']),
        bookingCode: _strOrNull(j['bookingCode']),
        lastMessage: _strOrNull(j['lastMessage']),
        lastMessageAt: _strOrNull(j['lastMessageAt']),
        lastMessageMine: _bool(j['lastMessageMine']),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.mine,
    required this.type,
    required this.isDeleted,
    required this.isEdited,
    this.text,
    this.replyToId,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final bool mine;
  final String type;

  /// Null once deleted — the row stays so the thread still reads in order.
  final String? text;
  final bool isDeleted;
  final bool isEdited;
  final String? replyToId;
  final String? createdAt;

  /// Ids are monotonic integers, which is what makes them a safe poll cursor:
  /// two messages in the same millisecond would break a time-based one.
  int get seq => int.tryParse(id) ?? 0;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _str(j['id']),
        senderId: _str(j['senderId']),
        senderName: _str(j['senderName']),
        mine: _bool(j['mine']),
        type: _str(j['type'], 'text'),
        text: _strOrNull(j['text']),
        isDeleted: _bool(j['isDeleted']),
        isEdited: _bool(j['isEdited']),
        replyToId: _strOrNull(j['replyToId']),
        createdAt: _strOrNull(j['createdAt']),
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
