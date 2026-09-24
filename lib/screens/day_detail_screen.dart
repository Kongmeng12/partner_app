import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/property_picker.dart';

/// What the summary chips filter the room list by.
enum _Filter { booked, arrivals, departures, free, cleaning }

/// Every room on one day: each room type, each numbered room, who is in it,
/// and what the host has to do about it. Reached by tapping a day on the
/// Calendar; ‹ › in the app bar step through days without going back.
class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({super.key, required this.date});

  /// `YYYY-MM-DD`, from the route.
  final String date;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  _Filter? _filter;

  DateTime get _day => parseDay('${widget.date}T00:00:00.000Z') ?? todayUtc();

  void _goTo(DateTime day) => context.go('/calendar/day/${apiDay(day)}');

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.utc(2020),
      lastDate: addDays(todayUtc(), 730),
    );
    if (picked != null) {
      _goTo(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  void _toggle(_Filter f) => setState(() => _filter = _filter == f ? null : f);

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final isToday = day == todayUtc();
    final properties = ref.watch(propertiesProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(R.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    laoFullDate(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: C.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'ມື້ນີ້',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: C.accentDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'ມື້ກ່ອນ',
            onPressed: () => _goTo(addDays(day, -1)),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'ມື້ຕໍ່ໄປ',
            onPressed: () => _goTo(addDays(day, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
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
              message: 'ຍັງບໍ່ມີທີ່ພັກ',
              icon: Icons.home_outlined,
            );
          }
          final selected = ref.watch(selectedPropertyProvider);
          final property =
              list.where((p) => p.id == selected).firstOrNull ?? list.first;
          final board = ref.watch(
            dayBoardProvider((propertyId: property.id, date: day)),
          );

          return board.when(
            loading: () => const LoadingBlock(),
            error:
                (e, _) => ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(dayBoardProvider),
                ),
            data:
                (b) => RefreshIndicator(
                  color: C.accent,
                  onRefresh: () async => ref.invalidate(dayBoardProvider),
                  child: _Body(
                    board: b,
                    day: day,
                    filter: _filter,
                    onFilter: _toggle,
                    propertyChip:
                        list.length > 1
                            ? QuickChip(
                              label: '${property.name}  ▾',
                              onTap:
                                  () => pickCalendarProperty(
                                    context,
                                    ref,
                                    list,
                                    property.id,
                                  ),
                            )
                            : null,
                  ),
                ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.board,
    required this.day,
    required this.filter,
    required this.onFilter,
    this.propertyChip,
  });

  final DayBoard board;
  final DateTime day;
  final _Filter? filter;
  final ValueChanged<_Filter> onFilter;
  final Widget? propertyChip;

  @override
  Widget build(BuildContext context) {
    final sections = [
      for (final s in board.roomTypes)
        if (_visible(s)) s,
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (propertyChip != null)
          Align(alignment: Alignment.centerLeft, child: propertyChip),
        if (propertyChip != null) const SizedBox(height: 10),
        _SummaryStrip(
          summary: board.summary,
          filter: filter,
          onFilter: onFilter,
        ),
        if (board.summary.unassigned > 0 &&
            (filter == null || filter == _Filter.booked)) ...[
          const SizedBox(height: 10),
          _UnassignedBanner(count: board.summary.unassigned),
        ],
        if (board.roomTypes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              message: 'ຍັງບໍ່ມີປະເພດຫ້ອງ',
              icon: Icons.meeting_room_outlined,
            ),
          )
        else if (sections.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              message: 'ບໍ່ມີລາຍການທີ່ຕົງກັບຕົວກອງນີ້',
              icon: Icons.filter_alt_off_outlined,
            ),
          )
        else
          for (final s in sections)
            _RoomTypeSection(section: s, day: day, filter: filter),
      ],
    );
  }

  bool _visible(DayRoomTypeSection s) {
    if (filter == null) return true;
    if (s.hasRoomNumbers) {
      final unassigned = filter == _Filter.booked && s.unassigned.isNotEmpty;
      return unassigned || s.rooms.any((r) => _roomMatches(filter!, r, day));
    }
    return s.bookings.any((b) => _bookingMatches(filter!, b, day));
  }
}

