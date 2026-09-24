import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partner_app/core/report_export.dart';
import 'package:partner_app/models/models.dart';
import 'package:partner_app/theme/report_specs.dart';

/// `buildReportCsv` is covered fully, including a round-trip through the
/// same `csv` decoder Excel-compatible tooling would use. `buildReportPdf`
/// rasterises every string through `dart:ui` first (see report_export.dart's
/// `_shapedText` doc comment for why) — this only smoke-tests that the whole
/// font-load/rasterise/embed pipeline runs without throwing and produces a
/// non-empty PDF; whether the Lao glyphs actually render correctly still
/// needs a human to open the file, same as any other font-rendering bug.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final report = ReportResult({
    'range': {'from': '2026-09-01', 'to': '2026-09-08', 'bucket': 'day'},
    'kpis': {'gross': 1350000, 'commission': 67500, 'net': 1282500, 'bookings': 3},
    'series': [
      {'bucket': '2026-09-01', 'gross': 0, 'net': 0},
      {'bucket': '2026-09-02', 'gross': 1350000, 'net': 1282500},
    ],
    'breakdown': [
      {'label': 'ຫ້ອງມາດຕະຖານ · Standard Room', 'gross': 1350000},
    ],
  });
  final spec = reportSpecs[ReportType.revenue]!;

  test('carries the summary and breakdown rows, Lao text intact', () {
    final csv = buildReportCsv(report, spec);

    expect(csv, startsWith('﻿'));
    expect(csv, contains('ຍອດຂາຍລວມ'));
    expect(csv, contains('ຫ້ອງມາດຕະຖານ'));
    expect(csv, contains('₭1,350,000'));
  });

  test('round-trips through the csv package\'s own decoder without data loss', () {
    final csv = buildReportCsv(report, spec).replaceFirst('﻿', '');
    final rows = const CsvToListConverter().convert(csv);

    // Title row, blank, "ສະຫຼຸບ", 4 kpi rows, blank, breakdown header, 1 data row.
    expect(rows.length, 10);
    expect(rows.last, ['ຫ້ອງມາດຕະຖານ · Standard Room', '₭1,350,000']);
  });

  test('buildReportPdf runs the font-load/rasterise/embed pipeline without throwing', () async {
    final bytes = await buildReportPdf(report, spec);

    expect(bytes, isNotEmpty);
    // Every PDF file starts with this magic header, regardless of content.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
