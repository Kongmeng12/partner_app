import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The pricing calendar.
///
/// Each cell shows the nightly rate and how many of the room type are still
/// free — `3/8`. Inventory is a count in v2, not a free/sold flag, so every
/// night can be repriced or closed regardless of what has already sold.
///
/// Three ways to build a selection, because a partner reaching for this
/// screen is usually either fixing one night, repricing a whole month for a
/// season change, or blocking out a holiday week — and tapping every day
/// individually only serves the first of those:
///   - tap a day — toggles it alone, for scattered individual nights
///   - long-press a day, then tap another — selects everything between them
///   - "ທັງເດືອນ" / "ເສົາ-ອາທິດ" chips — the two bulk patterns partners ask
///     for constantly (a full season reprice, a weekend-rate bump)
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final Set<String> _selected = {};

  /// Set while a long-press has anchored a range and is waiting for the
  /// second tap that closes it. Null the rest of the time, which is when a
  /// plain tap goes back to toggling one day at a time.
  String? _rangeAnchor;

  void _toggle(CalendarDay day) {
    if (_rangeAnchor != null) {
      setState(() {
        _selected
          ..clear()
          ..addAll(_isosBetween(_rangeAnchor!, day.date));
      });
      return;
    }
    setState(() {
      _selected.contains(day.date) ? _selected.remove(day.date) : _selected.add(day.date);
    });
  }

  void _startRange(CalendarDay day) {
    HapticFeedback.mediumImpact();
    setState(() {
      _rangeAnchor = day.date;
      _selected
        ..clear()
        ..add(day.date);
    });
  }

  void _cancelRange() {
    setState(() {
      _rangeAnchor = null;
      _selected.clear();
    });
  }

  void _selectAll(List<CalendarDay> days) {
    setState(() {
      _rangeAnchor = null;
      _selected
        ..clear()
        ..addAll(days.map((d) => d.date));
    });
  }

  void _selectWeekends(List<CalendarDay> days) {
    setState(() {
      _rangeAnchor = null;
      _selected
        ..clear()
        ..addAll(
          days
              .where((d) {
                final weekday = DateTime.parse('${d.date}T00:00:00.000Z').weekday;
                return weekday == DateTime.saturday || weekday == DateTime.sunday;
              })
              .map((d) => d.date),
        );
    });
  }

  Future<void> _applyToSelection({
    required String roomTypeId,
    required List<CalendarDay> days,
  }) async {
    if (_selected.isEmpty) return;

    final chosen = days.where((d) => _selected.contains(d.date)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (chosen.isEmpty) return;

    final action = await showModalBottomSheet<({int? price, String? status})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (ctx) => _ApplySheet(
        nights: chosen.length,
        fromLabel: laoDate('${chosen.first.date}T00:00:00.000Z'),
        toLabel: laoDate('${chosen.last.date}T00:00:00.000Z'),
        currentlyClosed: chosen.every((d) => d.isClosed),
      ),
    );

    if (action == null) return;

    // The selection can be scattered across the month, and the API takes a
    // contiguous range — so it is sent as consecutive runs.
    final runs = _contiguousRuns(chosen.map((d) => d.date).toList());
    try {
      var updated = 0;
      for (final run in runs) {
        updated += await ref.read(actionsProvider).setAvailability(
              roomTypeId: roomTypeId,
              from: run.from,
              // `to` is exclusive, like a stay's check-out.
              to: addDays(run.to, 1),
              price: action.price,
              status: action.status,
            );
      }
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _rangeAnchor = null;
      });
      showMessage(context, 'ອັບເດດ $updated ຄືນແລ້ວ');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  /// Groups sorted `YYYY-MM-DD` strings into runs of consecutive days.
  List<({DateTime from, DateTime to})> _contiguousRuns(List<String> dates) {
    final runs = <({DateTime from, DateTime to})>[];
    DateTime? start;
    DateTime? previous;

    for (final iso in dates) {
      final day = DateTime.parse('${iso}T00:00:00.000Z');
      if (start == null) {
        start = day;
      } else if (day.difference(previous!).inDays != 1) {
        runs.add((from: start, to: previous));
        start = day;
      }
      previous = day;
    }
    if (start != null && previous != null) runs.add((from: start, to: previous));
    return runs;
  }

  @override
  Widget build(BuildContext context) {
    final roomTypes = ref.watch(allRoomTypesProvider);
    final month = ref.watch(calendarMonthProvider);
    final selected = ref.watch(selectedRoomTypeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ປະຕິທິນ & ລາຄາ')),
      body: roomTypes.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(propertiesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              message: 'ຍັງບໍ່ມີຫ້ອງ\nເພີ່ມຫ້ອງກ່ອນຈຶ່ງຕັ້ງລາຄາໄດ້',
              icon: Icons.meeting_room_outlined,
            );
          }

          final roomTypeId = selected ?? list.first.roomType.id;
          final calendar = ref.watch(roomCalendarProvider((roomTypeId: roomTypeId, month: month)));
          final days = calendar.value?.days ?? const <CalendarDay>[];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<String>(
                  initialValue: roomTypeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ປະເພດຫ້ອງ'),
                  items: [
                    for (final e in list)
                      DropdownMenuItem(
                        value: e.roomType.id,
                        child: Text(
                          '${e.property.name} · ${e.roomType.label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selected.clear();
                      _rangeAnchor = null;
                    });
                    ref.read(selectedRoomTypeProvider.notifier).set(v);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selected.clear();
                          _rangeAnchor = null;
                        });
                        ref.read(calendarMonthProvider.notifier).shift(-1);
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selected.clear();
                          _rangeAnchor = null;
                        });
                        ref.read(calendarMonthProvider.notifier).shift(1);
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              if (days.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _QuickChip(label: 'ທັງເດືອນ', onTap: () => _selectAll(days)),
                              const SizedBox(width: 8),
                              _QuickChip(label: 'ເສົາ-ອາທິດ', onTap: () => _selectWeekends(days)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_rangeAnchor != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: C.accentSoft,
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, size: 16, color: C.accentDark),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'ກຳລັງເລືອກຊ່ວງ · ແຕະວັນສິ້ນສຸດ',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.accentDark),
                          ),
                        ),
                        InkWell(
                          onTap: _cancelRange,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              'ຍົກເລີກ',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.accentDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: calendar.when(
                  loading: () => const LoadingBlock(),
                  error: (e, _) => ErrorRetry(
                    error: e,
                    onRetry: () => ref.invalidate(roomCalendarProvider),
                  ),
                  data: (cal) => _MonthGrid(
                    month: month,
                    calendar: cal,
                    selected: _selected,
                    rangeAnchor: _rangeAnchor,
                    onTap: _toggle,
                    onLongPress: _startRange,
                  ),
                ),
              ),
              if (_selected.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _selected.clear();
                            _rangeAnchor = null;
                          }),
                          child: const Text('ລ້າງ'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _applyToSelection(roomTypeId: roomTypeId, days: days),
                            child: Text('ແກ້ໄຂ ${_selected.length} ຄືນ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static const _laoMonths = [
    'ມັງກອນ', 'ກຸມພາ', 'ມີນາ', 'ເມສາ', 'ພຶດສະພາ', 'ມິຖຸນາ',
    'ກໍລະກົດ', 'ສິງຫາ', 'ກັນຍາ', 'ຕຸລາ', 'ພະຈິກ', 'ທັນວາ',
  ];

  String _monthLabel(DateTime month) => '${_laoMonths[month.month - 1]} ${month.year}';
}

