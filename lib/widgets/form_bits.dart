import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The three rules for a new password, kept in sync with the backend's
/// NEW_PASSWORD_PATTERN in `backend/src/auth/dto/auth.dto.ts`. Letters of any
/// script count, so a Lao password is fine.
bool passwordHasLength(String p) => p.length >= 8;
bool passwordHasLetter(String p) => RegExp(r'\p{L}', unicode: true).hasMatch(p);
bool passwordHasNumber(String p) => RegExp(r'\p{Nd}', unicode: true).hasMatch(p);
bool isStrongPassword(String p) =>
    passwordHasLength(p) && passwordHasLetter(p) && passwordHasNumber(p);

bool looksLikeEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

/// Same as the backend's PHONE_PATTERN.
bool looksLikePhone(String v) => RegExp(r'^\+?[0-9][0-9\s-]{5,19}$').hasMatch(v.trim());

/// A field label for [InputDecoration.label], with a red `*` when required.
Widget fieldLabel(String text, {bool required = false}) => Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: C.dangerFg)),
        ],
      ),
    );

/// "* ຊ່ອງທີ່ມີ * ຕ້ອງໃສ່" — shown once at the top of a form.
class RequiredLegend extends StatelessWidget {
  const RequiredLegend({super.key});

  @override
  Widget build(BuildContext context) => const Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 12.5, color: C.muted),
          children: [
            TextSpan(text: '* ', style: TextStyle(color: C.dangerFg)),
            TextSpan(text: 'ຊ່ອງທີ່ມີ * ຕ້ອງໃສ່'),
          ],
        ),
      );
}

/// The new-password rules as a live checklist: each turns green with a tick
/// as it is met, so what is missing shows while typing, not after submitting.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final short = password.isNotEmpty && !passwordHasLength(password);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rule(
            ok: passwordHasLength(password),
            text: 'ຢ່າງໜ້ອຍ 8 ຕົວອັກສອນ',
            progress: short ? '${password.length}/8' : null,
          ),
          _Rule(ok: passwordHasLetter(password), text: 'ມີຕົວອັກສອນຢ່າງໜ້ອຍ 1 ຕົວ'),
          _Rule(ok: passwordHasNumber(password), text: 'ມີຕົວເລກຢ່າງໜ້ອຍ 1 ຕົວ'),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.text, this.progress});

  final bool ok;
  final String text;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(ok),
              size: 15,
              color: ok ? C.successFg : C.faint,
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: ok ? C.successFg : C.muted)),
          if (progress != null) ...[
            const SizedBox(width: 6),
            Text(progress!, style: const TextStyle(fontSize: 11.5, color: C.faint)),
          ],
        ],
      ),
    );
  }
}

/// Scrolls to the first field in [keys] that failed validation and focuses
/// it. On a phone the red text is often off-screen, and a button that seems
/// to do nothing reads as broken. Returns false when nothing is in error.
bool jumpToFirstError(
  List<GlobalKey<FormFieldState<dynamic>>> keys, {
  Map<GlobalKey, FocusNode> focus = const {},
}) {
  for (final k in keys) {
    if (k.currentState?.hasError ?? false) {
      final ctx = k.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.2);
      }
      focus[k]?.requestFocus();
      return true;
    }
  }
  return false;
}
