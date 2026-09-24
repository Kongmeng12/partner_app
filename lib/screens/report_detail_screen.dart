import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../providers/data.dart';
import '../theme/report_specs.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/date_range_sheet.dart';
import '../widgets/export_sheet.dart';
import '../widgets/report_chart_card.dart';

/// One parametrized screen for all seven report types — [ReportSpec] (in
/// `theme/report_specs.dart`) says which KPI fields, chart lines and
/// breakdown columns to render, so an eighth report later is a config entry
/// here, not a new screen.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.typePath});

  final String typePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ReportTypePath.fromPath(typePath);
    final spec = type == null ? null : reportSpecs[type];

    if (type == null || spec == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ລາຍງານ')),
        body: const EmptyState(message: 'ບໍ່ພົບລາຍງານນີ້', icon: Icons.error_outline),
      );
    }

    final range = ref.watch(reportRangeProvider);
    final bucket = ref.watch(reportBucketProvider);
    final propertyId = ref.watch(reportPropertyFilterProvider);
    final key = (
      type: type,
      from: range.from,
      to: range.to,
      bucket: bucket,
      propertyId: propertyId,
    );
    final result = ref.watch(reportProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: Text(spec.title),
        actions: [
          IconButton(
            onPressed: result.value == null
                ? null
                : () => ExportSheet.show(context, result.value!, spec),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: result.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(reportProvider(key))),
        data: (report) => RefreshIndicator(
          color: C.accent,
          onRefresh: () async => ref.invalidate(reportProvider(key)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _ContextBar(spec: spec, range: range),
              const SizedBox(height: 14),
              _KpiGrid(spec: spec, kpis: report.kpis),
              if (type == ReportType.bookings) ...[
                const SizedBox(height: 10),
                _StatusChips(
                  byStatus: Map<String, dynamic>.from(report.kpis['byStatus'] as Map? ?? const {}),
                ),
              ],
              const SizedBox(height: 14),
              ReportChartCard(series: report.series, lines: spec.chartLines),
              const SizedBox(height: 14),
              SectionCard(
                title: 'ລາຍລະອຽດ',
                child: report.breakdown.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          spec.emptyMessage,
                          style: const TextStyle(color: C.muted, fontSize: 13.5),
                        ),
                      )
                    : _BreakdownTable(spec: spec, rows: report.breakdown),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextBar extends ConsumerWidget {
  const _ContextBar({required this.spec, required this.range});

  final ReportSpec spec;
  final ({DateTime from, DateTime to}) range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucket = ref.watch(reportBucketProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        QuickChip(
          label: laoDateRange(
            range.from.toIso8601String(),
            addDays(range.to, -1).toIso8601String(),
          ),
          onTap: () async {
            final picked = await DateRangeSheet.show(context, range);
            if (picked != null) {
              ref.read(reportRangeProvider.notifier).set(picked.from, picked.to);
            }
          },
        ),
        if (spec.bucketable)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'day', label: Text('ວັນ')),
              ButtonSegment(value: 'week', label: Text('ອາທິດ')),
              ButtonSegment(value: 'month', label: Text('ເດືອນ')),
            ],
            selected: {bucket},
            onSelectionChanged: (v) => ref.read(reportBucketProvider.notifier).set(v.first),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: C.accentSoft,
              selectedForegroundColor: C.accentDark,
            ),
          ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.spec, required this.kpis});

  final ReportSpec spec;
  final Map<String, dynamic> kpis;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: [
        for (final f in spec.kpis) StatTile(label: f.label, value: formatValue(kpis[f.key], f.format)),
      ],
    );
  }
}

/// The `bookings` report's `kpis.byStatus` map, shown as small count pills —
/// the one field shape none of the other six reports carry.
class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.byStatus});

  final Map<String, dynamic> byStatus;

  @override
  Widget build(BuildContext context) {
    if (byStatus.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in byStatus.entries)
          Builder(builder: (context) {
            final pill = pillFor(bookingStatusPill, entry.key);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: pill.bg, borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${pill.label} ${entry.value}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: pill.fg),
              ),
            );
          }),
      ],
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({required this.spec, required this.rows});

  final ReportSpec spec;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  (row['label'] ?? '—').toString(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.text),
                ),
              ),
              for (final c in spec.breakdownColumns)
                Expanded(
                  child: Text(
                    formatValue(row[c.key], c.format),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 13, color: C.soft),
                  ),
                ),
            ],
          ),
          if (row != rows.last) const Divider(height: 16),
        ],
      ],
    );
  }
}
