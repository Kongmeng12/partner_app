/// Date handling, ported from `backend/src/common/dates.ts` and
/// `webadmin/src/lib/format.ts`.
///
/// The API sends two different kinds of instant and they must not be read the
/// same way:
///
///  * **Calendar days** — `check_in`, `check_out`, `period_start`,
///    `room_availability.date` — come from PostgreSQL `date` columns and arrive
///    as `2026-08-13T00:00:00.000Z`. Reading those with local getters shows the
///    12th anywhere west of UTC and the 14th far enough east. They are read in
///    **UTC**, always.
///  * **Real timestamps** — `paid_at`, `sent_at`, `created_at` — are moments in
///    time and are shown in the partner's own clock.
///
/// This is the bug the backend README calls out as "ເຄີຍພາດມາແລ້ວ". It is easy
/// to reintroduce: one `DateTime.parse(x).day` is all it takes.
library;

const _laoMonthsShort = [
  'ມ.ກ.', 'ກ.ພ.', 'ມີ.ນ.', 'ມ.ສ.', 'ພ.ພ.', 'ມິ.ຖ.',
  'ກ.ຄ.', 'ສ.ຫ.', 'ກ.ຍ.', 'ຕ.ລ.', 'ພ.ຈ.', 'ທ.ວ.',
];

/// True when the value is a date-only column rendered as UTC midnight.
bool isDateOnly(String value) =>
    RegExp(r'T00:00:00(\.000)?Z$').hasMatch(value);

/// Parses an API string into the calendar day it denotes.
///
/// Date-only values keep their UTC day; real timestamps are converted to local
/// time first, because that is the day the user experienced them on.
DateTime? parseDay(Object? value) {
  if (value == null) return null;

  if (value is DateTime) {
    return DateTime.utc(value.year, value.month, value.day);
  }
  if (value is! String || value.isEmpty) return null;

  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;

  if (isDateOnly(value)) {
    final u = parsed.toUtc();
    return DateTime.utc(u.year, u.month, u.day);
  }
  final l = parsed.toLocal();
  return DateTime.utc(l.year, l.month, l.day);
}

/// `13 ສ.ຫ.`
String laoDate(Object? value) {
  final d = parseDay(value);
  if (d == null) return '—';
  return '${d.day} ${_laoMonthsShort[d.month - 1]}';
}

/// `12–15 ກ.ຄ.`, collapsing the month when both dates share one.
String laoDateRange(Object? from, Object? to) {
  final a = parseDay(from);
  final b = parseDay(to);
  if (a == null || b == null) return '—';
  if (a.month == b.month && a.year == b.year) {
    return '${a.day}–${b.day} ${_laoMonthsShort[a.month - 1]}';
  }
  return '${laoDate(from)} – ${laoDate(to)}';
}

/// `13 ສ.ຫ. 2026 · 14:30` — a real timestamp, in the reader's own clock.
String laoDateTime(Object? value) {
  if (value == null) return '—';
  final parsed = value is DateTime ? value : DateTime.tryParse(value.toString());
  if (parsed == null) return '—';
  final d = parsed.toLocal();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_laoMonthsShort[d.month - 1]} ${d.year} · $hh:$mm';
}

/// `10 ນາທີທີ່ແລ້ວ`
String laoAgo(Object? value) {
  if (value == null) return '—';
  final parsed = value is DateTime ? value : DateTime.tryParse(value.toString());
  if (parsed == null) return '—';

  final secs = DateTime.now().difference(parsed.toLocal()).inSeconds;
  if (secs < 60) return 'ຫາກໍ່ນີ້';
  if (secs < 3600) return '${secs ~/ 60} ນາທີທີ່ແລ້ວ';
  if (secs < 86400) return '${secs ~/ 3600} ຊົ່ວໂມງທີ່ແລ້ວ';
  if (secs < 172800) return 'ມື້ວານນີ້';
  if (secs < 2592000) return '${secs ~/ 86400} ມື້ກ່ອນ';
  return laoDate(value);
}

/// `2026-08-13` — the form every date query parameter and body field takes.
String apiDay(DateTime day) {
  final u = day.isUtc ? day : DateTime.utc(day.year, day.month, day.day);
  final m = u.month.toString().padLeft(2, '0');
  final d = u.day.toString().padLeft(2, '0');
  return '${u.year}-$m-$d';
}

/// Today as UTC midnight — the anchor every date picker starts from.
DateTime todayUtc() {
  final n = DateTime.now();
  return DateTime.utc(n.year, n.month, n.day);
}

DateTime addDays(DateTime day, int n) =>
    DateTime.utc(day.year, day.month, day.day + n);

/// Nights between two calendar days. Check-out is not charged.
int nightsBetween(Object? checkIn, Object? checkOut) {
  final a = parseDay(checkIn);
  final b = parseDay(checkOut);
  if (a == null || b == null) return 0;
  return b.difference(a).inDays;
}

/// Lao weekday initials for the calendar header, starting Monday.
const laoWeekdaysShort = ['ຈ', 'ອ', 'ພ', 'ພຫ', 'ສຸ', 'ສ', 'ອາ'];
