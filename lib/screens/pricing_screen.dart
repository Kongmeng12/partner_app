import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Room prices, in the two steps a partner actually thinks in:
///
///   1. the everyday rate of each room type — one card each, edited in place
///      ([PricingScreen]);
///   2. the nights that differ from it — holidays, weekends, a closed week —
///      on that room type's own calendar ([RoomPricingScreen]).
///
/// A night either follows the base rate or has a special price of its own;
/// putting a night back to the base rate removes the special price, so a later
/// change to the base rate reaches it again. Bookings already made keep the
/// price they were quoted — it is stored on the booking.
class PricingScreen extends ConsumerWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomTypes = ref.watch(allRoomTypesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ລາຄາຫ້ອງ')),
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
          // The property name only helps when there is more than one.
          final manyProperties = list.map((e) => e.property.id).toSet().length > 1;

          return RefreshIndicator(
            color: C.accent,
            onRefresh: () async => ref.invalidate(propertiesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _RoomPriceCard(entry: list[i], showProperty: manyProperties),
            ),
          );
        },
      ),
    );
  }
}

class _RoomPriceCard extends ConsumerWidget {
  const _RoomPriceCard({required this.entry, required this.showProperty});

  final PropertyRoomType entry;
  final bool showProperty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rt = entry.roomType;
    final special = rt.specialPriceNights;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/calendar/pricing/${rt.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rt.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (showProperty)
                Text(entry.property.name, style: const TextStyle(fontSize: 12.5, color: C.muted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: kip(rt.basePrice),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: C.text,
                        ),
                        children: const [
                          TextSpan(
                            text: '  / ຄືນ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => editBasePrice(context, ref, rt),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      foregroundColor: C.accentDark,
                      side: const BorderSide(color: C.accent),
                      textStyle: const TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('ແກ້ລາຄາ'),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
              Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 17,
                    color: special > 0 ? C.accent : C.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      special > 0
                          ? 'ມີລາຄາພິເສດ $special ຄືນທີ່ຈະມາເຖິງ'
                          : 'ຕັ້ງລາຄາຕາມວັນ · ວັນພັກ, ເສົາ-ອາທິດ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: special > 0 ? FontWeight.w600 : FontWeight.w500,
                        color: special > 0 ? C.accentDark : C.soft,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: C.faint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the base-rate sheet and saves what comes back. Shared by the list
/// card and the room type's calendar header.
Future<void> editBasePrice(BuildContext context, WidgetRef ref, RoomType rt) async {
  final price = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
    ),
    builder: (_) => _BasePriceSheet(roomType: rt),
  );
  if (price == null || price == rt.basePrice) return;

  try {
    await ref.read(actionsProvider).setBasePrice(rt, price);
    if (context.mounted) showMessage(context, 'ລາຄາປົກກະຕິເປັນ ${kip(price)} ແລ້ວ');
  } on ApiException catch (e) {
    if (context.mounted) showMessage(context, e.message, error: true);
  }
}

/// One room type's nights for one month, to give some of them a price of
/// their own or close them.
///
/// Picking nights works like any booking calendar: tap the first night, tap
/// the last — the range between is selected. Tapping the same night again
/// clears it. "ເສົາ-ອາທິດ" and "ທັງເດືອນ" select the usual bulk patterns.
/// Past nights are greyed out: they can no longer be sold.
class RoomPricingScreen extends ConsumerStatefulWidget {
  const RoomPricingScreen({super.key, required this.roomTypeId});

  final String roomTypeId;

  @override
  ConsumerState<RoomPricingScreen> createState() => _RoomPricingScreenState();
}

class _RoomPricingScreenState extends ConsumerState<RoomPricingScreen> {
  late final DateTime _thisMonth = () {
    final t = todayUtc();
    return DateTime.utc(t.year, t.month, 1);
  }();
  late DateTime _month = _thisMonth;

  final Set<String> _selected = {};

  /// The first tap of a range, waiting for the tap that closes it.
  String? _anchor;

  String get _today => apiDay(todayUtc());

  void _tap(String iso) {
    setState(() {
      if (_anchor == iso) {
        _anchor = null;
        _selected.clear();
      } else if (_anchor != null) {
        _selected
          ..clear()
          ..addAll(isosBetween(_anchor!, iso));
        _anchor = null;
      } else {
        _selected
          ..clear()
          ..add(iso);
        _anchor = iso;
      }
    });
  }

  void _select(Iterable<CalendarDay> days) {
    HapticFeedback.selectionClick();
    setState(() {
      _anchor = null;
      _selected
        ..clear()
        ..addAll(days.map((d) => d.date).where((iso) => iso.compareTo(_today) >= 0));
    });
  }

  void _clear() => setState(() {
    _anchor = null;
    _selected.clear();
  });

  Future<void> _apply(RoomType rt, List<CalendarDay> visible) async {
    final dates = _selected.toList()..sort();
    if (dates.isEmpty) return;

    final byDate = {for (final d in visible) d.date: d};
    final known = [
      for (final iso in dates)
        if (byDate[iso] != null) byDate[iso]!,
    ];
    final allKnown = known.length == dates.length;
    final prices = known.map((d) => d.price).toSet();

    final result = await showModalBottomSheet<({int? price, String? status})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder:
          (_) => _RangeSheet(
            title: _selectionLabel(dates),
            basePrice: rt.basePrice,
            // Prefilled only when every chosen night shares one price.
            currentPrice: allKnown && prices.length == 1 ? prices.first : null,
            closed: known.isNotEmpty && known.every((d) => d.isClosed),
          ),
    );
    if (result == null) return;

    final actions = ref.read(actionsProvider);
    // A night at the base rate is simply a night without a special price.
    final reset = result.price == rt.basePrice;
    var nights = 0;
    try {
      // The API takes contiguous ranges, `to` exclusive like a check-out.
      for (final run in _runs(dates)) {
        final to = addDays(run.to, 1);
        if (reset) {
          await actions.clearPrices(roomTypeId: rt.id, from: run.from, to: to);
        }
        final price = reset ? null : result.price;
        if (price != null || result.status != null) {
          await actions.setAvailability(
            roomTypeId: rt.id,
            from: run.from,
            to: to,
            price: price,
            status: result.status,
          );
        }
        nights += to.difference(run.from).inDays;
      }
      if (!mounted) return;
      _clear();
      showMessage(context, 'ບັນທຶກແລ້ວ · $nights ຄືນ');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry =
        ref
            .watch(allRoomTypesProvider)
            .value
            ?.where((e) => e.roomType.id == widget.roomTypeId)
            .firstOrNull;

    if (entry == null) {
      final loading = ref.watch(allRoomTypesProvider).isLoading;
      return Scaffold(
        appBar: AppBar(),
        body:
            loading
                ? const LoadingBlock()
                : const EmptyState(
                  message: 'ບໍ່ພົບປະເພດຫ້ອງນີ້',
                  icon: Icons.meeting_room_outlined,
                ),
      );
    }

    final rt = entry.roomType;
    final calendar = ref.watch(roomCalendarProvider((roomTypeId: rt.id, month: _month)));
    final days = calendar.value?.days ?? const <CalendarDay>[];
    final weekends = days.where((d) {
      final w = DateTime.parse('${d.date}T00:00:00.000Z').weekday;
      return w == DateTime.saturday || w == DateTime.sunday;
    });

    return Scaffold(
      appBar: AppBar(title: Text(rt.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _BaseRateBar(price: rt.basePrice, onEdit: () => editBasePrice(context, ref, rt)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed:
                      _month == _thisMonth
                          ? null
                          : () => setState(
                            () => _month = DateTime.utc(_month.year, _month.month - 1, 1),
                          ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    laoMonthYear(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed:
                      () => setState(() => _month = DateTime.utc(_month.year, _month.month + 1, 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                QuickChip(label: 'ເສົາ-ອາທິດ', onTap: () => _select(weekends)),
                const SizedBox(width: 8),
                QuickChip(label: 'ທັງເດືອນ', onTap: () => _select(days)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _anchor != null
                        ? 'ແຕະວັນສຸດທ້າຍ ເພື່ອເລືອກເປັນຊ່ວງ'
                        : 'ແຕະວັນເລີ່ມ ແລ້ວແຕະວັນສຸດທ້າຍ',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: _anchor != null ? FontWeight.w700 : FontWeight.w500,
                      color: _anchor != null ? C.accentDark : C.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: calendar.when(
              loading: () => const LoadingBlock(),
              error:
                  (e, _) =>
                      ErrorRetry(error: e, onRetry: () => ref.invalidate(roomCalendarProvider)),
              data:
                  (cal) => _MonthGrid(
                    month: _month,
                    calendar: cal,
                    today: _today,
                    selected: _selected,
                    anchor: _anchor,
                    onTap: _tap,
                  ),
            ),
          ),
          if (_selected.isNotEmpty)
            _SelectionBar(
              label: _selectionLabel(_selected.toList()..sort()),
              onClear: _clear,
              onApply: () => _apply(rt, days),
            ),
        ],
      ),
    );
  }
}

/// `6–7 ຕຸລາ · 2 ຄືນ`, or just the count when the nights are scattered.
String _selectionLabel(List<String> sorted) {
  final n = sorted.length;
  if (_runs(sorted).length > 1) return '$n ຄືນ';
  final first = '${sorted.first}T00:00:00.000Z';
  final last = '${sorted.last}T00:00:00.000Z';
  return n == 1 ? '${laoDate(first)} · 1 ຄືນ' : '${laoDateRange(first, last)} · $n ຄືນ';
}

/// Groups sorted `YYYY-MM-DD` strings into runs of consecutive days.
List<({DateTime from, DateTime to})> _runs(List<String> sorted) {
  final runs = <({DateTime from, DateTime to})>[];
  DateTime? start;
  DateTime? previous;

  for (final iso in sorted) {
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

class _BaseRateBar extends StatelessWidget {
  const _BaseRateBar({required this.price, required this.onEdit});

  final int price;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(R.md),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(R.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.border),
          ),
          child: Row(
            children: [
              const Text('ລາຄາປົກກະຕິ', style: TextStyle(fontSize: 13, color: C.soft)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${kip(price)} / ຄືນ',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'ແກ້',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.label, required this.onClear, required this.onApply});

  final String label;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ເລືອກແລ້ວ: $label',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: onClear, child: const Text('ລ້າງ')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(onPressed: onApply, child: const Text('ຕັ້ງລາຄາ / ປິດຂາຍ')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.calendar,
    required this.today,
    required this.selected,
    required this.anchor,
    required this.onTap,
  });

  final DateTime month;
  final RoomCalendar calendar;
  final String today;
  final Set<String> selected;
  final String? anchor;
  final void Function(String iso) onTap;

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in calendar.days) d.date: d};

    // Monday-first: DateTime.weekday is 1=Mon…7=Sun, so the offset is
    // weekday-1 blank cells before the 1st.
    final leading = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      children: [
        Row(
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
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.66,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (_, index) {
            if (index < leading) return const SizedBox.shrink();

            final dayNumber = index - leading + 1;
            final iso = apiDay(DateTime.utc(month.year, month.month, dayNumber));
            final day = byDate[iso];
            final past = iso.compareTo(today) < 0;

            return _DayCell(
              dayNumber: dayNumber,
              day: day,
              past: past,
              isToday: iso == today,
              selected: selected.contains(iso),
              isAnchor: anchor == iso,
              onTap: day == null || past ? null : () => onTap(iso),
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
    required this.past,
    required this.isToday,
    required this.selected,
    required this.isAnchor,
    this.onTap,
  });

  final int dayNumber;
  final CalendarDay? day;
  final bool past;
  final bool isToday;
  final bool selected;
  final bool isAnchor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final closed = day?.isClosed ?? false;
    final full = day?.isFull ?? false;
    final special = day?.special ?? false;

    final background =
        selected
            ? C.accent
            : closed
            ? C.neutralBg
            : full
            ? C.accentSoft
            : C.surface;
    final foreground =
        selected
            ? Colors.white
            : closed
            ? C.neutralFg
            : C.text;
    final priceColor =
        selected
            ? Colors.white
            : special && !closed
            ? C.accentDark
            : foreground;

    return Opacity(
      opacity: past ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.sm),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(R.sm),
            border: Border.all(
              color:
                  isAnchor
                      ? C.accentDark
                      : isToday && !selected
                      ? C.accent
                      : C.border,
              width: isAnchor || (isToday && !selected) ? 1.8 : 1,
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
                      closed ? 'ປິດ' : kipShort(day!.price).replaceFirst('₭', ''),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: priceColor,
                      ),
                    ),
                  // Rooms left of this type: "3/8" is sellable, "ເຕັມ" is not.
                  if (day != null && !closed) ...[
                    const SizedBox(height: 3),
                    Text(
                      full ? 'ເຕັມ' : '${day!.available}/${day!.total}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color:
                            selected
                                ? Colors.white.withValues(alpha: 0.85)
                                : full
                                ? C.accentDark
                                : C.muted,
                      ),
                    ),
                  ],
                ],
              ),
              if (special && !closed)
                Positioned(
                  top: 1,
                  right: 2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : C.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
      ],
    );

    Widget swatch(Color color) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: C.border),
      ),
    );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle),
          ),
          'ລາຄາພິເສດ',
        ),
        item(swatch(C.accentSoft), 'ເຕັມ'),
        item(swatch(C.neutralBg), 'ປິດຂາຍ'),
        item(swatch(C.accent), 'ເລືອກຢູ່'),
      ],
    );
  }
}

