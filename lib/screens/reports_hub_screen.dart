import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/dates.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/report_specs.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/date_range_sheet.dart';

/// Sentinel popped by the property-filter sheet's "ທຸກທີ່ພັກ" row so it can
/// be told apart from a plain dismiss (tap outside), which also pops `null`.
const _kAllProperties = '__all__';

/// Entry point for `/more/reports` — a persistent date-range (and, for a
/// partner with more than one property, property) filter, plus a grid of the
/// seven report types each showing its own live headline number for the
/// current range, so the hub reads as a mini-dashboard rather than a menu.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final bucket = ref.watch(reportBucketProvider);
    final propertyId = ref.watch(reportPropertyFilterProvider);
    final properties = ref.watch(propertiesProvider).value ?? const <Property>[];

    return Scaffold(
      appBar: AppBar(title: const Text('ລາຍງານ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
              if (properties.length > 1)
                QuickChip(
                  label: propertyId == null
                      ? 'ທຸກທີ່ພັກ'
                      : properties
                          .firstWhere((p) => p.id == propertyId, orElse: () => properties.first)
                          .name,
                  onTap: () => _pickProperty(context, ref, properties, propertyId),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (final type in ReportType.values)
                _ReportTile(
                  type: type,
                  from: range.from,
                  to: range.to,
                  bucket: bucket,
                  propertyId: propertyId,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickProperty(
    BuildContext context,
    WidgetRef ref,
    List<Property> properties,
    String? current,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('ທຸກທີ່ພັກ'),
              trailing: current == null ? const Icon(Icons.check, color: C.accent) : null,
              onTap: () => Navigator.of(context).pop(_kAllProperties),
            ),
            for (final p in properties)
              ListTile(
                title: Text(p.name),
                trailing: current == p.id ? const Icon(Icons.check, color: C.accent) : null,
                onTap: () => Navigator.of(context).pop(p.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref
          .read(reportPropertyFilterProvider.notifier)
          .set(picked == _kAllProperties ? null : picked);
    }
  }
}

class _ReportTile extends ConsumerWidget {
  const _ReportTile({
    required this.type,
    required this.from,
    required this.to,
    required this.bucket,
    required this.propertyId,
  });

  final ReportType type;
  final DateTime from;
  final DateTime to;
  final String bucket;
  final String? propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = reportSpecs[type]!;
    final result = ref.watch(
      reportProvider((type: type, from: from, to: to, bucket: bucket, propertyId: propertyId)),
    );

    return InkWell(
      onTap: () => context.go('/more/reports/${type.path}'),
      borderRadius: BorderRadius.circular(R.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(spec.icon, color: C.accentDark, size: 22),
            const Spacer(),
            Text(
              spec.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.soft),
            ),
            const SizedBox(height: 4),
            result.when(
              loading: () => const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: C.accent),
              ),
              error: (_, __) => const Text(
                '—',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.muted),
              ),
              data: (r) => Text(
                formatValue(r.kpis[spec.headline.key], spec.headline.format),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
