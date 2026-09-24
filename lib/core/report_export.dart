/// Turns a fetched [ReportResult] into a CSV or PDF file and hands it to the
/// OS share sheet — built entirely client-side (see the reports feature's
/// design notes): the backend already sends this data as JSON for the
/// in-app view, so these are two more renderings of it rather than a reason
/// to add export plumbing to the API.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../theme/report_specs.dart';
import 'dates.dart';

String _fileBaseName(ReportSpec spec, ReportResult report) =>
    'phaphak_${spec.type.path}_${report.from}_${report.to}';

/// Builds the CSV text for one report: a small summary block, then the
/// breakdown table — the two things worth pasting into a spreadsheet.
/// Prefixed with a UTF-8 BOM so Excel (which otherwise guesses ANSI) opens
/// Lao text correctly; a plain text editor ignores the BOM either way.
String buildReportCsv(ReportResult report, ReportSpec spec) {
  final rows = <List<String>>[
    ['${spec.title} · ${laoDateRange('${report.from}T00:00:00.000Z', '${report.to}T00:00:00.000Z')}'],
    [],
    ['ສະຫຼຸບ'],
    for (final f in spec.kpis) [f.label, formatValue(report.kpis[f.key], f.format)],
    [],
    [
      spec.breakdownLabelHeader,
      for (final c in spec.breakdownColumns) c.label,
    ],
    for (final row in report.breakdown)
      [
        (row['label'] ?? '—').toString(),
        for (final c in spec.breakdownColumns) formatValue(row[c.key], c.format),
      ],
  ];

  return '﻿${const ListToCsvConverter().convert(rows)}';
}

/// Hands the CSV to the OS share sheet (or, on web, a browser download).
///
/// Built from in-memory bytes via [XFile.fromData] rather than a temp file —
/// `dart:io`'s `File` and `path_provider` both compile on web but throw at
/// runtime there (no real filesystem in a browser); `XFile.fromData` is the
/// one construction path `cross_file` actually implements on every platform.
Future<void> shareReportCsv(ReportResult report, ReportSpec spec) async {
  final bytes = Uint8List.fromList(buildReportCsv(report, spec).codeUnits);
  await Share.shareXFiles([
    XFile.fromData(bytes, mimeType: 'text/csv', name: '${_fileBaseName(spec, report)}.csv'),
  ]);
}

const _laoFontFamily = 'NotoSansLaoPdfExport';
bool _laoFontLoaded = false;

/// Registers the app's bundled Lao font with `dart:ui`'s own text renderer,
/// once per session — see [_shapedText] for why this is needed at all.
Future<void> _ensureLaoFontLoaded() async {
  if (_laoFontLoaded) return;
  final data = await rootBundle.load('assets/fonts/NotoSansLao-Regular.ttf');
  await ui.loadFontFromList(data.buffer.asUint8List(), fontFamily: _laoFontFamily);
  _laoFontLoaded = true;
}

/// Rasterises [text] through Flutter's own (Skia) text layout instead of
/// handing a string to the `pdf` package directly.
///
/// The `pdf` package places one glyph per code point in logical order with
/// no OpenType shaping — fine for Latin, but Lao script needs a real shaping
/// engine: leading vowels are typed after their consonant but drawn before
/// it, and tone marks stack above/below rather than advancing the cursor.
/// Skia's paragraph layout (the same engine that renders the on-screen UI
/// correctly) already does this, so every piece of Lao text in the PDF goes
/// through here and is embedded as a small image instead of `pw.Text`.
Future<pw.Widget> _shapedText(
  String text, {
  double fontSize = 10,
  ui.Color color = const ui.Color(0xFF2B2521),
}) async {
  await _ensureLaoFontLoaded();

  // Rasterised at 2.5x and then scaled back down via the pw.Image's own
  // width/height, so the embedded bitmap stays sharp at PDF/print resolution
  // instead of looking soft at the font's literal pixel size.
  const scale = 2.5;
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(fontFamily: _laoFontFamily, fontSize: fontSize * scale),
  )
    ..pushStyle(ui.TextStyle(color: color))
    ..addText(text.isEmpty ? ' ' : text);
  final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 2400));

  final width = paragraph.longestLine.clamp(1, 2400).toDouble();
  final height = paragraph.height.clamp(1, 400).toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
  canvas.drawParagraph(paragraph, ui.Offset.zero);
  final image = await recorder.endRecording().toImage(width.ceil(), height.ceil());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);

  return pw.Image(
    pw.MemoryImage(png!.buffer.asUint8List()),
    width: width / scale,
    height: height / scale,
  );
}

Future<List<List<pw.Widget>>> _shapedRows(List<List<String>> rows, {double fontSize = 9.5}) {
  return Future.wait(
    rows.map((row) => Future.wait(row.map((cell) => _shapedText(cell, fontSize: fontSize)))),
  );
}

/// Builds the PDF bytes for one report: title, date range, KPI summary and
/// the breakdown table. The per-bucket series is left to the in-app chart
/// and the CSV export — a page of exact daily figures is more useful as a
/// spreadsheet than as PDF text, and every cell here is a rasterised image
/// (see [_shapedText]), so keeping this to the two small tables that matter
/// keeps export time and file size reasonable.
Future<Uint8List> buildReportPdf(ReportResult report, ReportSpec spec) async {
  final title = await _shapedText(spec.title, fontSize: 20);
  final subtitle = await _shapedText(
    laoDateRange('${report.from}T00:00:00.000Z', '${report.to}T00:00:00.000Z'),
    fontSize: 11,
    color: const ui.Color(0xFF8C8073),
  );

  final summaryHeading = await _shapedText('ສະຫຼຸບ', fontSize: 13);
  final summaryHeaders = await Future.wait([_shapedText('ຫົວຂໍ້'), _shapedText('ຄ່າ')]);
  final summaryRows = await _shapedRows([
    for (final f in spec.kpis) [f.label, formatValue(report.kpis[f.key], f.format)],
  ]);

  pw.Widget? breakdownHeading;
  List<pw.Widget>? breakdownHeaders;
  List<List<pw.Widget>>? breakdownRows;
  if (report.breakdown.isNotEmpty) {
    breakdownHeading = await _shapedText('ລາຍລະອຽດ', fontSize: 13);
    breakdownHeaders = await Future.wait([
      _shapedText(spec.breakdownLabelHeader),
      for (final c in spec.breakdownColumns) _shapedText(c.label),
    ]);
    breakdownRows = await _shapedRows([
      for (final row in report.breakdown)
        [
          (row['label'] ?? '—').toString(),
          for (final c in spec.breakdownColumns) formatValue(row[c.key], c.format),
        ],
    ]);
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        title,
        pw.SizedBox(height: 4),
        subtitle,
        pw.SizedBox(height: 16),
        summaryHeading,
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: summaryHeaders,
          data: summaryRows,
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.centerLeft,
        ),
        if (breakdownHeading != null) ...[
          pw.SizedBox(height: 18),
          breakdownHeading,
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: breakdownHeaders,
            data: breakdownRows!,
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ],
    ),
  );

  return doc.save();
}

Future<void> shareReportPdf(ReportResult report, ReportSpec spec) async {
  final bytes = await buildReportPdf(report, spec);
  await Printing.sharePdf(bytes: bytes, filename: '${_fileBaseName(spec, report)}.pdf');
}
