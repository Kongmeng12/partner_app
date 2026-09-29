import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../theme/report_specs.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// The trend chart on a report's detail screen — one or two lines over the
/// bucketed `series`, x-axis labelled sparsely so a 366-point day series
/// doesn't crowd into unreadable text.
class ReportChartCard extends StatelessWidget {
  const ReportChartCard({super.key, required this.series, required this.lines});

  final List<Map<String, dynamic>> series;
  final List<ChartLine> lines;

  @override
  Widget build(BuildContext context) {
    final hasData = series.isNotEmpty &&
        series.any((p) => lines.any((l) => ((p[l.key] as num?) ?? 0) != 0));

    if (!hasData) {
      return SectionCard(
        title: 'ແນວໂນ້ມ',
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'ຍັງບໍ່ມີຂໍ້ມູນສະແດງກຣາຟໃນຊ່ວງນີ້',
              style: TextStyle(color: C.muted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    var top = 1.0;
    for (final p in series) {
      for (final l in lines) {
        final v = ((p[l.key] as num?) ?? 0).toDouble();
        if (v > top) top = v;
      }
    }
    final format = lines.first.format;
    final (:maxY, :step) = _axisScale(top, format);

    final labelEvery = (series.length / 5).ceil().clamp(1, series.length);

    return SectionCard(
      title: 'ແນວໂນ້ມ',
      trailing: lines.length > 1
          ? Wrap(
              spacing: 12,
              children: [
                for (final (i, l) in lines.indexed)
                  _LegendSwatch(color: l.color, label: l.label, dashed: _isDashed(i)),
              ],
            )
          : null,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              // The same step as the labels, so every label sits on a line.
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) => const FlLine(color: C.divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: step,
                  reservedSize: 44,
                  getTitlesWidget: (v, meta) => Text(
                    _axisLabelY(v, format),
                    style: const TextStyle(fontSize: 10, color: C.muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: labelEvery.toDouble(),
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.round();
                    if (i < 0 || i >= series.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _axisLabel(series[i]['bucket'] as String? ?? ''),
                        style: const TextStyle(fontSize: 9.5, color: C.muted),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      formatValue(s.y, lines[s.barIndex].format),
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (final (i, l) in lines.indexed)
                LineChartBarData(
                  spots: [
                    for (var j = 0; j < series.length; j++)
                      FlSpot(j.toDouble(), ((series[j][l.key] as num?) ?? 0).toDouble()),
                  ],
                  color: l.color,
                  barWidth: 2.4,
                  // The second line is drawn on top and is often the same
                  // amount as the first — net equals gross whenever commission
                  // is ₭0 — so solid it would hide the first line entirely.
                  // Dashed, the first still shows through the gaps.
                  dashArray: _isDashed(i) ? const [6, 4] : null,
                  isCurved: true,
                  // Without this the smoothing swings past the real values: a
                  // drop to ₭0 dips below the axis, as if there were negative
                  // sales, and a peak is drawn higher than it was.
                  preventCurveOverShooting: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: lines.length == 1, color: l.color.withValues(alpha: 0.12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `2026-09-10` (day/week bucket) or `2026-09-01` (month bucket) → `10 ກ.ຍ.`.
String _axisLabel(String bucketKey) {
  if (bucketKey.isEmpty) return '';
  return laoDate('${bucketKey}T00:00:00.000Z');
}

/// The top of the y-axis and the gap between its gridlines.
///
/// The step is a round number — 1, 2 or 5 times a power of ten — and the top
/// is a whole number of steps with some room above the highest point, so each
/// label lands on a gridline and reads as a round amount. Ratings and
/// percentages keep their natural scale (0–5, 0–100%).
({double maxY, double step}) _axisScale(double top, ValueFormat format) {
  if (format == ValueFormat.rating) return (maxY: 5, step: 1);
  if (format == ValueFormat.percent && top <= 100) return (maxY: 100, step: 25);

  final target = top * 1.1 / 5;
  final base = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
  var step = 10 * base;
  for (final m in const [1, 2, 5]) {
    if (m * base >= target) {
      step = m * base;
      break;
    }
  }
  // Every label is a whole number — a step below 1 would repeat "0", "0", "1".
  if (step < 1) step = 1;
  return (maxY: (top * 1.1 / step).ceil() * step, step: step);
}

/// One y-axis label. Money is shortened like `kipShort` but keeps a decimal,
/// because the gridlines can fall between whole thousands: with a ₭500 step
/// they are ₭1K and ₭1.5K, which `kipShort` would round to ₭1K and ₭2K.
String _axisLabelY(double v, ValueFormat format) {
  switch (format) {
    case ValueFormat.money:
    case ValueFormat.moneyShort:
      final abs = v.abs();
      if (abs >= 1e6) return '₭${_trimmed(v / 1e6, 2)}M';
      if (abs >= 1e3) return '₭${_trimmed(v / 1e3, 1)}K';
      return '₭${v.round()}';
    case ValueFormat.percent:
      return '${v.round()}%';
    default:
      return v.round().toString();
  }
}

/// `1.50` → `1.5`, `2.00` → `2`, but `10` stays `10`.
String _trimmed(double value, int digits) {
  final s = value.toStringAsFixed(digits);
  if (!s.contains('.')) return s;
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// Every line after the first — the ones drawn on top of another.
bool _isDashed(int lineIndex) => lineIndex > 0;

/// A short sample of the line itself, solid or dashed, so the legend says
/// which line is which even where the two lie on top of each other.
class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label, required this.dashed});
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    Widget segment(double width) => Container(
          width: width,
          height: 2.4,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed) ...[segment(5), const SizedBox(width: 3), segment(5)] else segment(13),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: C.muted)),
      ],
    );
  }
}
