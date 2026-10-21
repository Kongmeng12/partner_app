import 'dart:typed_data';

import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../providers/auth.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/form_bits.dart';
import 'location_picker_screen.dart';

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

    final ok = await ref
        .read(authProvider.notifier)
        .signIn(_email.text, _password.text);

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
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: C.bg,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Stack(
              children: [
                _LoginHeader(topInset: topInset),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, topInset + 236, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _loginCard(),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ຍັງບໍ່ມີບັນຊີ?',
                            style: TextStyle(color: C.muted, fontSize: 13.5),
                          ),
                          TextButton(
                            onPressed:
                                _busy ? null : () => context.push('/register'),
                            child: const Text(
                              'ສະໝັກເປັນ Partner',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, size: 13, color: C.faint),
                          SizedBox(width: 5),
                          Text(
                            'ເຊື່ອມຕໍ່ແບບປອດໄພ · © Phapai',
                            style: TextStyle(color: C.faint, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The white card the form sits on, lifted over the curve of the header.
  Widget _loginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A3A2A1E),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ຍິນດີຕ້ອນຮັບກັບມາ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: C.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ເຂົ້າສູ່ລະບົບເພື່ອຈັດການທີ່ພັກ ແລະ ການຈອງຂອງທ່ານ',
              style: TextStyle(color: C.muted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'ອີເມວ',
                prefixIcon: Icon(Icons.alternate_email, size: 20),
              ),
              validator:
                  (v) =>
                      (v == null || !v.contains('@'))
                          ? 'ໃສ່ອີເມວໃຫ້ຖືກຕ້ອງ'
                          : null,
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
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator:
                  (v) =>
                      (v == null || v.length < 8)
                          ? 'ລະຫັດຜ່ານຢ່າງໜ້ອຍ 8 ຕົວອັກສອນ'
                          : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    _busy ? null : () => context.push('/forgot-password'),
                child: const Text('ລືມລະຫັດຜ່ານ?'),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _busy ? null : _submit,
              child:
                  _busy
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ເຂົ້າສູ່ລະບົບ'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The orange top of the sign-in screen: the Phapai mark on a white ring,
/// the name, and a soft curve the form card overlaps.
class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _BottomCurve(),
      child: Container(
        height: topInset + 300,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6A3D), C.accent, C.accentDark],
          ),
        ),
        child: Stack(
          children: [
            // Two faint rings for depth — decoration only.
            Positioned(right: -60, top: topInset - 40, child: _ring(200)),
            Positioned(left: -50, top: topInset + 150, child: _ring(140)),
            Padding(
              padding: EdgeInsets.fromLTRB(28, topInset + 36, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 74,
                        height: 74,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Phapai Partner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ຈັດການທີ່ພັກ ແລະ ການຈອງຂອງທ່ານ ໃນທີ່ດຽວ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 22,
      ),
    ),
  );
}

class _BottomCurve extends CustomClipper<Path> {
  @override
  Path getClip(Size size) =>
      Path()
        ..lineTo(0, size.height - 56)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height + 28,
          size.width,
          size.height - 56,
        )
        ..lineTo(size.width, 0)
        ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// The application form. Creates the partner **and** their first property in
