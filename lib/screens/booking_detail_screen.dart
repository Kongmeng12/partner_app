import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, success);
    } on ApiException catch (e) {
      // The API's message says exactly why — "ປ່ຽນຈາກ done ໄປ staying ບໍ່ໄດ້"
      // is far more use than a generic failure.
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel(BookingDetail b) async {
    final reason = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ຍົກເລີກການຈອງ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              b.paidAmount > 0
                  ? 'ແຂກຈ່າຍມາແລ້ວ — ລະບົບຈະຄິດຄ່າທຳນຽມ ແລະ ຄືນເງິນສ່ວນທີ່ເຫຼືອອັດຕະໂນມັດ.'
                  : 'ການຈອງນີ້ຍັງບໍ່ໄດ້ຈ່າຍ ຈຶ່ງບໍ່ມີການຄືນເງິນ.',
              style: const TextStyle(fontSize: 13.5, color: C.soft, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'ເຫດຜົນ (ບໍ່ບັງຄັບ)'),
              maxLength: 255,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('ບໍ່ຍົກເລີກ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.dangerFg),
            onPressed: () => ctx.pop(true),
            child: const Text('ຢືນຢັນຍົກເລີກ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _run(
      () => ref.read(actionsProvider).cancelBooking(widget.bookingId, reason.text.trim()),
      'ຍົກເລີກການຈອງແລ້ວ',
    );
  }

  Future<void> _assignRoom(BookingDetail b) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (_) => _AssignRoomSheet(
        bookingId: widget.bookingId,
        roomTypeName: b.roomTypeName,
        checkInLabel: laoDate(b.checkIn),
        checkOutLabel: laoDate(b.checkOut),
      ),
    );
  }

  Future<void> _setStatus(String status, String success) => _run(
        () => ref.read(actionsProvider).setBookingStatus(widget.bookingId, status),
        success,
      );

  /// A guest is put in a room when they are checked in — so if no room has
  /// been assigned and the property has numbered rooms to give, offer to pick
  /// one first. Never forced: plenty of properties don't number their rooms,
  /// and a room list that fails to load must not block a guest at the desk.
  Future<void> _checkIn(BookingDetail b) async {
    if (b.roomNumbers.isEmpty && b.canAssignRoom) {
      BookingRoomOptions? options;
      try {
        options = await ref.read(bookingRoomOptionsProvider(widget.bookingId).future);
      } on ApiException {
        options = null;
      }
      if (!mounted) return;

      if (options != null && options.rooms.isNotEmpty) {
        final assignFirst = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ຍັງບໍ່ໄດ້ກຳນົດຫ້ອງ'),
            content: const Text('ກຳນົດເລກຫ້ອງໃຫ້ແຂກກ່ອນເຊັກອິນບໍ?'),
            actions: [
              TextButton(onPressed: () => ctx.pop(false), child: const Text('ເຊັກອິນເລີຍ')),
              FilledButton(onPressed: () => ctx.pop(true), child: const Text('ກຳນົດຫ້ອງ')),
            ],
          ),
        );
        if (!mounted || assignFirst == null) return;
        if (assignFirst) {
          await _assignRoom(b);
          return;
        }
      }
    }
    await _setStatus('staying', 'ເຊັກອິນແລ້ວ — ສະຖານະ: ກຳລັງພັກ');
  }

  Future<void> _checkOut(BookingDetail b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ເຊັກເອົາ?'),
        content: const Text(
          'ແຂກອອກຈາກຫ້ອງແລ້ວ? ການຈອງຈະປິດເປັນ "ສຳເລັດ" ແລະ ແຂກຈະໄດ້ຮັບແຈ້ງເຕືອນໃຫ້ຂຽນຮີວິວ.',
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('ຍັງບໍ່')),
          FilledButton(onPressed: () => ctx.pop(true), child: const Text('ເຊັກເອົາ')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _setStatus('completed', 'ເຊັກເອົາແລ້ວ — ສຳເລັດການເຂົ້າພັກ');
  }

  Future<void> _undoCheckIn(BookingDetail b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ຍົກເລີກການເຊັກອິນ?'),
        content: const Text('ການຈອງຈະກັບເປັນ "ຢືນຢັນ" ຄືກັບກ່ອນເຊັກອິນ.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('ບໍ່')),
          FilledButton(onPressed: () => ctx.pop(true), child: const Text('ຍົກເລີກເຊັກອິນ')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _setStatus('confirmed', 'ຍົກເລີກການເຊັກອິນແລ້ວ');
  }

  /// Why check-in is not on offer yet — the API's own window, in plain words.
  String _checkInHint(BookingDetail b) {
    final checkIn = parseDay(b.checkIn);
    if (checkIn != null && todayUtc().isBefore(checkIn)) {
      return 'ເຊັກອິນໄດ້ຕັ້ງແຕ່ມື້ເຂົ້າພັກ (${laoDate(b.checkIn)})';
    }
    return 'ເກີນມື້ອອກແລ້ວ — ລະບົບຈະປິດການເຂົ້າພັກໃຫ້ເອງ';
  }

  /// Opens the thread attached to this booking.
  ///
  /// A partner cannot start one — only a guest can — so if the guest has never
  /// written, there is nothing to open and saying so is better than dropping
  /// them into an empty screen with no way to begin.
  ///
  /// A conversation belongs to the property, not to a single booking (see
  /// [Conversation]): a guest who books twice keeps one thread, tagged with
  /// whichever booking it started against. So an exact `bookingId` match can
  /// miss a thread that plainly belongs to this guest — fall back to matching
  /// by guest id + property id (not by name, which two guests can share)
  /// before concluding there is truly nothing to open.
  Future<void> _openChat(BuildContext context) async {
    final conversations = await ref.read(conversationsProvider.future);
    final detail = await ref.read(bookingDetailProvider(widget.bookingId).future);

    final thread = conversations.items
            .where((c) => c.bookingId == widget.bookingId)
            .firstOrNull ??
        conversations.items
            .where((c) => c.customerId == detail.guestId && c.propertyId == detail.propertyId)
            .firstOrNull;

    if (!context.mounted) return;
    if (thread == null) {
      showMessage(context, 'ແຂກຍັງບໍ່ໄດ້ເລີ່ມສົນທະນາສຳລັບການຈອງນີ້');
      return;
    }
    context.go('/chats/${thread.id}');
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.code ?? 'ລາຍລະອຽດການຈອງ'),
        actions: [
          IconButton(
            tooltip: 'ແຊັດກັບແຂກ',
            onPressed: () => _openChat(context),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: detail.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (b) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                StatusPill(map: bookingStatusPill, status: b.status),
                const SizedBox(width: 8),
                if (b.paymentStatus != null)
                  StatusPill(map: paymentStatusPill, status: b.paymentStatus),
                const Spacer(),
                if (b.isWalkIn)
                  const Text(
                    'Walk-in',
                    style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            SectionCard(
              title: 'ແຂກ',
              child: Column(
                children: [
                  Row(
                    children: [
                      Avatar(name: b.guestName, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.guestName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.guestPhone,
                              style: const TextStyle(fontSize: 13, color: C.soft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (b.guestEmail.isNotEmpty)
                    LabelledRow(label: 'ອີເມວ', value: b.guestEmail),

                ],
              ),
            ),

            const SizedBox(height: 14),
            SectionCard(
              title: 'ການເຂົ້າພັກ',
              child: Column(
                children: [
                  LabelledRow(label: 'ທີ່ພັກ', value: b.propertyName),
                  LabelledRow(
                    label: 'ຫ້ອງ',
                    value: b.roomQuantity > 1
                        ? '${b.roomTypeName} × ${b.roomQuantity}'
                        : b.roomTypeName,
                  ),
                  _RoomAssignmentRow(
                    roomNumbers: b.roomNumbers,
                    editable: b.canAssignRoom,
                    onTap: () => _assignRoom(b),
                  ),
                  LabelledRow(label: 'ເຂົ້າພັກ', value: laoDate(b.checkIn), strong: true),
                  LabelledRow(label: 'ອອກ', value: laoDate(b.checkOut), strong: true),
                  LabelledRow(label: 'ຈຳນວນຄືນ', value: '${b.nights} ຄືນ'),
                  LabelledRow(label: 'ຜູ້ເຂົ້າພັກ', value: '${b.guests} ຄົນ'),
                ],
              ),
            ),

            const SizedBox(height: 14),
            SectionCard(
              title: 'ຍອດເງິນ',
              child: Column(
                children: [
                  MoneyRow(label: 'ຄ່າຫ້ອງ', amount: b.subtotal),
                  // Walk-ins carry no platform service fee, so the row would
                  // just read ₭0 — hide it rather than explain a zero.
                  if (b.serviceFee > 0) MoneyRow(label: 'ຄ່າບໍລິການ', amount: b.serviceFee),
                  if (b.tax > 0) MoneyRow(label: 'ພາສີ', amount: b.tax),
                  if (b.cleaningFee > 0)
                    MoneyRow(label: 'ຄ່າທຳຄວາມສະອາດ', amount: b.cleaningFee),
                  if (b.discount > 0)
                    MoneyRow(label: 'ສ່ວນຫຼຸດ', amount: b.discount, negative: true),
                  const Divider(height: 20),
                  MoneyRow(label: 'ລວມທັງໝົດ', amount: b.total, strong: true),
                  if (b.paidAmount > 0) ...[
                    const SizedBox(height: 4),
                    MoneyRow(label: 'ຈ່າຍແລ້ວ', amount: b.paidAmount),
                  ],
                  // What this stay is actually worth to the property, which is
                  // the number the partner cares about — not the guest's total.
                  const Divider(height: 20),
                  MoneyRow(
                    label: 'ຄອມມິຊຊັນ ${b.commissionRate}%',
                    amount: b.commission,
                    negative: true,
                  ),
                  MoneyRow(label: 'ຮັບສຸດທິ', amount: b.payout, strong: true),
                ],
              ),
            ),

            if (b.specialRequest != null && b.specialRequest!.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'ຄຳຂໍພິເສດຈາກແຂກ',
                child: Text(
                  b.specialRequest!,
                  style: const TextStyle(fontSize: 13.5, color: C.soft, height: 1.6),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Only the moves the backend says are open today are offered — it
            // answers 400 for anything else, so a button for it would be a lie.
            // Status moves by itself where it can: payment confirms the booking,
            // an expired hold cancels it, and a finished stay is closed out
            // after check-out. What is left for the front desk is the two
            // things only a person can know — the guest arrived, the guest left.
            if (b.awaitingPayment)
              _StatusNote(
                icon: Icons.hourglass_top_rounded,
                text: 'ລໍຖ້າແຂກຈ່າຍເງິນ — ລະບົບຈະຢືນຢັນການຈອງໃຫ້ເອງເມື່ອໄດ້ຮັບເງິນ',
              ),

            if (b.status == 'confirmed')
              b.canCheckIn
                  ? FilledButton.icon(
                      onPressed: _busy ? null : () => _checkIn(b),
                      icon: const Icon(Icons.login_rounded, size: 19),
                      label: const Text('ເຊັກອິນ (ແຂກມາຮອດ)'),
                    )
                  : _StatusNote(
                      icon: Icons.event_available_outlined,
                      text: _checkInHint(b),
                    ),

            if (b.canCheckOut)
              FilledButton.icon(
                onPressed: _busy ? null : () => _checkOut(b),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('ເຊັກເອົາ (ແຂກອອກແລ້ວ)'),
              ),

            if (b.canUndoCheckIn) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy ? null : () => _undoCheckIn(b),
                child: const Text('ກົດເຊັກອິນຜິດ? ຍົກເລີກການເຊັກອິນ'),
              ),
            ],

            if (b.canCancel) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _confirmCancel(b),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.dangerFg,
                  side: const BorderSide(color: C.dangerBg),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 19),
                label: const Text('ຍົກເລີກການຈອງ'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A quiet line explaining why there is no button — an empty gap where an
/// action might be reads as a bug, so say what the system is doing instead.
class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.infoBg,
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: C.infoFg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: C.infoFg, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one editable fact in the stay card — every other row here is a record
/// of what happened; this one is a decision the property can make or revisit
/// any time before the stay ends. Unassigned is drawn as a gap worth closing,
/// not a blank worth ignoring, since most bookings start here and would stay
/// here forever if the row only ever displayed and never invited action.
class _RoomAssignmentRow extends StatelessWidget {
  const _RoomAssignmentRow({
    required this.roomNumbers,
    required this.editable,
    required this.onTap,
  });

  final List<String> roomNumbers;
  final bool editable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assigned = roomNumbers.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 118,
            child: Text('ເລກຫ້ອງ', style: TextStyle(fontSize: 13, color: C.muted)),
          ),
          Expanded(
            child: assigned
                ? Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final number in roomNumbers)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: C.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            number,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.accentDark,
                            ),
                          ),
                        ),
                      if (editable)
                        InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.edit_outlined, size: 15, color: C.muted),
                          ),
                        ),
                    ],
                  )
                : editable
                    ? InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(R.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: C.accent),
                            borderRadius: BorderRadius.circular(R.md),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_circle_outline, size: 15, color: C.accentDark),
                              SizedBox(width: 5),
                              Text(
                                'ກຳນົດຫ້ອງ',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: C.accentDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const Text('ຍັງບໍ່ໄດ້ກຳນົດ', style: TextStyle(fontSize: 13.5, color: C.faint)),
          ),
        ],
      ),
    );
  }
}