bool _roomMatches(_Filter f, DayRoom r, DateTime day) {
  final s = r.stateOn(day);
  return switch (f) {
    _Filter.booked =>
      s == RoomDayState.occupied ||
          s == RoomDayState.arriving ||
          s == RoomDayState.turnover,
    _Filter.arrivals =>
      s == RoomDayState.arriving || s == RoomDayState.turnover,
    _Filter.departures =>
      s == RoomDayState.departing || s == RoomDayState.turnover,
    _Filter.free => s == RoomDayState.available,
    _Filter.cleaning => r.status == 'needs_cleaning',
  };
}

bool _bookingMatches(_Filter f, DayBooking b, DateTime day) => switch (f) {
  _Filter.booked => !b.departsOn(day),
  _Filter.arrivals => b.arrivesOn(day),
  _Filter.departures => b.departsOn(day),
  _Filter.free || _Filter.cleaning => false,
};

// ── summary ─────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.summary,
    required this.filter,
    required this.onFilter,
  });

  final DaySummary summary;
  final _Filter? filter;
  final ValueChanged<_Filter> onFilter;

  @override
  Widget build(BuildContext context) {
    Widget tile(_Filter f, String value, String label, {Color? tint}) {
      final selected = filter == f;
      return Expanded(
        child: InkWell(
          onTap: () => onFilter(f),
          borderRadius: BorderRadius.circular(R.md),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? C.accentSoft : C.surface,
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(
                color: selected ? C.accent : C.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: selected ? C.accentDark : (tint ?? C.text),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? C.accentDark : C.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(_Filter.booked, '${summary.taken}/${summary.total}', 'ຈອງ'),
        const SizedBox(width: 6),
        tile(
          _Filter.arrivals,
          '${summary.arrivals}',
          'ເຂົ້າ',
          tint: C.successFg,
        ),
        const SizedBox(width: 6),
        tile(
          _Filter.departures,
          '${summary.departures}',
          'ອອກ',
          tint: const Color(0xFFE08A1E),
        ),
        const SizedBox(width: 6),
        tile(_Filter.free, '${summary.free}', 'ວ່າງ'),
        const SizedBox(width: 6),
        tile(
          _Filter.cleaning,
          '${summary.needsCleaning}',
          'ທຳສະອາດ',
          tint: C.warnFg,
        ),
      ],
    );
  }
}

class _UnassignedBanner extends StatelessWidget {
  const _UnassignedBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.warnBg,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: C.warnFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ມີ $count ການຈອງທີ່ຍັງບໍ່ໄດ້ກຳນົດເບີຫ້ອງ',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: C.warnFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── room types ──────────────────────────────────────────────────────────────

class _RoomTypeSection extends StatelessWidget {
  const _RoomTypeSection({
    required this.section,
    required this.day,
    required this.filter,
  });

  final DayRoomTypeSection section;
  final DateTime day;
  final _Filter? filter;

  @override
  Widget build(BuildContext context) {
    final rooms = [
      for (final r in section.rooms)
        if (filter == null || _roomMatches(filter!, r, day)) r,
    ];
    final bookings = [
      for (final b in section.bookings)
        if (filter == null || _bookingMatches(filter!, b, day)) b,
    ];
    final showUnassigned =
        section.unassigned.isNotEmpty &&
        (filter == null || filter == _Filter.booked);

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(section: section),
          const SizedBox(height: 10),
          if (showUnassigned) ...[
            _UnassignedCard(bookings: section.unassigned),
            const SizedBox(height: 8),
          ],
          if (section.hasRoomNumbers)
            for (final room in rooms)
              _RoomCard(room: room, section: section, day: day)
          else ...[
            if (filter == null) _NoRoomNumbersNote(section: section),
            for (final b in bookings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Panel(child: _GuestBlock(booking: b, day: day)),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});
  final DayRoomTypeSection section;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: C.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.roomTypeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                section.total > 0
                    ? '${section.taken}/${section.total} ຈອງ · ${kip(section.price)}'
                    : kip(section.price),
                style: const TextStyle(
                  fontSize: 12,
                  color: C.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!section.onSale)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: C.neutralBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'ປິດຂາຍ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: C.neutralFg,
              ),
            ),
          ),
      ],
    );
  }
}