// ── sheets ──────────────────────────────────────────────────────────────────

const _sheetFootnote = 'ການຈອງທີ່ມີຢູ່ແລ້ວ ລາຄາບໍ່ປ່ຽນ';

/// Whole kip from whatever is in the field, commas and all.
int? _parseKip(String text) => int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));

/// To the nearest thousand: a 10% bump on ₭350,000 should read ₭385,000, not
/// a number no one would charge.
int _roundKip(num value) => ((value / 1000).round() * 1000).toInt();

/// `350000` → `350,000` as the partner types.
class _KipFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final n = _parseKip(newValue.text);
    if (n == null) return const TextEditingValue();
    final text = kip(n).replaceFirst('₭', '');
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

String _grouped(int n) => kip(n).replaceFirst('₭', '');

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.onChanged, this.hint, this.error});

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [_KipFormatter()],
      onChanged: (_) => onChanged(),
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        prefixText: '₭ ',
        suffixText: '/ ຄືນ',
        hintText: hint,
        errorText: error,
      ),
    );
  }
}

class _BasePriceSheet extends StatefulWidget {
  const _BasePriceSheet({required this.roomType});

  final RoomType roomType;

  @override
  State<_BasePriceSheet> createState() => _BasePriceSheetState();
}

class _BasePriceSheetState extends State<_BasePriceSheet> {
  late final _field = TextEditingController(text: _grouped(widget.roomType.basePrice));

