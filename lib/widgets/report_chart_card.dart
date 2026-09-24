import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/money.dart';
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

    var maxY = 1.0;
    for (final p in series) {
      for (final l in lines) {
        final v = ((p[l.key] as num?) ?? 0).toDouble();
        if (v > maxY) maxY = v;
      }
    }
    maxY *= 1.2;

    final labelEvery = (series.length / 5).ceil().clamp(1, series.length);
    final moneyAxis = lines.first.format == ValueFormat.money || lines.first.format == ValueFormat.moneyShort;

    return SectionCard(
      title: 'ແນວໂນ້ມ',
      trailing: lines.length > 1
          ? Wrap(
              spacing: 12,
              children: [for (final l in lines) _LegendDot(color: l.color, label: l.label)],
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
              horizontalInterval: maxY / 4 == 0 ? 1 : maxY / 4,
              getDrawingHorizontalLine: (_) => const FlLine(color: C.divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (v, meta) => Text(
                    moneyAxis ? kipShort(v) : v.round().toString(),
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
              for (final l in lines)
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < series.length; i++)
                      FlSpot(i.toDouble(), ((series[i][l.key] as num?) ?? 0).toDouble()),
                  ],
                  color: l.color,
                  barWidth: 2.4,
                  isCurved: true,
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: C.muted)),
      ],
    );
  }
}
