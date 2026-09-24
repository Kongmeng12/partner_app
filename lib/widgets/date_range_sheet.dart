import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../theme/tokens.dart';
import 'common.dart';

typedef DateRange = ({DateTime from, DateTime to});

/// A bottom sheet for picking a report's date range: presets for the common
/// cases, a custom two-tap picker for everything else. The returned `to` is
/// always exclusive (the day after the last day the report should cover),
/// matching every date-range endpoint on the backend.
class DateRangeSheet extends StatefulWidget {
  const DateRangeSheet({super.key, required this.initialFrom, required this.initialTo});

  final DateTime initialFrom;
  final DateTime initialTo;

  static Future<DateRange?> show(BuildContext context, DateRange current) {
    return showModalBottomSheet<DateRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (_) => DateRangeSheet(initialFrom: current.from, initialTo: current.to),
    );
  }

  @override
  State<DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<DateRangeSheet> {
  static const _maxDays = 366;

  late DateTime _from = widget.initialFrom;
  late DateTime _to = widget.initialTo; // exclusive

  void _apply(DateTime from, DateTime toExclusive) {
    setState(() {
      _from = from;
      _to = toExclusive;
    });
  }

  void _preset(int days) {
    final today = todayUtc();
    _apply(addDays(today, -(days - 1)), addDays(today, 1));
  }

  void _thisMonth() {
    final today = todayUtc();
    _apply(DateTime.utc(today.year, today.month, 1), addDays(today, 1));
  }

  void _lastMonth() {
    final today = todayUtc();
    final firstOfThis = DateTime.utc(today.year, today.month, 1);
    final firstOfLast = DateTime.utc(today.year, today.month - 1, 1);
    _apply(firstOfLast, firstOfThis);
  }

  Future<void> _pickCustom() async {
    final today = todayUtc();
    final from = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime.utc(2020),
      lastDate: today,
      helpText: 'ວັນທີ່ເລີ່ມຕົ້ນ',
    );
    if (from == null || !mounted) return;

    final lastSelectable = _earlier(addDays(from, _maxDays - 1), today);
    var toInitial = _to.isAfter(from) ? addDays(_to, -1) : from;
    if (toInitial.isAfter(lastSelectable)) toInitial = lastSelectable;
    if (toInitial.isBefore(from)) toInitial = from;

    final to = await showDatePicker(
      context: context,
      initialDate: toInitial,
      firstDate: from,
      lastDate: lastSelectable,
      helpText: 'ວັນທີ່ສິ້ນສຸດ',
    );
    if (to == null || !mounted) return;

    _apply(
      DateTime.utc(from.year, from.month, from.day),
      addDays(DateTime.utc(to.year, to.month, to.day), 1),
    );
  }

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  int get _nights => _to.difference(_from).inDays;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ຊ່ວງວັນທີ່', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${laoDate(_from.toIso8601String())} – ${laoDate(addDays(_to, -1).toIso8601String())} · $_nights ວັນ',
            style: const TextStyle(fontSize: 13, color: C.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              QuickChip(label: 'ມື້ນີ້', onTap: () => _preset(1)),
              QuickChip(label: '7 ວັນ', onTap: () => _preset(7)),
              QuickChip(label: '30 ວັນ', onTap: () => _preset(30)),
              QuickChip(label: 'ເດືອນນີ້', onTap: _thisMonth),
              QuickChip(label: 'ເດືອນແລ້ວ', onTap: _lastMonth),
              QuickChip(label: 'ກຳນົດເອງ', onTap: _pickCustom),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((from: _from, to: _to)),
            child: const Text('ນຳໃຊ້'),
          ),
        ],
      ),
    );
  }
}