/// one call, which is what the admin Approvals screen expects to review, then
/// attaches the two verification documents.
///
/// Only what the review needs is asked here. Photos, amenities, rules, rooms,
/// prices and the bank account are filled in from the app afterwards.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();

  /// Top-to-bottom order of the form, which is also the order a failed submit
  /// searches for the first field to jump to.
  static const _order = [
    'email',
    'password',
    'confirmPassword',
    'ownerName',
    'phone',
    'businessName',
    'taxId',
    'propertyName',
    'province',
    'address',
    'mapsUrl',
    'id_card',
    'business_license',
  ];
  static const _nonText = {'province', 'id_card', 'business_license'};

  final _fields = {
    for (final key in _order)
      if (!_nonText.contains(key)) key: TextEditingController(),
  };
  final _keys = {
    for (final key in _order) key: GlobalKey<FormFieldState<dynamic>>(),
  };
  late final _focus = {
    for (final key in _fields.keys) _keys[key]!: FocusNode(),
  };
  final _termsKey = GlobalKey();

  /// Set by the first press of "submit": the terms error only shows once the
  /// applicant has tried to send, not on a fresh form.
  bool _triedSubmit = false;
  String _propertyType = 'guesthouse';

  /// `business_type`: individual · company.
  String _businessType = 'individual';

  /// Photos of the verification documents, keyed by `document_type`. Held as
  /// bytes so the same code previews and uploads them on web and mobile.
  final _docs = <String, ({Uint8List bytes, String name})>{};

  /// The API wants ids, not names. A typed province cannot be matched to a row,
  /// which is what used to make every application fail validation.
  String _provinceId = '';
  String _districtId = '';

  /// Where the property is, pinned on the map. Optional, as is the Google Maps
  /// link that can stand in for it — but one of the two is what lets the
  /// admin check the address, and guests find a stay by its pin.
  LatLng? _location;
  bool _showPassword = false;
  bool _busy = false;
  bool _acceptedTerms = false;

  /// The values of the `property_type` enum. Anything else is rejected by the
  /// registration DTO. `hotel` exists since migration 0018; `apartment` still
  /// does not.
  static const _types = {
    'hotel': 'ໂຮງແຮມ',
    'guesthouse': 'ເຮືອນພັກ (Guesthouse)',
    'homestay': 'ໂຮມສະເຕ (Homestay)',
    'villa': 'ວິນລາ',
    'resort': 'ຣີສອດ',
  };

  static const _businessTypes = {'individual': 'ບຸກຄົນ', 'company': 'ບໍລິສັດ'};

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    final fieldsOk = _form.currentState!.validate();
    if (!fieldsOk || !_acceptedTerms) {
      if (!jumpToFirstError([
        for (final k in _order) _keys[k]!,
      ], focus: _focus)) {
        final terms = _termsKey.currentContext;
        if (terms != null) {
          Scrollable.ensureVisible(
            terms,
            duration: const Duration(milliseconds: 250),
            alignment: 0.5,
          );
        }
      }
      showMessage(
        context,
        fieldsOk
            ? 'ກະລຸນາຍອມຮັບເງື່ອນໄຂກ່ອນສົ່ງໃບສະໝັກ'
            : 'ກະລຸນາແກ້ຊ່ອງທີ່ເປັນສີແດງ',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);

    final taxId = _fields['taxId']!.text.trim();
    final mapsUrl = _fields['mapsUrl']!.text.trim();
    // A full Google Maps link carries the coordinates; use them when no pin
    // was dropped. A short maps.app.goo.gl link does not, and is kept for the
    // admin to open instead.
    final pin = _location ?? _coordsFromMapsUrl(mapsUrl);

    // Exactly the keys RegisterPartnerDto declares. The API runs with
    // `forbidNonWhitelisted`, so one extra key rejects the whole application.
    final body = <String, dynamic>{
      'email': _fields['email']!.text.trim(),
      'password': _fields['password']!.text,
      'ownerName': _fields['ownerName']!.text.trim(),
      'phone': _fields['phone']!.text.trim(),
      'businessName': _fields['businessName']!.text.trim(),
      'businessType': _businessType,
      if (taxId.isNotEmpty) 'taxId': taxId,
      'propertyName': _fields['propertyName']!.text.trim(),
      'propertyType': _propertyType,
      'provinceId': int.parse(_provinceId),
      if (_districtId.isNotEmpty) 'districtId': int.parse(_districtId),
      'address': _fields['address']!.text.trim(),
      if (pin != null) 'lat': pin.latitude,
      if (pin != null) 'lng': pin.longitude,
      if (mapsUrl.isNotEmpty) 'mapsUrl': mapsUrl,
      // Required by the API, and required to be true. The server records which
      // version of each document was live when this was ticked.
      'acceptedTerms': _acceptedTerms,
    };

    final ok = await ref
        .read(authProvider.notifier)
        .register(
          body,
          documents: {
            for (final d in _docs.entries)
              d.key: MultipartFile.fromBytes(d.value.bytes, filename: d.value.name),
          },
        );

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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                    child: RequiredLegend(),
                  ),
                  SectionCard(
                    title: '1. ບັນຊີ',
                    child: Column(
                      children: [
                        _text(
                          'email',
                          'ອີເມວ',
                          keyboard: TextInputType.emailAddress,
                          hint: 'name@gmail.com',
                          helper: 'ໃຊ້ເຂົ້າສູ່ລະບົບ · ຫ້າມຊ້ຳກັບບັນຊີອື່ນ',
                          helperMuted: true,
                          validator:
                              (v) =>
                                  _need(v, 'ອີເມວ') ??
                                  (looksLikeEmail(v!)
                                      ? null
                                      : 'ອີເມວບໍ່ຖືກຕ້ອງ ເຊັ່ນ name@gmail.com'),
                        ),
                        _text(
                          'password',
                          'ລະຫັດຜ່ານ',
                          obscure: true,
                          onChanged: (_) {
                            setState(() {});
                            if (_fields['confirmPassword']!.text.isNotEmpty) {
                              _keys['confirmPassword']!.currentState
                                  ?.validate();
                            }
                          },
                          validator:
                              (v) =>
                                  _need(v, 'ລະຫັດຜ່ານ') ??
                                  (isStrongPassword(v!)
                                      ? null
                                      : 'ລະຫັດຜ່ານຍັງບໍ່ຄົບເງື່ອນໄຂຂ້າງລຸ່ມ'),
                        ),
                        PasswordChecklist(password: _fields['password']!.text),
                        _text(
                          'confirmPassword',
                          'ຢືນຢັນລະຫັດຜ່ານ',
                          obscure: true,
                          onChanged: (_) => setState(() {}),
                          helper: _passwordsMatch ? '✓ ລະຫັດຜ່ານກົງກັນ' : null,
                          validator:
                              (v) =>
                                  _need(v, 'ລະຫັດຜ່ານອີກຄັ້ງ') ??
                                  (v != _fields['password']!.text
                                      ? 'ລະຫັດຜ່ານບໍ່ກົງກັນ'
                                      : null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: '2. ເຈົ້າຂອງ ແລະ ທຸລະກິດ',
                    child: Column(
                      children: [
                        _text(
                          'ownerName',
                          'ຊື່ ແລະ ນາມສະກຸນ ເຈົ້າຂອງ',
                          validator:
                              (v) =>
                                  _need(v, 'ຊື່ ແລະ ນາມສະກຸນ') ??
                                  (v!.trim().length < 2
                                      ? 'ຊື່ຕ້ອງມີຢ່າງໜ້ອຍ 2 ຕົວອັກສອນ'
                                      : null),
                        ),
                        _text(
                          'phone',
                          'ເບີໂທ',
                          keyboard: TextInputType.phone,
                          hint: '020 5555 0001',
                          formatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-\s]'),
                            ),
                          ],
                          validator:
                              (v) =>
                                  _need(v, 'ເບີໂທ') ??
                                  (looksLikePhone(v!)
                                      ? null
                                      : 'ເບີໂທບໍ່ຖືກຕ້ອງ ເຊັ່ນ 020 5555 0001'),
                        ),
                        _text(
                          'businessName',
                          'ຊື່ທຸລະກິດ',
                          validator:
                              (v) =>
                                  _need(v, 'ຊື່ທຸລະກິດ') ??
                                  (v!.trim().length < 2
                                      ? 'ຊື່ທຸລະກິດຕ້ອງມີຢ່າງໜ້ອຍ 2 ຕົວອັກສອນ'
                                      : null),
                        ),
                        _businessTypePicker(),
                        _text(
                          'taxId',
                          'ເລກປະຈຳຕົວຜູ້ເສຍອາກອນ (ຖ້າມີ)',
                          required: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: '3. ທີ່ພັກ',
                    child: Column(
                      children: [
                        _text(
                          'propertyName',
                          'ຊື່ທີ່ພັກ',
                          validator:
                              (v) =>
                                  _need(v, 'ຊື່ທີ່ພັກ') ??
                                  (v!.trim().length < 2
                                      ? 'ຊື່ທີ່ພັກຕ້ອງມີຢ່າງໜ້ອຍ 2 ຕົວອັກສອນ'
                                      : null),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DropdownButtonFormField<String>(
                            value: _propertyType,
                            decoration: InputDecoration(
                              label: fieldLabel('ປະເພດທີ່ພັກ', required: true),
                            ),
                            items: [
                              for (final e in _types.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                            ],
                            onChanged:
                                (v) => setState(
                                  () => _propertyType = v ?? 'guesthouse',
                                ),
                          ),
                        ),
                        _provincePicker(),
                        _districtPicker(),
                        _text(
                          'address',
                          'ທີ່ຢູ່ລະອຽດ',
                          lines: 2,
                          hint: 'ບ້ານ, ຖະໜົນ, ຈຸດສັງເກດໃກ້ຄຽງ',
                          validator:
                              (v) =>
                                  _need(v, 'ທີ່ຢູ່ລະອຽດ') ??
                                  (v!.trim().length < 4
                                      ? 'ທີ່ຢູ່ຕ້ອງມີຢ່າງໜ້ອຍ 4 ຕົວອັກສອນ'
                                      : null),
                        ),
                        _locationField(),
                        _text(
                          'mapsUrl',
                          'ຫຼື ວາງລິ້ງ Google Maps',
                          required: false,
                          keyboard: TextInputType.url,
                          hint: 'https://maps.app.goo.gl/…',
                          validator:
                              (v) =>
                                  (v ?? '').trim().isEmpty ||
                                          _googleMapsUrl.hasMatch(v!.trim())
                                      ? null
                                      : 'ລິ້ງບໍ່ແມ່ນ Google Maps · ກົດ "ແບ່ງປັນ" ໃນ Google Maps ແລ້ວສຳເນົາລິ້ງ',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: '4. ເອກະສານຢັ້ງຢືນ',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(2, 0, 2, 10),
                          child: Text(
                            'ຖ່າຍຮູບ ຫຼື ສະແກນ ໃຫ້ເຫັນຂໍ້ຄວາມຊັດເຈນ',
                            style: TextStyle(color: C.muted, fontSize: 12.5),
                          ),
                        ),
                        for (final type in _docLabels.keys) _documentField(type),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _AfterSignUpNote(),
                  const SizedBox(height: 14),
                  // An explicit tick. The API refuses the application without
                  // it, so the button stays disabled rather than letting the
                  // partner fill in the whole form and be rejected at the end.
                  CheckboxListTile(
                    key: _termsKey,
                    value: _acceptedTerms,
                    onChanged:
                        (v) => setState(() => _acceptedTerms = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    isError: _triedSubmit && !_acceptedTerms,
                    title: const Text.rich(
                      TextSpan(
                        text:
                            '5. ຂ້າພະເຈົ້າຍອມຮັບເງື່ອນໄຂການໃຊ້ບໍລິການ, '
                            'ນະໂຍບາຍຄວາມເປັນສ່ວນຕົວ ແລະ ສັນຍາ Partner',
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: C.dangerFg),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                    subtitle:
                        _triedSubmit && !_acceptedTerms
                            ? const Text(
                              'ຕ້ອງຍອມຮັບເງື່ອນໄຂກ່ອນສົ່ງໃບສະໝັກ',
                              style: TextStyle(fontSize: 12, color: C.dangerFg),
                            )
                            : null,
                  ),
                  const SizedBox(height: 6),
                  // Always pressable: a greyed-out button does not say what
                  // is missing, while a press jumps to the first problem.
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child:
                        _busy
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('ສົ່ງໃບສະໝັກ'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ໃບສະໝັກຈະຖືກກວດສອບໂດຍທີມງານ Phapai ກ່ອນເປີດຮັບການຈອງ',
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
        loading:
            () => const InputDecorator(
              decoration: InputDecoration(labelText: 'ແຂວງ'),
              child: Text('ກຳລັງໂຫຼດ...', style: TextStyle(color: C.muted)),
            ),
        error:
            (e, _) => InputDecorator(
              decoration: const InputDecoration(labelText: 'ແຂວງ'),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ໂຫຼດລາຍຊື່ແຂວງບໍ່ໄດ້',
                      style: TextStyle(color: C.dangerFg),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(provincesProvider),
                    child: const Text('ລອງໃໝ່'),
                  ),
                ],
              ),
            ),
        data:
            (list) => DropdownButtonFormField<String>(
              key: _keys['province'],
              value: _provinceId.isEmpty ? null : _provinceId,
              decoration: InputDecoration(
                label: fieldLabel('ແຂວງ', required: true),
              ),
              items: [
                for (final p in list)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              validator:
                  (v) => (v == null || v.isEmpty) ? 'ກະລຸນາເລືອກແຂວງ' : null,
              onChanged:
                  (v) => setState(() {
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
        data:
            (list) => DropdownButtonFormField<String>(
              value: _districtId.isEmpty ? null : _districtId,
              decoration: const InputDecoration(labelText: 'ເມືອງ'),
              items: [
                for (final d in list)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => setState(() => _districtId = v ?? ''),
            ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  /// Individual or company — two choices, so both stay in view.
  Widget _businessTypePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'ປະເພດທຸລະກິດ',
          contentPadding: EdgeInsets.fromLTRB(10, 14, 10, 10),
        ),
        child: SegmentedButton<String>(
          segments: [
            for (final e in _businessTypes.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {_businessType},
          showSelectedIcon: false,
          onSelectionChanged:
              (s) => setState(() => _businessType = s.first),
        ),
      ),
    );
  }

  /// The pin. Optional: a Google Maps link below can stand in for it. The
  /// preview is non-interactive: a draggable map inside a scrolling form would
  /// steal the page's scroll.
  Widget _locationField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormField<LatLng>(
        builder: (field) {
          Future<void> pick() async {
            final picked = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(
                builder: (_) => LocationPickerScreen(initial: _location),
              ),
            );
            if (picked == null || !mounted) return;
            setState(() => _location = picked);
            field.didChange(picked);
          }

          final location = _location;
          return InputDecorator(
            decoration: const InputDecoration(
              labelText: 'ປັກໝຸດທີ່ຕັ້ງໃນແຜນທີ່',
              contentPadding: EdgeInsets.all(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (location != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(R.md),
                    child: SizedBox(
                      height: 150,
                      child: IgnorePointer(
                        child: FlutterMap(
                          // Keyed on the point: MapOptions are only read once,
                          // so a new pin needs a new map to re-centre.
                          key: ValueKey(location),
                          options: MapOptions(
                            initialCenter: location,
                            initialZoom: 15,
                          ),
                          children: [
                            mapTiles(),
                            MarkerLayer(markers: [pinMarker(location)]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: C.soft, fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: pick,
                  icon: Icon(
                    location == null
                        ? Icons.add_location_alt_outlined
                        : Icons.edit_location_alt_outlined,
                    size: 18,
                  ),
                  label: Text(
                    location == null ? 'ເລືອກໃນແຜນທີ່' : 'ປ່ຽນທີ່ຕັ້ງ',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _docLabels = {
    'id_card': (
      'ບັດປະຈຳຕົວ ຫຼື ໜັງສືຜ່ານແດນ ຂອງເຈົ້າຂອງ',
      Icons.badge_outlined,
    ),
    'business_license': (
      'ໃບທະບຽນວິສາຫະກິດ ຫຼື ໃບອະນຸຍາດດຳເນີນທຸລະກິດ',
      Icons.description_outlined,
    ),
  };

  /// One required document: a thumbnail once attached, and a button to take
  /// or choose the photo. A form field so a missing one fails like any other.
  Widget _documentField(String type) {
    final (label, icon) = _docLabels[type]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormField<void>(
        key: _keys[type],
        validator: (_) => _docs[type] == null ? 'ກະລຸນາແນບເອກະສານນີ້' : null,
        builder: (field) {
          final doc = _docs[type];
          return InputDecorator(
            decoration: InputDecoration(
              errorText: field.errorText,
              contentPadding: const EdgeInsets.all(10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.sm),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child:
                        doc == null
                            ? ColoredBox(
                              color: C.neutralBg,
                              child: Icon(icon, color: C.muted),
                            )
                            : Image.memory(doc.bytes, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      fieldLabel(label, required: true),
                      const SizedBox(height: 2),
                      Text(
                        doc == null ? 'ຍັງບໍ່ໄດ້ແນບ' : '✓ ແນບແລ້ວ',
                        style: TextStyle(
                          fontSize: 12,
                          color: doc == null ? C.muted : C.successFg,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _pickDocument(type, field),
                  child: Text(doc == null ? 'ແນບ' : 'ປ່ຽນ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDocument(String type, FormFieldState<void> field) async {
    final picked = await _pickDocumentPhoto(context);
    if (picked == null || !mounted) return;
    setState(() => _docs[type] = picked);
    field.didChange(null);
  }

  /// "ກະລຸນາໃສ່…" for an empty required field, or null.
  String? _need(String? v, String what) =>
      (v ?? '').trim().isEmpty ? 'ກະລຸນາໃສ່$what' : null;

  bool get _passwordsMatch {
    final confirm = _fields['confirmPassword']!.text;
    return confirm.isNotEmpty && confirm == _fields['password']!.text;
  }

  Widget _text(
    String key,
    String label, {
    bool obscure = false,
    bool required = true,
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
    String? helper,
    bool helperMuted = false,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: _keys[key],
        controller: _fields[key],
        focusNode: _focus[_keys[key]],
        obscureText: obscure && !_showPassword,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        inputFormatters: formatters,
        onChanged: onChanged,
        // Checked when the applicant leaves the field, not on every key —
        // red text while someone is still typing their email is just noise.
        autovalidateMode: AutovalidateMode.onUnfocus,
        maxLines: obscure ? 1 : lines,
        decoration: InputDecoration(
          label: fieldLabel(label, required: required),
          hintText: hint,
          helperText: helper,
          helperStyle: TextStyle(color: helperMuted ? C.muted : C.successFg),
          errorMaxLines: 2,
          // The same eye as the login screen, shared by both password
          // fields so the pair can be compared at a glance.
          suffixIcon:
              obscure
                  ? IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed:
                        () => setState(() => _showPassword = !_showPassword),
                  )
                  : null,
        ),
        validator: validator ?? (v) => required ? _need(v, label) : null,
      ),
    );
  }
}

/// Same hosts as GOOGLE_MAPS_URL in the backend's `auth.dto.ts`.
final _googleMapsUrl = RegExp(
  r'^https://(maps\.app\.goo\.gl/|goo\.gl/maps/|(www\.)?google\.[a-z.]{2,6}/maps|maps\.google\.[a-z.]{2,6}/)\S*$',
  caseSensitive: false,
);

/// The coordinates inside a full Google Maps link — `@lat,lng`, `?q=lat,lng`
/// or the `!3dlat!4dlng` of a place — or null. Short `maps.app.goo.gl` links
/// carry none; resolving them would mean following a redirect from the app.
LatLng? _coordsFromMapsUrl(String url) {
  if (url.isEmpty) return null;
  String text;
  try {
    text = Uri.decodeFull(url);
  } catch (_) {
    // A stray `%` in a pasted link; read it as it is.
    text = url;
  }
  final m =
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)').firstMatch(text) ??
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(text) ??
      RegExp(r'[?&](?:q|ll|query)=(-?\d+\.\d+),\s*(-?\d+\.\d+)').firstMatch(text);
  if (m == null) return null;
  final lat = double.parse(m.group(1)!);
  final lng = double.parse(m.group(2)!);
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return LatLng(lat, lng);
}

/// Takes or chooses a photo of a verification document. On the web there is
/// no camera choice to make — the browser's file picker offers both.
Future<({Uint8List bytes, String name})?> _pickDocumentPhoto(
  BuildContext context,
) async {
  final source =
      kIsWeb
          ? ImageSource.gallery
          : await showModalBottomSheet<ImageSource>(
            context: context,
            builder:
                (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('ຖ່າຍຮູບ'),
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('ເລືອກຈາກຄັງຮູບ'),
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
          );
  if (source == null) return null;

  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      // Big enough to read a card number; the server re-encodes anyway.
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 88,
    );
    if (picked == null) return null;
    return (bytes: await picked.readAsBytes(), name: picked.name);
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'ເປີດກ້ອງ ຫຼື ຄັງຮູບບໍ່ໄດ້', error: true);
    }
    return null;
  }
}

/// What is left for after approval, and the one item that holds up money.
class _AfterSignUpNote extends StatelessWidget {
  const _AfterSignUpNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.infoBg,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ຕື່ມພາຍຫຼັງໃນແອັບ Partner',
            style: TextStyle(
              color: C.infoFg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'ຮູບ, ຄຳອະທິບາຍ, ສິ່ງອຳນວຍຄວາມສະດວກ, ກົດລະບຽບ, ເວລາເຊັກອິນ ແລະ '
            'ເຊັກເອົ້າ, ນະໂຍບາຍຍົກເລີກ, ປະເພດຫ້ອງ, ລາຄາ ແລະ ບັນຊີທະນາຄານ.',
            style: TextStyle(color: C.soft, fontSize: 12.5, height: 1.5),
          ),
          SizedBox(height: 8),
          Text(
            'ເງິນຈະໂອນໃຫ້ທ່ານໄດ້ກໍ່ຕໍ່ເມື່ອມີບັນຊີທະນາຄານແລ້ວ — '
            'ກະລຸນາໃສ່ບັນຊີກ່ອນຮອບຈ່າຍເງິນຮອບທຳອິດ.',
            style: TextStyle(
              color: C.warnFg,
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// On the "under review" screen: any required document the application is
/// still missing — an upload that failed at sign-up, or an account made by an
/// older app build — with a button to send it now.
class _MissingDocuments extends ConsumerStatefulWidget {
  const _MissingDocuments({required this.missing});

  final List<String> missing;

  @override
  ConsumerState<_MissingDocuments> createState() => _MissingDocumentsState();
}

class _MissingDocumentsState extends ConsumerState<_MissingDocuments> {
  String? _uploading;

  static const _labels = {
    'id_card': 'ບັດປະຈຳຕົວ ຫຼື ໜັງສືຜ່ານແດນ',
    'business_license': 'ໃບທະບຽນວິສາຫະກິດ ຫຼື ໃບອະນຸຍາດ',
  };

  Future<void> _upload(String type) async {
    final picked = await _pickDocumentPhoto(context);
    if (picked == null || !mounted) return;
    setState(() => _uploading = type);
    try {
      await ref
          .read(authProvider.notifier)
          .uploadDocument(
            type,
            MultipartFile.fromBytes(picked.bytes, filename: picked.name),
          );
      if (mounted) showMessage(context, 'ສົ່ງເອກະສານແລ້ວ');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.warnBg,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ຍັງຂາດເອກະສານ — ທີມງານຈະກວດໃບສະໝັກໄດ້ເມື່ອໄດ້ຮັບຄົບ',
            style: TextStyle(
              color: C.warnFg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          for (final type in widget.missing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _labels[type] ?? type,
                      style: const TextStyle(fontSize: 13, color: C.text),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploading != null ? null : () => _upload(type),
                    icon:
                        _uploading == type
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('ແນບ'),
                  ),
                ],
              ),
            ),
        ],
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
                    decoration: const BoxDecoration(
                      color: C.warnBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: C.warnFg,
                      size: 34,
                    ),
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
                    'ທີມງານ Phapai ກຳລັງກວດສອບໃບສະໝັກຂອງທ່ານ. '
                    'ເມື່ອຜ່ານແລ້ວ ທ່ານຈະຕັ້ງລາຄາ ແລະ ຮັບການຈອງໄດ້ທັນທີ.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: C.soft,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  if (partner != null &&
                      partner.missingDocuments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _MissingDocuments(missing: partner.missingDocuments),
                  ],
                  const SizedBox(height: 20),
                  const _AfterSignUpNote(),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed:
                        () => ref.read(authProvider.notifier).refreshPartner(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('ກວດສະຖານະອີກຄັ້ງ'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                    child: const Text(
                      'ອອກຈາກລະບົບ',
                      style: TextStyle(color: C.muted),
                    ),
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
