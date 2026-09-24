/// Configuration for the `/more/reports` feature — one entry per report type,
/// driving both the hub grid and the shared detail screen so a new report
/// later is a config entry here, not a new screen.
library;

import 'package:flutter/material.dart';

import '../core/money.dart';
import 'tokens.dart';

enum ReportType { revenue, payouts, bookings, occupancy, cancellations, reviews, promotions }

extension ReportTypePath on ReportType {
  /// The `/partner/reports/<path>` segment this type calls.
  String get path => switch (this) {
        ReportType.revenue => 'revenue',
        ReportType.payouts => 'payouts',
        ReportType.bookings => 'bookings',
        ReportType.occupancy => 'occupancy',
        ReportType.cancellations => 'cancellations',
        ReportType.reviews => 'reviews',
        ReportType.promotions => 'promotions',
      };

  static ReportType? fromPath(String value) {
    for (final t in ReportType.values) {
      if (t.path == value) return t;
    }
    return null;
  }
}

enum ValueFormat { money, moneyShort, int, percent, rating, text }

/// Renders one `kpis`/`breakdown` value the way its format says to. `null`
/// values are what a report with zero rows in range hands back — shown as
/// "—" rather than a bare 0, which would read as a real (bad) number.
String formatValue(Object? value, ValueFormat format) {
  if (value == null) return '—';
  final n = value is num ? value : num.tryParse(value.toString());

  switch (format) {
    case ValueFormat.money:
      return kip(n);
    case ValueFormat.moneyShort:
      return kipShort(n);
    case ValueFormat.int:
      return n == null ? '$value' : n.round().toString();
    case ValueFormat.percent:
      return n == null ? '$value' : '${n.round()}%';
    case ValueFormat.rating:
      return n == null ? '$value★' : '${n.toStringAsFixed(1)}★';
    case ValueFormat.text:
      return value.toString();
  }
}

/// One field pulled out of a `kpis` map or a `breakdown` row by [key].
class ReportField {
  const ReportField(this.key, this.label, this.format);
  final String key;
  final String label;
  final ValueFormat format;
}

/// One line drawn on a report's trend chart.
class ChartLine {
  const ChartLine(this.key, this.label, this.color, this.format);
  final String key;
  final String label;
  final Color color;
  final ValueFormat format;
}

class ReportSpec {
  const ReportSpec({
    required this.type,
    required this.title,
    required this.icon,
    required this.kpis,
    required this.headline,
    required this.chartLines,
    required this.breakdownColumns,
    this.breakdownLabelHeader = 'ລາຍການ',
    this.bucketable = true,
    this.emptyMessage = 'ຍັງບໍ່ມີຂໍ້ມູນໃນຊ່ວງວັນທີ່ນີ້',
  });

  final ReportType type;
  final String title;
  final IconData icon;

  /// Shown as [StatTile]s at the top of the detail screen.
  final List<ReportField> kpis;

  /// The one number shown on the hub tile for this report.
  final ReportField headline;

  /// Lines on the trend chart — usually one, sometimes two related amounts.
  final List<ChartLine> chartLines;

  /// Extra columns rendered next to each breakdown row's own `label`.
  final List<ReportField> breakdownColumns;
  final String breakdownLabelHeader;

  /// False hides the day/week/month segmented control — a report whose
  /// `series` is a running average (reviews) or naturally sparse (payouts)
  /// still shows a chart, just always bucketed by day.
  final bool bucketable;
  final String emptyMessage;
}

