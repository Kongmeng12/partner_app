import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/special_request_card.dart';

/// What the front desk sees after scanning a guest's check-in QR: is this
/// booking ours, paid, and due today — then who the guest is, which room,
/// and anything they asked for.
///
/// Checking in takes two deliberate taps after the scan: staff confirm they
/// have matched the guest's ID to the name, then confirm the check-in. A QR
/// proves which booking it is, not who is holding the phone.
class CheckInVerifyScreen extends ConsumerStatefulWidget {
  const CheckInVerifyScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<CheckInVerifyScreen> createState() => _CheckInVerifyScreenState();
}

class _CheckInVerifyScreenState extends ConsumerState<CheckInVerifyScreen> {
  bool _idChecked = false;
  bool _busy = false;

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(actionsProvider).setBookingStatus(widget.bookingId, 'staying');
      if (!mounted) return;
      showMessage(context, 'ເຊັກອິນແລ້ວ — ຍິນດີຕ້ອນຮັບແຂກ');
      context.pushReplacement('/bookings/${widget.bookingId}');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Why this booking cannot be checked in right now, in the desk's words —
  /// null when it can. Mirrors what the API allows (`nextStatus`), so the
  /// screen never offers a check-in the server would refuse.
  String? _problem(BookingDetail b) {
    if (b.canCheckIn) return null;
    switch (b.status) {
      case 'staying':
        return 'ແຂກຄົນນີ້ເຊັກອິນໄປແລ້ວ';
      case 'cancelled':
        return 'ການຈອງນີ້ຖືກຍົກເລີກແລ້ວ — ຢ່າໃຫ້ເຂົ້າພັກ';
      case 'completed':
      case 'no_show':
        return 'ການເຂົ້າພັກນີ້ສິ້ນສຸດແລ້ວ';
      case 'pending':
        return 'ການຈອງນີ້ຍັງບໍ່ໄດ້ຈ່າຍເງິນ';
    }
    final checkIn = parseDay(b.checkIn);
    if (checkIn != null && todayUtc().isBefore(checkIn)) {
      return 'ຍັງບໍ່ຮອດມື້ເຂົ້າພັກ — ເຊັກອິນໄດ້ຕັ້ງແຕ່ ${laoDate(b.checkIn)}';
    }
    return 'ເກີນມື້ອອກແລ້ວ — ເຊັກອິນບໍ່ໄດ້';
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(title: Text(detail.value?.code ?? 'ກວດສອບການຈອງ')),
      body: detail.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (b) {
          final problem = _problem(b);
          final paid = !b.awaitingPayment && b.status != 'cancelled';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SectionCard(
                title: 'ກວດສອບ',
                child: Column(
                  children: [
                    _Check(ok: true, text: 'ການຈອງຂອງ ${b.propertyName}'),
                    _Check(
                      ok: paid,
                      text: paid
                          ? (b.paidAmount > 0 ? 'ຈ່າຍແລ້ວ ${kip(b.paidAmount)}' : 'ຈ່າຍທີ່ທີ່ພັກ')
                          : (b.status == 'cancelled' ? 'ຍົກເລີກແລ້ວ' : 'ຍັງບໍ່ໄດ້ຈ່າຍເງິນ'),
                    ),
                    _Check(
                      ok: problem == null,
                      text: problem ??
                          'ເຂົ້າພັກມື້ນີ້ · ${laoDateRange(b.checkIn, b.checkOut)} · ${b.nights} ຄືນ',
                    ),
                  ],
                ),
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
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(b.guestPhone, style: const TextStyle(fontSize: 13, color: C.soft)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LabelledRow(label: 'ຜູ້ເຂົ້າພັກ', value: '${b.guests} ຄົນ'),
                    LabelledRow(
                      label: 'ຫ້ອງ',
                      value: b.roomQuantity > 1 ? '${b.roomTypeName} × ${b.roomQuantity}' : b.roomTypeName,
                    ),
                    LabelledRow(
                      label: 'ເລກຫ້ອງ',
                      value: b.roomNumbers.isEmpty ? 'ຍັງບໍ່ໄດ້ກຳນົດ' : b.roomNumbers.join(', '),
                      strong: b.roomNumbers.isNotEmpty,
                    ),
                    if (b.roomNumbers.isEmpty && b.canAssignRoom)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          // The room picker lives on the booking itself.
                          onPressed: () => context.push('/bookings/${b.id}'),
                          icon: const Icon(Icons.add_circle_outline, size: 17),
                          label: const Text('ກຳນົດຫ້ອງ'),
                        ),
                      ),
                  ],
                ),
              ),
              if (b.specialRequest != null) ...[
                const SizedBox(height: 14),
                SpecialRequestCard(text: b.specialRequest!),
              ],
              const SizedBox(height: 20),
              if (problem == null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(R.md),
                    border: Border.all(color: _idChecked ? C.accent : C.border),
                  ),
                  child: CheckboxListTile(
                    value: _idChecked,
                    onChanged: _busy ? null : (v) => setState(() => _idChecked = v ?? false),
                    activeColor: C.accent,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'ກວດບັດປະຈຳຕົວ ຫຼື ພາສປອດ ແລ້ວ ຊື່ກົງກັບການຈອງ',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (_idChecked && !_busy) ? _checkIn : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login_rounded, size: 19),
                  label: const Text('ຢືນຢັນເຊັກອິນ'),
                ),
              ] else
                OutlinedButton(
                  onPressed: () => context.pushReplacement('/bookings/${b.id}'),
                  child: const Text('ເປີດລາຍລະອຽດການຈອງ'),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One line of the verdict: a green tick or a red cross, and why.
class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 20,
            color: ok ? C.successFg : C.dangerFg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: ok ? C.text : C.dangerFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