  int? get _price => _parseKip(_field.text);
  bool get _valid => (_price ?? 0) >= 1000;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _bump(double factor) {
    _field.text = _grouped(_roundKip(widget.roomType.basePrice * factor));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rt = widget.roomType;
    final special = rt.specialPriceNights;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ລາຄາປົກກະຕິ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          Text(rt.name, style: const TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 16),
          _PriceField(
            controller: _field,
            onChanged: () => setState(() {}),
            error: _field.text.isNotEmpty && !_valid ? 'ລາຄາຢ່າງໜ້ອຍ ₭1,000' : null,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              QuickChip(label: '−10%', onTap: () => _bump(0.9)),
              QuickChip(label: '+10%', onTap: () => _bump(1.1)),
              QuickChip(label: '+20%', onTap: () => _bump(1.2)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            special > 0 ? 'ໃຊ້ກັບທຸກຄືນ ຍົກເວັ້ນ $special ຄືນທີ່ມີລາຄາພິເສດ' : 'ໃຊ້ກັບທຸກຄືນ',
            style: const TextStyle(fontSize: 12.5, color: C.soft),
          ),
          const Text(_sheetFootnote, style: TextStyle(fontSize: 12.5, color: C.soft)),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _valid ? () => Navigator.of(context).pop(_price) : null,
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
  }
}

/// Price and open/closed for the chosen nights, in one save. Only what the
/// partner changed is sent: a prefilled price left alone, or the switch left
/// where it started, changes nothing.
class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.title,
    required this.basePrice,
    required this.currentPrice,
    required this.closed,
  });

  final String title;
  final int basePrice;

  /// The nights' shared price, or null when they differ.
  final int? currentPrice;

  /// True only when every chosen night is closed.
  final bool closed;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late final _field = TextEditingController(
    text: widget.currentPrice == null ? '' : _grouped(widget.currentPrice!),
  );
  late final String _initialText = _field.text;
  late bool _closed = widget.closed;

  int? get _price => _parseKip(_field.text);
  bool get _priceChanged => _field.text != _initialText && _field.text.isNotEmpty;
  bool get _priceValid => !_priceChanged || (_price ?? 0) >= 1000;
  bool get _canSave => _priceValid && (_priceChanged || _closed != widget.closed);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _setPrice(int price) {
    _field.text = _grouped(price);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.basePrice;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _PriceField(
            controller: _field,
            onChanged: () => setState(() {}),
            hint: widget.currentPrice == null ? 'ຫຼາຍລາຄາ · ໃສ່ລາຄາໃໝ່' : null,
            error: _priceValid ? null : 'ລາຄາຢ່າງໜ້ອຍ ₭1,000',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              QuickChip(
                label: 'ລາຄາປົກກະຕິ',
                selected: _price == base,
                onTap: () => _setPrice(base),
              ),
              QuickChip(label: '+10%', onTap: () => _setPrice(_roundKip(base * 1.1))),
              QuickChip(label: '+20%', onTap: () => _setPrice(_roundKip(base * 1.2))),
              QuickChip(label: '+50%', onTap: () => _setPrice(_roundKip(base * 1.5))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ເປີເຊັນທຽບກັບລາຄາປົກກະຕິ ${kip(base)}',
            style: const TextStyle(fontSize: 11.5, color: C.muted),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _closed,
            onChanged: (v) => setState(() => _closed = v),
            activeTrackColor: C.accent,
            title: const Text(
              'ປິດຂາຍຊ່ວງນີ້',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'ແຂກຈະຈອງຄືນເຫຼົ່ານີ້ບໍ່ໄດ້',
              style: TextStyle(fontSize: 12.5, color: C.muted),
            ),
          ),
          const Text(_sheetFootnote, style: TextStyle(fontSize: 12.5, color: C.soft)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                _canSave
                    ? () => Navigator.of(context).pop((
                      price: _priceChanged ? _price : null,
                      status: _closed == widget.closed ? null : (_closed ? 'closed' : 'open'),
                    ))
                    : null,
            child: const Text('ບັນທຶກ'),
          ),
        ],
      ),
    );
  }
}
