import 'package:flutter/material.dart';
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
/// Nights already sold are shown but cannot be selected: the backend refuses to
/// reprice or reopen a booked night, so letting them be picked would only earn
/// a "skippedBooked" the partner has to work out for themselves.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final Set<String> _selected = {};

  void _toggle(CalendarDay day) {
    if (day.isBooked) return;
    setState(() {
      _selected.contains(day.date) ? _selected.remove(day.date) : _selected.add(day.date);
    });
  }

  Future<void> _applyToSelection({required String roomId, required List<CalendarDay> days}) async {
    if (_selected.isEmpty) return;

    final priceField = TextEditingController();
    final chosen = days.where((d) => _selected.contains(d.date)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final anyClosed = chosen.any((d) => d.isClosed);

    final action = await showModalBottomSheet<({int? price, String? status})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_selected.length} ຄືນທີ່ເລືອກ',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${laoDate('${chosen.first.date}T00:00:00.000Z')} – ${laoDate('${chosen.last.date}T00:00:00.000Z')}',
              style: const TextStyle(fontSize: 13, color: C.muted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: priceField,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ລາຄາຕໍ່ຄືນ (ກີບ)',
                prefixText: '₭ ',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final price = int.tryParse(priceField.text.replaceAll(RegExp(r'[^0-9]'), ''));
                if (price == null || price < 1000) return;
                Navigator.of(ctx).pop((price: price, status: null));
              },
              child: const Text('ຕັ້ງລາຄາ'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(
                (price: null, status: anyClosed ? 'available' : 'closed'),
              ),
              icon: Icon(anyClosed ? Icons.lock_open : Icons.lock_outline, size: 18),
              label: Text(anyClosed ? 'ເປີດຂາຍຄືນ' : 'ປິດຂາຍ'),
            ),
          ],
        ),
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
              roomId: roomId,
              from: run.from,
              // `to` is exclusive, like a stay's check-out.
              to: addDays(run.to, 1),
              price: action.price,
              status: action.status,
            );
      }
      if (!mounted) return;
      setState(_selected.clear);
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
    final rooms = ref.watch(allRoomsProvider);
    final month = ref.watch(calendarMonthProvider);
    final selectedRoom = ref.watch(selectedRoomProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ປະຕິທິນ & ລາຄາ')),
      body: rooms.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(propertiesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              message: 'ຍັງບໍ່ມີຫ້ອງ\nເພີ່ມຫ້ອງກ່ອນຈຶ່ງຕັ້ງລາຄາໄດ້',
              icon: Icons.meeting_room_outlined,
            );
          }

          final roomId = selectedRoom ?? list.first.room.id;
          final calendar = ref.watch(roomCalendarProvider((roomId: roomId, month: month)));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<String>(
                  value: roomId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ຫ້ອງ'),
                  items: [
                    for (final e in list)
                      DropdownMenuItem(
                        value: e.room.id,
                        child: Text(
                          '${e.property.name} · ${e.room.label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(_selected.clear);
                    ref.read(selectedRoomProvider.notifier).set(v);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(_selected.clear);
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
                        setState(_selected.clear);
                        ref.read(calendarMonthProvider.notifier).shift(1);
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
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
                    onToggle: _toggle,
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
                          onPressed: () => setState(_selected.clear),
                          child: const Text('ລ້າງ'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _applyToSelection(
                              roomId: roomId,
                              days: calendar.value?.days ?? const [],
                            ),
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.calendar,
    required this.selected,
    required this.onToggle,
  });

  final DateTime month;
  final RoomCalendar calendar;
  final Set<String> selected;
  final void Function(CalendarDay) onToggle;

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

            return _DayCell(
              dayNumber: dayNumber,
              day: day,
              selected: isSelected,
              isToday: isToday,
              onTap: day == null ? null : () => onToggle(day),
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
    this.onTap,
  });

  final int dayNumber;
  final CalendarDay? day;
  final bool selected;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final booked = day?.isBooked ?? false;
    final closed = day?.isClosed ?? false;

    final background = selected
        ? C.accent
        : booked
            ? C.accentSoft
            : closed
                ? C.neutralBg
                : C.surface;

    final foreground = selected
        ? Colors.white
        : booked
            ? C.accentDark
            : closed
                ? C.neutralFg
                : C.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.sm),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(
            color: isToday && !selected ? C.accent : C.border,
            width: isToday && !selected ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const SizedBox(height: 2),
            if (day != null)
              Text(
                booked ? 'ຈອງ' : kipShort(day!.price).replaceFirst('₭', ''),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 9.5, color: foreground.withValues(alpha: 0.85)),
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
        swatch(C.surface, 'ວ່າງ'),
        swatch(C.accentSoft, 'ຖືກຈອງ (ແກ້ບໍ່ໄດ້)'),
        swatch(C.neutralBg, 'ປິດຂາຍ'),
        swatch(C.accent, 'ເລືອກຢູ່'),
      ],
    );
  }
}