class _NoRoomNumbersNote extends StatelessWidget {
  const _NoRoomNumbersNote({required this.section});
  final DayRoomTypeSection section;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: C.faint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              section.bookings.isEmpty
                  ? 'ບໍ່ມີການຈອງໃນມື້ນີ້ · ປະເພດຫ້ອງນີ້ຍັງບໍ່ໄດ້ຕັ້ງເບີຫ້ອງ'
                  : 'ປະເພດຫ້ອງນີ້ຍັງບໍ່ໄດ້ຕັ້ງເບີຫ້ອງ',
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/more/properties'),
            child: const Text('ໄປຕັ້ງຄ່າ'),
          ),
        ],
      ),
    );
  }
}

class _UnassignedCard extends StatelessWidget {
  const _UnassignedCard({required this.bookings});
  final List<DayBooking> bookings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.warnBg,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: C.warnFg.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ຍັງບໍ່ໄດ້ກຳນົດເບີຫ້ອງ (${bookings.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: C.warnFg,
            ),
          ),
          for (final b in bookings)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.guestName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${laoDateRange(b.checkIn, b.checkOut)} · ${b.nights} ຄືນ'
                          '${b.missingRooms > 1 ? ' · ຂາດ ${b.missingRooms} ຫ້ອງ' : ''}',
                          style: const TextStyle(fontSize: 12, color: C.soft),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    style: _compactButton,
                    onPressed: () => context.go('/bookings/${b.bookingId}'),
                    child: const Text('ຈັດຫ້ອງ'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── one numbered room ───────────────────────────────────────────────────────

final _compactButton = FilledButton.styleFrom(
  minimumSize: const Size(0, 34),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
);

class _RoomCard extends ConsumerWidget {
  const _RoomCard({
    required this.room,
    required this.section,
    required this.day,
  });

  final DayRoom room;
  final DayRoomTypeSection section;
  final DateTime day;

  ({Color bg, Color fg}) _tint(RoomDayState s) => switch (s) {
    RoomDayState.occupied ||
    RoomDayState.arriving => (bg: C.accentSoft, fg: C.accentDark),
    RoomDayState.departing ||
    RoomDayState.turnover => (bg: C.infoBg, fg: C.infoFg),
    RoomDayState.needsCleaning => (bg: C.warnBg, fg: C.warnFg),
    RoomDayState.maintenance ||
    RoomDayState.inactive => (bg: C.neutralBg, fg: C.neutralFg),
    RoomDayState.available => (bg: C.successBg, fg: C.successFg),
  };

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      if (context.mounted) showMessage(context, done);
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = room.stateOn(day);
    final tint = _tint(state);
    final actions = ref.read(actionsProvider);
    final dirty = room.status == 'needs_cleaning';

    Widget cleanButton() => FilledButton.tonal(
      style: _compactButton,
      onPressed:
          () => _run(
            context,
            () => actions.markRoomClean(room.roomId),
            'ທຳຄວາມສະອາດແລ້ວ',
          ),
      child: const Text('ທຳຄວາມສະອາດແລ້ວ'),
    );

    final Widget content = switch (state) {
      RoomDayState.occupied ||
      RoomDayState.arriving => _GuestBlock(booking: room.occupant!, day: day),
      RoomDayState.departing => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuestBlock(booking: room.departure!, day: day),
          if (dirty) ...[const SizedBox(height: 8), cleanButton()],
        ],
      ),
      RoomDayState.turnover => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuestBlock(booking: room.departure!, day: day, caption: 'ອອກ'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          _GuestBlock(booking: room.occupant!, day: day, caption: 'ເຂົ້າ'),
        ],
      ),
      RoomDayState.needsCleaning => _StateRow(
        label: 'ຕ້ອງທຳຄວາມສະອາດ',
        color: C.warnFg,
        trailing: cleanButton(),
      ),
      RoomDayState.maintenance => _StateRow(
        label: 'ບຳລຸງຮັກສາ',
        color: C.neutralFg,
        trailing: FilledButton.tonal(
          style: _compactButton,
          onPressed:
              () => _run(
                context,
                () => actions.updateRoom(room.roomId, status: 'available'),
                'ເປີດໃຊ້ຫ້ອງ ${room.roomNumber} ແລ້ວ',
              ),
          child: const Text('ເປີດໃຊ້'),
        ),
      ),
      RoomDayState.inactive => const _StateRow(
        label: 'ປິດໃຊ້ງານ',
        color: C.neutralFg,
      ),
      RoomDayState.available => _StateRow(
        label: 'ວ່າງ',
        color: C.successFg,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed:
                  () => context.go(
                    Uri(
                      path: '/bookings/walk-in',
                      queryParameters: {
                        'roomTypeId': section.roomTypeId,
                        'date': apiDay(day),
                        'roomId': room.roomId,
                        'roomNumber': room.roomNumber,
                      },
                    ).toString(),
                  ),
              child: const Text('+ Walk-in'),
            ),
            PopupMenuButton<String>(
              tooltip: 'ເພີ່ມເຕີມ',
              icon: const Icon(Icons.more_vert, size: 20, color: C.muted),
              onSelected:
                  (_) => _run(
                    context,
                    () =>
                        actions.updateRoom(room.roomId, status: 'maintenance'),
                    'ປິດຫ້ອງ ${room.roomNumber} ເພື່ອບຳລຸງຮັກສາ',
                  ),
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(
                      value: 'maintenance',
                      child: Text('ປິດເພື່ອບຳລຸງຮັກສາ'),
                    ),
                  ],
            ),
          ],
        ),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: tint.bg,
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Column(
                children: [
                  Text(
                    room.roomNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tint.fg,
                    ),
                  ),
                  if (room.floor != null && room.floor!.isNotEmpty)
                    Text(
                      'ຊັ້ນ ${room.floor}',
                      style: TextStyle(fontSize: 9.5, color: tint.fg),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.label, required this.color, this.trailing});

  final String label;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A guest's stay: name, status, dates, badges, and a call button. Tapping it
