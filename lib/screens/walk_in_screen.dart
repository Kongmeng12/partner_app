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

/// Records a guest who booked at the desk.
///
/// Deliberately has no promo field and shows no service fee: the backend prices
/// a walk-in with `fee = 0` and ignores promo codes, because the guest paid the
/// room rate in person. Offering either here would promise something the API
/// will not honour.
class WalkInScreen extends ConsumerStatefulWidget {
  const WalkInScreen({super.key});

  @override
  ConsumerState<WalkInScreen> createState() => _WalkInScreenState();
}

class _WalkInScreenState extends ConsumerState<WalkInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  String? _roomId;
  DateTime _checkIn = todayUtc();
  DateTime _checkOut = addDays(todayUtc(), 1);
  int _guests = 1;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final initial = isCheckIn ? _checkIn : _checkOut;
    final firstAllowed = isCheckIn ? addDays(todayUtc(), -30) : addDays(_checkIn, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstAllowed) ? firstAllowed : initial,
      firstDate: firstAllowed,
      lastDate: addDays(todayUtc(), 365),
    );
    if (picked == null) return;

    // The picker hands back local midnight; every date the API sees must be a
    // calendar day in UTC or it lands a day out.
    final day = DateTime.utc(picked.year, picked.month, picked.day);
    setState(() {
      if (isCheckIn) {
        _checkIn = day;
        if (!_checkOut.isAfter(_checkIn)) _checkOut = addDays(_checkIn, 1);
      } else {
        _checkOut = day;
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_roomId == null) {
      showMessage(context, 'ເລືອກຫ້ອງກ່ອນ', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final booking = await ref.read(actionsProvider).createWalkIn(
            roomId: _roomId!,
            checkIn: _checkIn,
            checkOut: _checkOut,
            guests: _guests,
            guestName: _name.text.trim(),
            guestPhone: _phone.text.trim(),
            guestEmail: _email.text.trim(),
          );

      if (!mounted) return;
      showMessage(context, 'ບັນທຶກແລ້ວ · ${strOf(booking['code'])}');
      context.go('/bookings/${strOf(booking['id'])}');
    } on ApiException catch (e) {
      // A 409 here means the room is already full on one of those nights —
      // the message names the dates.
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(allRoomsProvider);
    final nights = _checkOut.difference(_checkIn).inDays;

    return Scaffold(
      appBar: AppBar(title: const Text('ບັນທຶກ Walk-in')),
      body: rooms.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(propertiesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              message: 'ຍັງບໍ່ມີຫ້ອງທີ່ເປີດຂາຍ\nເພີ່ມຫ້ອງກ່ອນຈຶ່ງບັນທຶກ Walk-in ໄດ້',
              icon: Icons.meeting_room_outlined,
            );
          }

          final selected = list.where((e) => e.room.id == _roomId).firstOrNull;

          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SectionCard(
                  title: 'ຫ້ອງ ແລະ ວັນທີ',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _roomId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'ຫ້ອງ'),
                        hint: const Text('ເລືອກຫ້ອງ'),
                        items: [
                          for (final e in list)
                            DropdownMenuItem(
                              value: e.room.id,
                              child: Text(
                                '${e.room.label} · ${kip(e.room.basePrice)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _roomId = v;
                          final room = list.where((e) => e.room.id == v).firstOrNull?.room;
                          if (room != null && _guests > room.capacity) _guests = room.capacity;
                        }),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'ເຂົ້າພັກ',
                              value: laoDate(_checkIn.toIso8601String()),
                              onTap: () => _pickDate(isCheckIn: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateField(
                              label: 'ອອກ',
                              value: laoDate(_checkOut.toIso8601String()),
                              onTap: () => _pickDate(isCheckIn: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$nights ຄືນ',
                          style: const TextStyle(fontSize: 12.5, color: C.muted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('ຜູ້ເຂົ້າພັກ', style: TextStyle(fontSize: 13.5, color: C.soft)),
                          const Spacer(),
                          IconButton(
                            onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$_guests',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            onPressed: selected == null || _guests < selected.room.capacity
                                ? () => setState(() => _guests++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      if (selected != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ຫ້ອງນີ້ຮັບໄດ້ສູງສຸດ ${selected.room.capacity} ຄົນ',
                            style: const TextStyle(fontSize: 12, color: C.faint),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'ຂໍ້ມູນແຂກ',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'ຊື່ແຂກ'),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'ໃສ່ຊື່ແຂກ' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'ເບີໂທ'),
                        validator: (v) =>
                            (v == null || v.trim().length < 6) ? 'ໃສ່ເບີໂທ' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'ອີເມວ (ບໍ່ບັງຄັບ)',
                          helperText: 'ໃສ່ໄວ້ ແຂກຈະເຫັນປະຫວັດການພັກໃນແອັບໄດ້',
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return null;
                          return value.contains('@') ? null : 'ອີເມວບໍ່ຖືກຕ້ອງ';
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.infoBg,
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: C.infoFg),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Walk-in ຄິດຄ່າຄອມມິຊຊັນຕ່ຳກວ່າ ແລະ ບໍ່ເກັບຄ່າບໍລິການຈາກແຂກ',
                          style: TextStyle(fontSize: 12.5, color: C.infoFg, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('ບັນທຶກການເຂົ້າພັກ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
