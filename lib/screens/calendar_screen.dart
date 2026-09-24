import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/dates.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/property_picker.dart';

/// The Calendar: one month, each day showing how full the property is. Tap a
/// day to see every room that day (`day_detail_screen.dart`).
///
/// A day cell says three things without opening it — `8/11` rooms taken with a
/// fill bar, a green dot when guests arrive, an orange dot when guests leave —
/// so the host can spot the busy and the quiet days at a glance.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ປະຕິທິນ'),
        actions: [
          IconButton(
            tooltip: 'ລາຄາ & ເປີດ-ປິດຂາຍ',
            onPressed: () => context.go('/calendar/pricing'),
            icon: const Icon(Icons.sell_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: properties.when(
        loading: () => const LoadingBlock(),
        error:
            (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(propertiesProvider),
            ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              message: 'ຍັງບໍ່ມີທີ່ພັກ\nເພີ່ມທີ່ພັກກ່ອນຈຶ່ງເບິ່ງປະຕິທິນໄດ້',
              icon: Icons.home_outlined,
            );
          }

          final selected = ref.watch(selectedPropertyProvider);
          final property =
              list.where((p) => p.id == selected).firstOrNull ?? list.first;
          final month = ref.watch(occupancyMonthProvider);
          final summary = ref.watch(
            monthSummaryProvider((propertyId: property.id, month: month)),
          );

          return Column(
            children: [
              _Header(properties: list, property: property, month: month),
              const _WeekdayRow(),
              Expanded(
                child: summary.when(
                  loading: () => const LoadingBlock(),
                  error:
                      (e, _) => ErrorRetry(
                        error: e,
                        onRetry: () => ref.invalidate(monthSummaryProvider),
                      ),
                  data:
                      (days) => RefreshIndicator(
                        color: C.accent,
                        onRefresh:
                            () async => ref.invalidate(monthSummaryProvider),
                        child: _MonthGrid(month: month, days: days),
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.properties,
    required this.property,
    required this.month,
  });

  final List<Property> properties;
  final Property property;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todayUtc();
    final onCurrentMonth =
        month.year == today.year && month.month == today.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        children: [
          if (properties.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: QuickChip(
                  label: '${property.name}  ▾',
                  onTap:
                      () => pickCalendarProperty(
                        context,
                        ref,
                        properties,
                        property.id,
                      ),
                ),
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed:
                    () => ref.read(occupancyMonthProvider.notifier).shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    laoMonthYear(month),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (!onCurrentMonth)
                QuickChip(
                  label: 'ມື້ນີ້',
                  onTap:
                      () =>
                          ref.read(occupancyMonthProvider.notifier).set(today),
                ),
              IconButton(
                onPressed:
                    () => ref.read(occupancyMonthProvider.notifier).shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          for (final label in laoWeekdaysShort)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: C.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.days});

  final DateTime month;
  final List<CalendarMonthDay> days;

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in days) d.date: d};
    // Monday-first: DateTime.weekday is 1=Mon…7=Sun.
    final leading = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
    final today = todayUtc();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.66,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (_, index) {
            if (index < leading) return const SizedBox.shrink();
            final number = index - leading + 1;
            final date = DateTime.utc(month.year, month.month, number);
            return _DayCell(
              number: number,
              info: byDate[apiDay(date)],
              isToday: date == today,
              isPast: date.isBefore(today),
              onTap: () => context.go('/calendar/day/${apiDay(date)}'),
            );
          },
        ),
        const SizedBox(height: 16),
        const _Legend(),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.number,
    required this.info,
    required this.isToday,
    required this.isPast,
    required this.onTap,
  });

  final int number;
  final CalendarMonthDay? info;
  final bool isToday;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = info;
    final hasInventory = day?.hasInventory ?? false;
    final full = day?.isFull ?? false;
    // Past days stay tappable (a host looks back at who stayed) but recede.
    final ink = isPast ? C.muted : C.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.sm),
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 5, 3, 5),
        decoration: BoxDecoration(
          color: full ? C.accentSoft : C.surface,
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(
            color: isToday ? C.accent : C.border,
            width: isToday ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$number',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 3),
            if (hasInventory) ...[
              Text(
                '${day!.taken}/${day.total}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: full ? C.accentDark : ink,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: day.fill,
                  minHeight: 4,
                  backgroundColor: C.divider,
                  color: full ? C.accentDark : C.accent,
                ),
              ),
            ] else
              const Text('—', style: TextStyle(fontSize: 12, color: C.faint)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((day?.arrivals ?? 0) > 0) const _Dot(color: C.successFg),
                if ((day?.arrivals ?? 0) > 0 && (day?.departures ?? 0) > 0)
                  const SizedBox(width: 4),
                if ((day?.departures ?? 0) > 0)
                  const _Dot(color: Color(0xFFE08A1E)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
      ],
    );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(
          Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
              color: C.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          'ຫ້ອງຖືກຈອງ / ທັງໝົດ',
        ),
        item(const _Dot(color: C.successFg), 'ມີແຂກເຂົ້າ'),
        item(const _Dot(color: Color(0xFFE08A1E)), 'ມີແຂກອອກ'),
        item(
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: C.accentSoft,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: C.border),
            ),
          ),
          'ເຕັມ',
        ),
      ],
    );
  }
}
