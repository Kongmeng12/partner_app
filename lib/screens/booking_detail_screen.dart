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

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.code ?? 'ລາຍລະອຽດການຈອງ'),
        actions: [
          IconButton(
            tooltip: 'ແຊັດກັບແຂກ',
            onPressed: () => context.go('/bookings/${widget.bookingId}/chat'),
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
                  if (b.guestTier != null) LabelledRow(label: 'ລະດັບ', value: b.guestTier!),
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
                    value: b.roomNo?.isNotEmpty == true ? '${b.roomName} · ${b.roomNo}' : b.roomName,
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
                  if (b.fee > 0) MoneyRow(label: 'ຄ່າບໍລິການ', amount: b.fee),
                  if (b.discount > 0)
                    MoneyRow(
                      label: 'ສ່ວນຫຼຸດ${b.promo != null ? ' (${strOf(b.promo!['code'])})' : ''}',
                      amount: b.discount,
                      negative: true,
                    ),
                  const Divider(height: 20),
                  MoneyRow(label: 'ລວມທັງໝົດ', amount: b.total, strong: true),
                  if (b.paidAmount > 0) ...[
                    const SizedBox(height: 4),
                    MoneyRow(label: 'ຈ່າຍແລ້ວ', amount: b.paidAmount),
                  ],
                ],
              ),
            ),

            if (b.cancellations.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'ການຍົກເລີກ',
                child: Column(
                  children: [
                    for (final c in b.cancellations) ...[
                      LabelledRow(label: 'ເຫດຜົນ', value: strOf(c['reason'], '—')),
                      MoneyRow(label: 'ຄ່າທຳນຽມ', amount: intOf(c['fee'])),
                      MoneyRow(label: 'ຄືນເງິນ', amount: intOf(c['refund_amount'])),
                    ],
                  ],
                ),
              ),
            ],

            if (b.reviews.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'ຮີວິວຈາກແຂກ',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in b.reviews) ...[
                      Text(
                        '★' * intOf(r['stars']),
                        style: const TextStyle(color: C.accent, fontSize: 16),
                      ),
                      if (strOf(r['text']).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          strOf(r['text']),
                          style: const TextStyle(fontSize: 13.5, color: C.soft, height: 1.5),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Only the moves the backend actually allows are offered. It answers
            // 400 for anything else, so a button for it would be a lie.
            if (b.nextStatus != null)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => ref
                              .read(actionsProvider)
                              .setBookingStatus(widget.bookingId, b.nextStatus!),
                          'ອັບເດດສະຖານະແລ້ວ',
                        ),
                icon: const Icon(Icons.check_circle_outline, size: 19),
                label: Text(b.nextStatusLabel!),
              ),

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