/// Picks which physical room(s) a booking holds. Same floor-grouped reading
/// order as room-type management (`groupRoomsByFloor`), but every tile here
/// is chosen from rather than edited — the list only ever contains rooms
/// already free for this stay's dates, so nothing inside it needs its own
/// "unavailable" state; the only real choice besides which room is whether to
/// pick one at all.
class _AssignRoomSheet extends ConsumerStatefulWidget {
  const _AssignRoomSheet({
    required this.bookingId,
    required this.roomTypeName,
    required this.checkInLabel,
    required this.checkOutLabel,
  });

  final String bookingId;
  final String roomTypeName;
  final String checkInLabel;
  final String checkOutLabel;

  @override
  ConsumerState<_AssignRoomSheet> createState() => _AssignRoomSheetState();
}

class _AssignRoomSheetState extends ConsumerState<_AssignRoomSheet> {
  /// Null until the fetch resolves and seeds it from what the booking already
  /// holds — an empty (non-null) set from then on means "no room," a real
  /// choice this sheet lets a partner make deliberately, not just an
  /// unanswered question.
  Set<String>? _selected;
  bool _busy = false;

  void _seedIfNeeded(BookingRoomOptions options) {
    _selected ??= options.currentRoomIds.toSet();
  }

  void _toggle(String roomId, int quantity) {
    setState(() {
      final selected = _selected!;
      if (selected.contains(roomId)) {
        selected.remove(roomId);
        return;
      }
      // Picking a room while at capacity replaces the whole selection when
      // there is only one slot (the overwhelming common case) rather than
      // silently refusing the tap — a partner correcting a mistaken pick
      // should not have to deselect first to select the right room.
      if (quantity == 1) selected.clear();
      if (selected.length < quantity) selected.add(roomId);
    });
  }

