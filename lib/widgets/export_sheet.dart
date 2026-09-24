import 'package:flutter/material.dart';

import '../core/report_export.dart';
import '../models/models.dart';
import '../theme/report_specs.dart';
import '../theme/tokens.dart';

/// The export-format picker opened from a report detail screen's AppBar.
class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key, required this.report, required this.spec});

  final ReportResult report;
  final ReportSpec spec;

  static Future<void> show(BuildContext context, ReportResult report, ReportSpec spec) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (_) => ExportSheet(report: report, spec: spec),
    );
  }

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _export(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'ສົ່ງອອກບໍ່ສຳເລັດ · Export failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ສົ່ງອອກ ${widget.spec.title}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text('ເລືອກຮູບແບບໄຟລ໌', style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 18),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: C.accent)),
            )
          else ...[
            _ExportTile(
              icon: Icons.table_chart_outlined,
              title: 'CSV',
              subtitle: 'ສຳລັບ Excel/Google Sheets',
              onTap: () => _export(() => shareReportCsv(widget.report, widget.spec)),
            ),
            const SizedBox(height: 10),
            _ExportTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF',
              subtitle: 'ສະຫຼຸບເປັນເອກະສານ, ພ້ອມພິມ',
              onTap: () => _export(() => shareReportPdf(widget.report, widget.spec)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: C.dangerFg, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md)),
              child: Icon(icon, color: C.accentDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: C.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: C.faint),
          ],
        ),
      ),
    );
  }
}
