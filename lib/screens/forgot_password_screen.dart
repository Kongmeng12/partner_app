import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../providers/auth.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/form_bits.dart';

/// Forgot password, the same flow as the customer app: a 6-digit code by email
/// or SMS, then a new password.
///
/// One screen with three steps rather than three routes. The email/phone and
/// the reset token only live as long as this screen, and Back steps back
/// through the flow instead of leaving it.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { request, verify, reset }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _target = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.request;
  String? _resetToken;
  bool _busy = false;
  bool _showPassword = false;

  /// Seconds until another code may be asked for. The API refuses a second
  /// request within a minute, so the button waits rather than failing.
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [_target, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn--);
    });
  }

  /// Runs one API step with the button spinning and any error shown.
  Future<void> _run(Future<void> Function() action) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
        await _api.requestPasswordResetCode(_target.text.trim());
        if (!mounted) return;
        _code.clear();
        setState(() => _step = _Step.verify);
        _startResendCountdown();
      });

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await _api.requestPasswordResetCode(_target.text.trim());
      if (!mounted) return;
      showMessage(context, 'ສົ່ງລະຫັດອີກຄັ້ງແລ້ວ');
      _startResendCountdown();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() => _run(() async {
        final token = await _api.verifyPasswordResetCode(_target.text.trim(), _code.text.trim());
        if (!mounted) return;
        if (token == null) {
          // The code matched but no account uses this email/phone. The API
          // words it no more specifically than that, and neither does this.
          showMessage(context, 'ຢືນຢັນລະຫັດບໍ່ສຳເລັດ ກວດອີເມວ ຫຼື ເບີໂທອີກຄັ້ງ', error: true);
          return;
        }
        setState(() {
          _resetToken = token;
          _step = _Step.reset;
        });
      });

  Future<void> _savePassword() => _run(() async {
        await _api.resetPassword(_resetToken!, _password.text);
        if (!mounted) return;
        showMessage(context, 'ປ່ຽນລະຫັດຜ່ານສຳເລັດແລ້ວ · ເຂົ້າສູ່ລະບົບດ້ວຍລະຫັດຜ່ານໃໝ່');
        context.go('/login');
      });

  void _back() {
    switch (_step) {
      case _Step.request:
        context.go('/login');
      case _Step.verify:
        setState(() => _step = _Step.request);
      case _Step.reset:
        // The token is spent-once and short-lived; going back means starting
        // over with a fresh code rather than reusing it.
        setState(() {
          _resetToken = null;
          _step = _Step.request;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _Step.request => ('ລືມລະຫັດຜ່ານ', 'ໃສ່ອີເມວ ຫຼື ເບີໂທລະສັບທີ່ຜູກກັບບັນຊີຂອງທ່ານ'),
      _Step.verify => ('ໃສ່ລະຫັດ', 'ພວກເຮົາໄດ້ສົ່ງລະຫັດ 6 ຕົວເລກໄປທີ່ ${_target.text.trim()}'),
      _Step.reset => ('ຕັ້ງລະຫັດຜ່ານໃໝ່', 'ເລືອກລະຫັດຜ່ານໃໝ່ສຳລັບບັນຊີຂອງທ່ານ'),
    };

    return PopScope(
      canPop: _step == _Step.request,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepBar(current: _step.index),
                      const SizedBox(height: 22),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 26),
                      ...switch (_step) {
                        _Step.request => _requestStep(),
                        _Step.verify => _verifyStep(),
                        _Step.reset => _resetStep(),
                      },
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _requestStep() => [
        TextFormField(
          controller: _target,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ອີເມວ ຫຼື ເບີໂທ',
            hintText: 'you@example.com · 020 5555 0001',
            prefixIcon: Icon(Icons.alternate_email, size: 20),
          ),
          onFieldSubmitted: (_) => _sendCode(),
          validator: (v) =>
              _isEmailOrPhone(v ?? '') ? null : 'ໃສ່ອີເມວ ຫຼື ເບີໂທທີ່ຖືກຕ້ອງ',
        ),
        const SizedBox(height: 22),
        _SubmitButton(label: 'ສົ່ງລະຫັດ', busy: _busy, onPressed: _sendCode),
      ];

  List<Widget> _verifyStep() => [
        TextFormField(
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 10),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          onFieldSubmitted: (_) => _verify(),
          validator: (v) => (v ?? '').length == 6 ? null : 'ໃສ່ລະຫັດ 6 ຕົວເລກ',
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton(
              onPressed: _busy ? null : () => setState(() => _step = _Step.request),
              child: const Text('ປ່ຽນອີເມວ / ເບີໂທ', style: TextStyle(color: C.muted)),
            ),
            const Spacer(),
            TextButton(
              onPressed: (_busy || _resendIn > 0) ? null : _resend,
              child: Text(_resendIn > 0 ? 'ສົ່ງລະຫັດໃໝ່ ($_resendIn)' : 'ສົ່ງລະຫັດໃໝ່'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SubmitButton(label: 'ຢືນຢັນ', busy: _busy, onPressed: _verify),
      ];

  List<Widget> _resetStep() {
    final eye = IconButton(
      icon: Icon(
        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
      ),
      onPressed: () => setState(() => _showPassword = !_showPassword),
    );
    return [
      TextFormField(
        controller: _password,
        obscureText: !_showPassword,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          label: fieldLabel('ລະຫັດຜ່ານໃໝ່', required: true),
          prefixIcon: const Icon(Icons.lock_outline, size: 20),
          suffixIcon: eye,
          errorMaxLines: 2,
        ),
        validator: (v) =>
            isStrongPassword(v ?? '') ? null : 'ລະຫັດຜ່ານຍັງບໍ່ຄົບເງື່ອນໄຂຂ້າງລຸ່ມ',
      ),
      const SizedBox(height: 8),
      PasswordChecklist(password: _password.text),
      TextFormField(
        controller: _confirm,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          label: fieldLabel('ຢືນຢັນລະຫັດຜ່ານ', required: true),
          prefixIcon: const Icon(Icons.lock_outline, size: 20),
          suffixIcon: eye,
        ),
        onFieldSubmitted: (_) => _savePassword(),
        validator: (v) => v != _password.text ? 'ລະຫັດຜ່ານບໍ່ກົງກັນ' : null,
      ),
      const SizedBox(height: 22),
      _SubmitButton(label: 'ຕັ້ງລະຫັດຜ່ານໃໝ່', busy: _busy, onPressed: _savePassword),
    ];
  }
}

/// Same shapes the customer app accepts in its "email or phone" field.
bool _isEmailOrPhone(String value) => looksLikeEmail(value) || looksLikePhone(value);

/// Three thin bars, the current and done ones in the logo's orange.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? C.accent : C.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}