/// Every calendar day between two ISO dates, inclusive, in either order —
/// the long-press-then-tap range selection's whole job.
List<String> _isosBetween(String a, String b) {
  final start = DateTime.parse('${a}T00:00:00.000Z');
  final end = DateTime.parse('${b}T00:00:00.000Z');
  final from = start.isBefore(end) ? start : end;
  final to = start.isBefore(end) ? end : start;

  final isos = <String>[];
  for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
    isos.add(apiDay(d));
  }
  return isos;
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.border),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.soft)),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.calendar,
    required this.selected,
    required this.rangeAnchor,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime month;
  final RoomCalendar calendar;
  final Set<String> selected;
  final String? rangeAnchor;
  final void Function(CalendarDay) onTap;
  final void Function(CalendarDay) onLongPress;

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in calendar.days) d.date: d};

    // Monday-first: DateTime.weekday is 1=Mon…7=Sun, so the offset is
    // weekday-1 blank cells before the 1st.
    final leading = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
    final today = todayUtc();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      children: [
        Row(
          children: [
            for (final label in laoWeekdaysShort)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: C.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.72,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (_, index) {
            if (index < leading) return const SizedBox.shrink();

            final dayNumber = index - leading + 1;
            final date = DateTime.utc(month.year, month.month, dayNumber);
            final iso = apiDay(date);
            final day = byDate[iso];
            final isSelected = selected.contains(iso);
            final isToday = date == today;
            final isAnchor = rangeAnchor == iso;

            return _DayCell(
              dayNumber: dayNumber,
              day: day,
              selected: isSelected,
              isToday: isToday,
              isRangeAnchor: isAnchor,
              onTap: day == null ? null : () => onTap(day),
              onLongPress: day == null ? null : () => onLongPress(day),
            );
          },
        ),
        const SizedBox(height: 14),
        const _Legend(),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.isRangeAnchor,
    this.onTap,
    this.onLongPress,
  });

  final int dayNumber;
  final CalendarDay? day;
  final bool selected;
  final bool isToday;
  final bool isRangeAnchor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final closed = day?.isClosed ?? false;
    final full = day?.isFull ?? false;

    final background = selected
        ? C.accent
        : full
            ? C.accentSoft
            : closed
                ? C.neutralBg
                : C.surface;

    final foreground = selected
        ? Colors.white
        : full
            ? C.accentDark
            : closed
                ? C.neutralFg
                : C.text;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(R.sm),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(
            color: isRangeAnchor
                ? C.accentDark
                : isToday && !selected
                    ? C.accent
                    : C.border,
            width: isRangeAnchor || (isToday && !selected) ? 1.8 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: foreground.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 3),
                if (day != null)
                  Text(
                    closed ? 'ປິດຂາຍ' : kipShort(day!.price).replaceFirst('₭', ''),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: foreground),
                  ),
                // How many of this room type are left. The number is the whole
                // point of a room type: "3/8" is sellable, "0/8" is not.
                if (day != null && !closed) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.25) : C.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${day!.available}/${day!.total}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: foreground.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.check_circle, size: 12, color: Colors.white.withValues(alpha: 0.9)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: C.border),
              ),
            ),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
          ],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        swatch(C.surface, 'ຍັງມີວ່າງ'),
        swatch(C.accentSoft, 'ເຕັມ'),
        swatch(C.neutralBg, 'ປິດຂາຍ'),
        swatch(C.accent, 'ເລືອກຢູ່'),
      ],
    );
  }
}