/// opens the booking.
class _GuestBlock extends StatelessWidget {
  const _GuestBlock({required this.booking, required this.day, this.caption});

  final DayBooking booking;
  final DateTime day;

  /// "ອອກ" / "ເຂົ້າ" on a turnover card, where two guests share one room.
  final String? caption;

  Widget _badge(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final phone = b.guestPhone;

    return InkWell(
      onTap: () => context.go('/bookings/${b.bookingId}'),
      borderRadius: BorderRadius.circular(R.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        caption == null
                            ? b.guestName
                            : '$caption · ${b.guestName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusPill(
                      map: bookingStatusPill,
                      status: b.status,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${laoDateRange(b.checkIn, b.checkOut)} · ${b.nights} ຄືນ · ${b.guests} ຄົນ',
                  style: const TextStyle(fontSize: 12, color: C.soft),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (b.arrivesOn(day))
                      _badge('ເຂົ້າມື້ນີ້', C.successBg, C.successFg),
                    if (b.departsOn(day))
                      _badge('ອອກມື້ນີ້', C.infoBg, C.infoFg),
                    if (b.paymentStatus != null)
                      StatusPill(
                        map: paymentStatusPill,
                        status: b.paymentStatus,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              tooltip: phone,
              visualDensity: VisualDensity.compact,
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              icon: const Icon(Icons.call_outlined, color: C.accentDark),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: C.border),
      ),
      child: child,
    );
  }
}