final Map<ReportType, ReportSpec> reportSpecs = {
  ReportType.revenue: const ReportSpec(
    type: ReportType.revenue,
    title: 'ລາຍຮັບ',
    icon: Icons.payments_outlined,
    kpis: [
      ReportField('gross', 'ຍອດຂາຍລວມ', ValueFormat.money),
      ReportField('commission', 'ຄ່າຄອມມິຊຊັນ', ValueFormat.money),
      ReportField('net', 'ທ່ານໄດ້ຮັບ', ValueFormat.money),
      ReportField('bookings', 'ຈຳນວນການຈອງ', ValueFormat.int),
    ],
    headline: ReportField('gross', 'ຍອດຂາຍລວມ', ValueFormat.moneyShort),
    chartLines: [
      ChartLine('gross', 'ຍອດຂາຍ', C.accent, ValueFormat.money),
      ChartLine('net', 'ໄດ້ຮັບ', C.dark, ValueFormat.money),
    ],
    breakdownColumns: [ReportField('gross', 'ຍອດຂາຍ', ValueFormat.money)],
    breakdownLabelHeader: 'ຫ້ອງ/ທີ່ພັກ',
  ),
  ReportType.payouts: const ReportSpec(
    type: ReportType.payouts,
    title: 'ການໂອນເງິນ',
    icon: Icons.account_balance_wallet_outlined,
    kpis: [
      ReportField('gross', 'ຍອດລວມ', ValueFormat.money),
      ReportField('commission', 'ຄ່າຄອມມິຊຊັນ', ValueFormat.money),
      ReportField('net', 'ໂອນສຸດທິ', ValueFormat.money),
      ReportField('count', 'ຈຳນວນງວດ', ValueFormat.int),
    ],
    headline: ReportField('net', 'ໂອນສຸດທິ', ValueFormat.moneyShort),
    chartLines: [
      ChartLine('gross', 'ຍອດລວມ', C.accent, ValueFormat.money),
      ChartLine('net', 'ໂອນສຸດທິ', C.dark, ValueFormat.money),
    ],
    breakdownColumns: [
      ReportField('count', 'ຈຳນວນ', ValueFormat.int),
      ReportField('net', 'ໂອນສຸດທິ', ValueFormat.money),
    ],
    breakdownLabelHeader: 'ສະຖານະ',
    bucketable: false,
  ),
  ReportType.bookings: const ReportSpec(
    type: ReportType.bookings,
    title: 'ການຈອງ',
    icon: Icons.event_note_outlined,
    kpis: [
      ReportField('total', 'ທັງໝົດ', ValueFormat.int),
      ReportField('app', 'ຜ່ານແອັບ', ValueFormat.int),
      ReportField('walkIn', 'Walk-in', ValueFormat.int),
    ],
    headline: ReportField('total', 'ການຈອງທັງໝົດ', ValueFormat.int),
    chartLines: [ChartLine('total', 'ການຈອງ', C.accent, ValueFormat.int)],
    breakdownColumns: [ReportField('count', 'ຈຳນວນ', ValueFormat.int)],
    breakdownLabelHeader: 'ປະເພດຫ້ອງ',
  ),
  ReportType.occupancy: const ReportSpec(
    type: ReportType.occupancy,
    title: 'ອັດຕາເຂົ້າພັກ',
    icon: Icons.hotel_outlined,
    kpis: [
      ReportField('occupancyPercent', 'ອັດຕາເຂົ້າພັກ', ValueFormat.percent),
      ReportField('soldRoomNights', 'ຄືນທີ່ຂາຍໄດ້', ValueFormat.int),
      ReportField('availableRoomNights', 'ຄືນທັງໝົດ', ValueFormat.int),
    ],
    headline: ReportField('occupancyPercent', 'ອັດຕາເຂົ້າພັກ', ValueFormat.percent),
    chartLines: [ChartLine('percent', 'ອັດຕາເຂົ້າພັກ', C.accent, ValueFormat.percent)],
    breakdownColumns: [
      ReportField('sold', 'ຂາຍໄດ້', ValueFormat.int),
      ReportField('available', 'ທັງໝົດ', ValueFormat.int),
      ReportField('percent', 'ອັດຕາ', ValueFormat.percent),
    ],
    breakdownLabelHeader: 'ປະເພດຫ້ອງ/ທີ່ພັກ',
  ),
  ReportType.cancellations: const ReportSpec(
    type: ReportType.cancellations,
    title: 'ການຍົກເລີກ & ຄືນເງິນ',
    icon: Icons.cancel_outlined,
    kpis: [
      ReportField('count', 'ຈຳນວນຍົກເລີກ', ValueFormat.int),
      ReportField('penalty', 'ຄ່າປັບທີ່ເກັບໄດ້', ValueFormat.money),
      ReportField('refunded', 'ຄືນເງິນໃຫ້ແຂກ', ValueFormat.money),
    ],
    headline: ReportField('count', 'ຍົກເລີກ', ValueFormat.int),
    chartLines: [ChartLine('count', 'ຍົກເລີກ', C.dangerFg, ValueFormat.int)],
    breakdownColumns: [
      ReportField('count', 'ຈຳນວນ', ValueFormat.int),
      ReportField('amount', 'ຈຳນວນເງິນ', ValueFormat.money),
    ],
    breakdownLabelHeader: 'ສະຖານະຄືນເງິນ',
  ),
  ReportType.reviews: const ReportSpec(
    type: ReportType.reviews,
    title: 'ຮີວິວ',
    icon: Icons.star_outline,
    kpis: [
      ReportField('count', 'ຈຳນວນຮີວິວ', ValueFormat.int),
      ReportField('averageOverall', 'ຄະແນນສະເລ່ຍ', ValueFormat.rating),
    ],
    headline: ReportField('averageOverall', 'ຄະແນນສະເລ່ຍ', ValueFormat.rating),
    chartLines: [ChartLine('average', 'ຄະແນນສະເລ່ຍ', C.accent, ValueFormat.rating)],
    breakdownColumns: [ReportField('count', 'ຈຳນວນ', ValueFormat.int)],
    breakdownLabelHeader: 'ດາວ',
  ),
  ReportType.promotions: const ReportSpec(
    type: ReportType.promotions,
    title: 'ໂປຣໂມຊັນ & ສ່ວນຫຼຸດ',
    icon: Icons.local_offer_outlined,
    kpis: [
      ReportField('discountGiven', 'ສ່ວນຫຼຸດທີ່ໃຫ້', ValueFormat.money),
      ReportField('couponUses', 'ຈຳນວນຄັ້ງທີ່ໃຊ້', ValueFormat.int),
    ],
    headline: ReportField('discountGiven', 'ສ່ວນຫຼຸດ', ValueFormat.moneyShort),
    chartLines: [ChartLine('discount', 'ສ່ວນຫຼຸດ', C.accent, ValueFormat.money)],
    breakdownColumns: [
      ReportField('uses', 'ຈຳນວນຄັ້ງ', ValueFormat.int),
      ReportField('discount', 'ສ່ວນຫຼຸດ', ValueFormat.money),
    ],
    breakdownLabelHeader: 'ຄູປອງ',
  ),
};
