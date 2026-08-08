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
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _taxId = TextEditingController();

  bool _busy = false;
  String? _loadedFor;

  @override
  void dispose() {
    _businessName.dispose();
    _phone.dispose();
    _taxId.dispose();
    super.dispose();
  }

  /// Fills the form once per partner. Re-filling on every rebuild would wipe
  /// whatever is being typed the moment a provider refreshes.
  void _seed(Partner p) {
    if (_loadedFor == p.id) return;
    _loadedFor = p.id;
    _businessName.text = p.businessName;
    _phone.text = p.phone;
    _taxId.text = p.taxId ?? '';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      await ref.read(actionsProvider).updateProfile({
        'businessName': _businessName.text.trim(),
        'contactPhone': _phone.text.trim(),
        if (_taxId.text.trim().isNotEmpty) 'taxId': _taxId.text.trim(),
      });
      if (!mounted) return;
      showMessage(context, 'ບັນທຶກແລ້ວ');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Adds a payout account.
  ///
  /// Its own dialog and its own endpoint, because the number is write-once: the
  /// server never sends it back unmasked, so it could not be edited in place
  /// without the form overwriting the real number with asterisks.
  Future<void> _addBankAccount() async {
    final bankName = TextEditingController();
    final accountName = TextEditingController();
    final accountNumber = TextEditingController();
    final key = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ເພີ່ມບັນຊີທະນາຄານ'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: bankName,
                decoration: const InputDecoration(labelText: 'ຊື່ທະນາຄານ'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'ໃສ່ຊື່ທະນາຄານ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: accountName,
                decoration: const InputDecoration(labelText: 'ຊື່ບັນຊີ'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'ໃສ່ຊື່ບັນຊີ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: accountNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ເລກບັນຊີ'),
                validator: (v) => (v == null || v.trim().length < 4) ? 'ໃສ່ເລກບັນຊີ' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ຍົກເລີກ')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('ເພີ່ມ'),
          ),
        ],
      ),
    );

    if (submitted != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(actionsProvider).addBankAccount({
        'bankName': bankName.text.trim(),
        'accountName': accountName.text.trim(),
        'accountNumber': accountNumber.text.trim(),
      });
      if (mounted) showMessage(context, 'ເພີ່ມບັນຊີແລ້ວ');
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
                        controller: _businessName,
                        decoration: const InputDecoration(labelText: 'ຊື່ທຸລະກິດ'),
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? 'ໃສ່ຊື່ທຸລະກິດ' : null,
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
                        controller: _taxId,
                        decoration: const InputDecoration(
                          labelText: 'ເລກປະຈຳຕົວຜູ້ເສຍພາສີ',
                          helperText: 'ບໍ່ບັງຄັບ',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'ບັນຊີຮັບເງິນ',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A partner may hold several accounts and one is the
                      // default the payouts go to, so this is a list rather
                      // than a pair of fields.
                      if (p.bankAccounts.isEmpty)
                        const Text(
                          'ຍັງບໍ່ໄດ້ເພີ່ມບັນຊີ — ຕ້ອງມີບັນຊີກ່ອນຈຶ່ງຮັບເງິນໂອນໄດ້',
                          style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.5),
                        )
                      else
                        for (final b in p.bankAccounts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_outlined,
                                    size: 18, color: C.soft),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.bankName,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: C.text,
                                        ),
                                      ),
                                      Text(
                                        '${b.accountName} · ${b.account}',
                                        style: const TextStyle(fontSize: 12, color: C.faint),
                                      ),
                                    ],
                                  ),
                                ),
                                if (b.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: C.accentSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'ຫຼັກ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: C.accentDark,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _addBankAccount,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('ເພີ່ມບັນຊີທະນາຄານ'),
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
