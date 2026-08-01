/// Kip formatting, ported from `webadmin/src/lib/format.ts`.
///
/// Every amount the API sends is an `int` of whole kip — there are no subunits.
/// Nothing here converts to `double`: a stay of 1,350,000 kip must render as
/// exactly that, and floating point has no business anywhere near money.
library;

const _kipSign = '₭';

/// `₭1,350,000`
String kip(num? amount) {
  if (amount == null) return '—';
  return '$_kipSign${_grouped(amount.round())}';
}

/// `₭18.4M` / `₭628K` — for tiles where the full number will not fit.
String kipShort(num? amount) {
  if (amount == null) return '—';
  final n = amount.round();
  final abs = n.abs();
  if (abs >= 1000000) {
    final m = (n / 1000000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    return '$_kipSign${m}M';
  }
  if (abs >= 1000) return '$_kipSign${(n / 1000).round()}K';
  return '$_kipSign$n';
}

/// Thousands separators, without pulling in a locale — the grouping is the same
/// in both languages the app shows and `intl` would need initialising first.
String _grouped(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// `▲ 12%` / `▼ 4%`, plus whether it is a rise — the caller picks the colour.
({String text, bool? up}) deltaLabel(int? percent, {String suffix = ''}) {
  if (percent == null) return (text: 'ບໍ່ມີຂໍ້ມູນປຽບທຽບ', up: null);
  if (percent == 0) return (text: 'ເທົ່າເດີມ $suffix'.trim(), up: null);
  final up = percent > 0;
  return (text: '${up ? '▲' : '▼'} ${percent.abs()}% $suffix'.trim(), up: up);
}

/// `★★★★☆`
String stars(int n) {
  final filled = n.clamp(0, 5);
  return '★' * filled + '☆' * (5 - filled);
}

/// Last name initial, for avatars. Lao sits in the BMP, so one UTF-16 unit is
/// one character here.
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.last.substring(0, 1).toUpperCase();
}