/// The sheet a selection is turned into an actual change through — price and
/// open/closed status together in one save, rather than two separate actions
/// for what is usually one intent ("open this range at the holiday rate").
class _ApplySheet extends StatefulWidget {
  const _ApplySheet({
    required this.nights,
    required this.fromLabel,
    required this.toLabel,
    required this.currentlyClosed,
  });

  final int nights;
  final String fromLabel;
  final String toLabel;

  /// Pre-selects the status control to match the selection's current state
  /// only when every chosen night agrees — a mixed selection starts on "don't
  /// change" rather than guessing which way the partner means to flip it.
  final bool currentlyClosed;

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _priceField = TextEditingController();
  String? _status; // null = leave status unchanged

  bool get _canSave => _priceField.text.trim().isNotEmpty || _status != null;

  @override
  void dispose() {
    _priceField.dispose();
    super.dispose();
  }

  void _save() {
    final priceText = _priceField.text.replaceAll(RegExp(r'[^0-9]'), '');
    final price = priceText.isEmpty ? null : int.tryParse(priceText);
    if (priceText.isNotEmpty && (price == null || price < 1000)) return;
    if (!_canSave) return;
    Navigator.of(context).pop((price: price, status: _status));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.nights} ຄືນທີ່ເລືອກ', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${widget.fromLabel} – ${widget.toLabel}',
            style: const TextStyle(fontSize: 13, color: C.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _priceField,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'ລາຄາຕໍ່ຄືນ',
              prefixText: '₭ ',
              helperText: 'ປະໄວ້ຫວ່າງຖ້າບໍ່ປ່ຽນລາຄາ',
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ສະຖານະຂາຍ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.soft)),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String?>(
            segments: const [
              ButtonSegment(value: null, label: Text('ບໍ່ປ່ຽນ')),
              ButtonSegment(value: 'open', label: Text('ເປີດຂາຍ')),
              ButtonSegment(value: 'closed', label: Text('ປິດຂາຍ')),
            ],
            selected: {_status},
            onSelectionChanged: (v) => setState(() => _status = v.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: C.accentSoft,
              selectedForegroundColor: C.accentDark,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
  }
}
