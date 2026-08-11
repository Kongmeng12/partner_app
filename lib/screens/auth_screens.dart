import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    final ok = await ref.read(authProvider.notifier).signIn(_email.text, _password.text);

    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      final error = ref.read(authProvider).error;
      if (error != null) showMessage(context, error, error: true);
    }
    // On success the router's redirect moves us on — no navigation here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.accent,
                        borderRadius: BorderRadius.circular(R.lg),
                      ),
                      child: const Text(
                        'LS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'LaoStay Partner',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ຈັດການທີ່ພັກ ແລະ ການຈອງຂອງທ່ານ',
                      style: TextStyle(color: C.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'ອີເມວ',
                        prefixIcon: Icon(Icons.alternate_email, size: 20),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'ໃສ່ອີເມວໃຫ້ຖືກຕ້ອງ' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'ລະຫັດຜ່ານ',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'ລະຫັດຜ່ານຢ່າງໜ້ອຍ 8 ຕົວອັກສອນ' : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('ເຂົ້າສູ່ລະບົບ'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : () => context.push('/register'),
                      child: const Text('ສະໝັກເປັນ Partner'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The application form. Creates the partner **and** their first property in
/// one call, which is what the admin Approvals screen expects to review.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'email',
      'password',
      'ownerName',
      'phone',
      'businessName',
      'propertyName',
      'address',
      'bankName',
      'bankAccount',
    ])
      key: TextEditingController(),
  };
  String _propertyType = 'guesthouse';

  /// The API wants ids, not names. A typed province cannot be matched to a row,
  /// which is what used to make every application fail validation.
  String _provinceId = '';
  String _districtId = '';
  bool _busy = false;

  /// The four values of the `property_type` enum. Anything else is rejected by
  /// the registration DTO — this list used to carry `hotel` and `apartment`,
  /// which the database has never had.
  static const _types = {
    'homestay': 'ໂຮມສະເຕ',
    'guesthouse': 'ເຮືອນພັກ',
    'resort': 'ຣີສອດ',
    'villa': 'ວິນລ່າ',
  };

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    // Exactly the keys RegisterPartnerDto declares. The API runs with
    // `forbidNonWhitelisted`, so one extra key rejects the whole application —
    // the bank details go in their own call once the account exists.
    final body = <String, dynamic>{
      'email': _fields['email']!.text.trim(),
      'password': _fields['password']!.text,
      'ownerName': _fields['ownerName']!.text.trim(),
      'phone': _fields['phone']!.text.trim(),
      'businessName': _fields['businessName']!.text.trim(),
      'propertyName': _fields['propertyName']!.text.trim(),
      'propertyType': _propertyType,
      'provinceId': int.parse(_provinceId),
      if (_districtId.isNotEmpty) 'districtId': int.parse(_districtId),
      'address': _fields['address']!.text.trim(),
    };

    final ok = await ref.read(authProvider.notifier).register(body);

    // Best effort, and deliberately after the account exists: a bank account
    // that fails to save is something the partner can add from their profile,
    // not a reason to lose the application they just filled in.
    if (ok && _fields['bankName']!.text.trim().isNotEmpty) {
      try {
        await ref.read(actionsProvider).addBankAccount({
          'bankName': _fields['bankName']!.text.trim(),
          'accountName': _fields['ownerName']!.text.trim(),
          'accountNumber': _fields['bankAccount']!.text.trim(),
        });
      } catch (_) {
        // Added later from the profile screen.
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      // The redirect sends an unapproved partner to /pending; drop this route
      // so Back does not return to a half-filled form.
      context.go('/pending');
    } else {
      final error = ref.read(authProvider).error;
      if (error != null) showMessage(context, error, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ສະໝັກເປັນ Partner')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionCard(
                    title: 'ບັນຊີຂອງທ່ານ',
                    child: Column(
                      children: [
                        _text('email', 'ອີເມວ',
                            keyboard: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? 'ໃສ່ອີເມວໃຫ້ຖືກຕ້ອງ' : null),
                        _text('password', 'ລະຫັດຜ່ານ',
                            obscure: true,
                            validator: (v) => (v == null || v.length < 8)
                                ? 'ຢ່າງໜ້ອຍ 8 ຕົວອັກສອນ'
                                : null),
                        _text('ownerName', 'ຊື່ເຈົ້າຂອງ', minLength: 2),
                        _text('phone', 'ເບີໂທ',
                            keyboard: TextInputType.phone, minLength: 6),
                        _text('businessName', 'ຊື່ທຸລະກິດ', minLength: 2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'ທີ່ພັກຂອງທ່ານ',
                    child: Column(
                      children: [
                        _text('propertyName', 'ຊື່ທີ່ພັກ', minLength: 2),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            value: _propertyType,
                            decoration: const InputDecoration(labelText: 'ປະເພດທີ່ພັກ'),
                            items: [
                              for (final e in _types.entries)
                                DropdownMenuItem(value: e.key, child: Text(e.value)),
                            ],
                            onChanged: (v) => setState(() => _propertyType = v ?? 'guesthouse'),
                          ),
                        ),
                        _provincePicker(),
                        _districtPicker(),
                        _text('address', 'ທີ່ຢູ່', minLength: 4, lines: 2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'ບັນຊີທະນາຄານ (ໃສ່ພາຍຫຼັງກໍໄດ້)',
                    child: Column(
                      children: [
                        _text('bankName', 'ຊື່ທະນາຄານ', required: false),
                        _text('bankAccount', 'ເລກບັນຊີ', required: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('ສົ່ງໃບສະໝັກ'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ໃບສະໝັກຈະຖືກກວດສອບໂດຍທີມງານ LaoStay ກ່ອນເປີດຮັບການຈອງ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The province list, from the public endpoint.
  ///
  /// A dropdown rather than a text box because the API takes an id: "ວຽງຈັນ"
  /// typed by hand matches no row, and the application is rejected.
  Widget _provincePicker() {
    final provinces = ref.watch(provincesProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: provinces.when(
        loading: () => const InputDecorator(
          decoration: InputDecoration(labelText: 'ແຂວງ'),
          child: Text('ກຳລັງໂຫຼດ...', style: TextStyle(color: C.muted)),
        ),
        error: (e, _) => InputDecorator(
          decoration: const InputDecoration(labelText: 'ແຂວງ'),
          child: Row(
            children: [
              const Expanded(
                child: Text('ໂຫຼດລາຍຊື່ແຂວງບໍ່ໄດ້', style: TextStyle(color: C.dangerFg)),
              ),
              TextButton(
                onPressed: () => ref.invalidate(provincesProvider),
                child: const Text('ລອງໃໝ່'),
              ),
            ],
          ),
        ),
        data: (list) => DropdownButtonFormField<String>(
          value: _provinceId.isEmpty ? null : _provinceId,
          decoration: const InputDecoration(labelText: 'ແຂວງ'),
          items: [
            for (final p in list) DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          validator: (v) => (v == null || v.isEmpty) ? 'ເລືອກແຂວງ' : null,
          onChanged: (v) => setState(() {
            _provinceId = v ?? '';
            // The old district belongs to the old province.
            _districtId = '';
          }),
        ),
      ),
    );
  }

  /// Optional, and only once a province is chosen — districts are listed per
  /// province, so there is nothing to show before then.
  Widget _districtPicker() {
    if (_provinceId.isEmpty) return const SizedBox.shrink();
    final districts = ref.watch(districtsProvider(_provinceId));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: districts.maybeWhen(
        data: (list) => DropdownButtonFormField<String>(
          value: _districtId.isEmpty ? null : _districtId,
          decoration: const InputDecoration(labelText: 'ເມືອງ (ບໍ່ບັງຄັບ)'),
          items: [
            for (final d in list) DropdownMenuItem(value: d.id, child: Text(d.name)),
          ],
          onChanged: (v) => setState(() => _districtId = v ?? ''),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _text(
    String key,
    String label, {
    bool obscure = false,
    bool required = true,
    int minLength = 0,
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _fields[key],
        obscureText: obscure,
        keyboardType: keyboard,
        maxLines: obscure ? 1 : lines,
        decoration: InputDecoration(labelText: label),
        validator: validator ??
            (v) {
              final value = v?.trim() ?? '';
              if (!required) return null;
              if (value.isEmpty) return 'ຕ້ອງໃສ່$label';
              if (value.length < minLength) return '$label ສັ້ນເກີນໄປ';
              return null;
            },
      ),
    );
  }
}

/// Shown to a signed-in partner whose application is not approved yet.
///
/// Without this screen the app would look broken: the backend answers 403 on
/// every route that needs a verified partner, so the dashboard would be a wall
/// of errors rather than an explanation.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(authProvider).partner;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: C.warnBg, shape: BoxShape.circle),
                    child: const Icon(Icons.hourglass_top_rounded, color: C.warnFg, size: 34),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'ໃບສະໝັກລໍການອະນຸມັດ',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ສະບາຍດີ ${partner?.ownerName ?? ''}\n'
                    'ທີມງານ LaoStay ກຳລັງກວດສອບໃບສະໝັກຂອງທ່ານ. '
                    'ເມື່ອຜ່ານແລ້ວ ທ່ານຈະຕັ້ງລາຄາ ແລະ ຮັບການຈອງໄດ້ທັນທີ.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: C.soft, fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).refreshPartner(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('ກວດສະຖານະອີກຄັ້ງ'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                    child: const Text('ອອກຈາກລະບົບ', style: TextStyle(color: C.muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first screen, and the one that decides where to go next.
///
/// Reading the stored session is deliberately started here rather than from the
/// notifier's `build`: work begun in `build` outlives it, and Riverpod 3
/// refuses to let such work touch `ref`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: the router redirect runs during build, and moving
    // the auth stage mid-build would be a navigation inside a navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: C.accent)),
      );
}