  void _pickNoRoom() => setState(() => _selected = {});

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(actionsProvider).assignRoom(widget.bookingId, selected.toList());
      if (mounted) {
        Navigator.of(context).pop(true);
        showMessage(context, selected.isEmpty ? 'ຍົກເລີກການກຳນົດຫ້ອງແລ້ວ' : 'ກຳນົດຫ້ອງແລ້ວ');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(bookingRoomOptionsProvider(widget.bookingId));

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ກຳນົດຫ້ອງ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${widget.roomTypeName} · ${widget.checkInLabel} – ${widget.checkOutLabel}',
              style: const TextStyle(fontSize: 13, color: C.muted),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: options.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: C.accent)),
                ),
                error: (e, _) => ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(bookingRoomOptionsProvider(widget.bookingId)),
                ),
                data: (opts) {
                  _seedIfNeeded(opts);
                  final selected = _selected!;
                  final floors = groupRoomsByFloor(opts.rooms);
                  final noRoomPicked = selected.isEmpty;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (opts.quantity > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'ເລືອກແລ້ວ ${selected.length}/${opts.quantity} ຫ້ອງ',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: C.soft,
                              ),
                            ),
                          ),
                        InkWell(
                          onTap: _pickNoRoom,
                          borderRadius: BorderRadius.circular(R.md),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: noRoomPicked ? C.accentSoft : C.bg,
                              borderRadius: BorderRadius.circular(R.md),
                              border: Border.all(color: noRoomPicked ? C.accent : C.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  noRoomPicked ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 18,
                                  color: noRoomPicked ? C.accentDark : C.muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'ບໍ່ກຳນົດຫ້ອງ · ໃຫ້ທີ່ພັກເລືອກທີຫຼັງ',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: noRoomPicked ? C.accentDark : C.soft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (opts.rooms.isEmpty)
                          const EmptyState(
                            message: 'ບໍ່ມີຫ້ອງວ່າງໃນຊ່ວງວັນທີ່ນີ້\nໄປຕັ້ງເລກຫ້ອງກ່ອນທີ່ໜ້າ "ຫ້ອງ"',
                            icon: Icons.meeting_room_outlined,
                          )
                        else
                          for (final floor in floors) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                floor.label.isEmpty ? 'ບໍ່ໄດ້ລະບຸຊັ້ນ' : 'ຊັ້ນ ${floor.label}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: C.muted,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final room in floor.rooms)
                                  _SelectableRoomTile(
                                    room: room,
                                    selected: selected.contains(room.id),
                                    onTap: () => _toggle(room.id, opts.quantity),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (_busy || _selected == null) ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('ບັນທຶກ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One free room as a tappable chip — filled accent with a check mark when
/// picked, a plain bordered surface otherwise. No status pill here unlike the
/// room-management tiles: everything in this list already passed the
/// availability check, so the only state left to show is "chosen or not."
class _SelectableRoomTile extends StatelessWidget {
  const _SelectableRoomTile({required this.room, required this.selected, required this.onTap});

  final RoomUnit room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? C.accent : C.surface,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: selected ? C.accent : C.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              room.roomNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : C.text,
              ),
            ),
            const SizedBox(height: 3),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 13,
              color: selected ? Colors.white : C.border,
            ),
          ],
        ),
      ),
    );
  }
}
