import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();

  bool _busy = false;
  String? _loadedFor;

  @override
  void dispose() {
    _ownerName.dispose();
    _phone.dispose();
    _bankName.dispose();
    _bankAccount.dispose();
    super.dispose();
  }

  /// Fills the form once per partner. Re-filling on every rebuild would wipe
  /// whatever is being typed the moment a provider refreshes.
  void _seed(Partner p) {
    if (_loadedFor == p.id) return;
    _loadedFor = p.id;
    _ownerName.text = p.ownerName;
    _phone.text = p.phone;
    _bankName.text = p.bankName ?? '';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await ref.read(actionsProvider).updateProfile({
        'ownerName': _ownerName.text.trim(),
        'phone': _phone.text.trim(),
        'bankName': _bankName.text.trim(),
        // Only sent when actually retyped: the server returns the account
        // masked (`***1234`), so echoing that back would overwrite the real
        // number with asterisks.
        if (_bankAccount.text.trim().isNotEmpty) 'bankAccount': _bankAccount.text.trim(),
      });
      if (!mounted) return;
      _bankAccount.clear();
      showMessage(context, 'ບັນທຶກແລ້ວ');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ໂປຣໄຟລ໌')),
      body: profile.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(profileProvider)),
        data: (p) {
          _seed(p);

          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SectionCard(
                  title: 'ບັນຊີ',
                  child: Column(
                    children: [
                      LabelledRow(label: 'ອີເມວ', value: p.email),
                      LabelledRow(
                        label: 'ສະຖານະ',
                        value: pillFor(partnerStatusPill, p.status).label,
                      ),
                      if (p.commissionRate != null)
                        LabelledRow(
                          label: 'ຄ່າຄອມມິຊຊັນ',
                          value: '${p.commissionRate!.toStringAsFixed(2)}%',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'ຂໍ້ມູນຕິດຕໍ່',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _ownerName,
                        decoration: const InputDecoration(labelText: 'ຊື່ເຈົ້າຂອງ'),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'ໃສ່ຊື່' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'ເບີໂທ'),
                        validator: (v) =>
                            (v == null || v.trim().length < 6) ? 'ໃສ່ເບີໂທ' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'ບັນຊີຮັບເງິນ',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _bankName,
                        decoration: const InputDecoration(labelText: 'ຊື່ທະນາຄານ'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bankAccount,
                        decoration: InputDecoration(
                          labelText: 'ເລກບັນຊີ',
                          hintText: p.bankAccount ?? 'ຍັງບໍ່ໄດ້ໃສ່',
                          helperText: 'ປ່ອຍວ່າງໄວ້ ຖ້າບໍ່ຕ້ອງການປ່ຽນ',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 15, color: C.faint),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ເລກບັນຊີເຕັມຈະບໍ່ຖືກສົ່ງກັບມາຫາແອັບ ເຫັນໄດ້ພຽງ 4 ໂຕທ້າຍ',
                              style: TextStyle(fontSize: 11.5, color: C.faint, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _save,
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
          );
        },
      ),
    );
  }
}
