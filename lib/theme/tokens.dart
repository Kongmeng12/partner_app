import 'package:flutter/material.dart';

/// Design tokens.
///
/// Ported one-for-one from `webadmin/src/theme.ts`, which itself was lifted
/// from the WebAdmin mockup — so the app and the admin panel are the same
/// product to look at. **This is the only file to change when a partner-app
/// design lands**: every screen reads its colours, radii and status pills from
/// here and hard-codes none of its own.
class C {
  const C._();

  /// Page background behind cards.
  static const bg = Color(0xFFF3E9D9);
  static const bgDeep = Color(0xFFEDE3D6);
  static const surface = Color(0xFFFFFFFF);

  static const dark = Color(0xFF3A2A1E);
  static const darkDeep = Color(0xFF241B15);
  static const darkPanel = Color(0xFF2C1E16);

  static const accent = Color(0xFFFD4D1C);
  static const accentDark = Color(0xFFD13A0E);
  static const accentSoft = Color(0xFFFFE3D6);

  static const text = Color(0xFF2B2521);
  static const soft = Color(0xFF5C5348);
  static const muted = Color(0xFF8C8073);
  static const faint = Color(0xFF9B8F7E);
  static const onDark = Color(0xFFC4B8A0);

  static const border = Color(0xFFE4D8C4);
  static const divider = Color(0xFFEFE6D6);
  static const rowHover = Color(0xFFFBF6EC);

  static const successBg = Color(0xFFE7EAD7);
  static const successFg = Color(0xFF4E5836);
  static const warnBg = Color(0xFFF6E7C9);
  static const warnFg = Color(0xFF8A6B1F);
  static const dangerBg = Color(0xFFFFF0EA);
  static const dangerFg = Color(0xFFD13A0E);
  static const neutralBg = Color(0xFFE4E2DC);
  static const neutralFg = Color(0xFF5C5348);
  static const infoBg = Color(0xFFF3E6D8);
  static const infoFg = Color(0xFF4A3527);
}

class R {
  const R._();
  static const sm = 8.0;
  static const md = 11.0;
  static const lg = 16.0;
  static const xl = 22.0;
}

/// A status chip: background, foreground and the Lao label that goes with it.
class Pill {
  const Pill(this.bg, this.fg, this.label);
  final Color bg;
  final Color fg;
  final String label;
}

const _fallbackPill = Pill(C.neutralBg, C.neutralFg, '—');

/// `bookings.status`
const bookingStatusPill = <String, Pill>{
  'confirmed': Pill(C.successBg, C.successFg, 'ຢືນຢັນ'),
  'pending': Pill(C.warnBg, C.warnFg, 'ລໍຖ້າ'),
  'staying': Pill(C.accentSoft, C.accentDark, 'ກຳລັງພັກ'),
  'done': Pill(C.infoBg, C.infoFg, 'ສຳເລັດ'),
  'cancelled': Pill(C.dangerBg, C.dangerFg, 'ຍົກເລີກ'),
};

/// `partners.status`
const partnerStatusPill = <String, Pill>{
  'verified': Pill(C.successBg, C.successFg, 'ຢືນຢັນແລ້ວ'),
  'pending': Pill(C.warnBg, C.warnFg, 'ລໍອະນຸມັດ'),
  'rejected': Pill(C.dangerBg, C.dangerFg, 'ບໍ່ຜ່ານ'),
};

/// `payouts.status`
const payoutStatusPill = <String, Pill>{
  'pending': Pill(C.warnBg, C.warnFg, 'ລໍໂອນ'),
  'paid': Pill(C.successBg, C.successFg, 'ໂອນແລ້ວ'),
};

/// `payments.status`
const paymentStatusPill = <String, Pill>{
  'paid': Pill(C.successBg, C.successFg, 'ຈ່າຍແລ້ວ'),
  'pending': Pill(C.warnBg, C.warnFg, 'ລໍຈ່າຍ'),
  'refunded': Pill(C.neutralBg, C.neutralFg, 'ຄືນເງິນ'),
  'expired': Pill(C.dangerBg, C.dangerFg, 'ໝົດອາຍຸ'),
};

/// An unknown status shows its raw value rather than a blank chip — a silent
/// gap would hide a backend change instead of surfacing it.
Pill pillFor(Map<String, Pill> map, String? status) {
  if (status == null || status.isEmpty) return _fallbackPill;
  return map[status] ?? Pill(_fallbackPill.bg, _fallbackPill.fg, status);
}

/// `room_availability.status`
const availabilityPill = <String, Pill>{
  'available': Pill(C.successBg, C.successFg, 'ວ່າງ'),
  'booked': Pill(C.accentSoft, C.accentDark, 'ຖືກຈອງ'),
  'closed': Pill(C.neutralBg, C.neutralFg, 'ປິດຂາຍ'),
};

const fontFamily = 'NotoSansLao';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.accent,
      primary: C.accent,
      surface: C.surface,
      brightness: Brightness.light,
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: C.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: C.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.lg),
        side: const BorderSide(color: C.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: C.divider, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.text,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: C.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: const BorderSide(color: C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: const BorderSide(color: C.accent, width: 2),
      ),
      labelStyle: const TextStyle(color: C.soft),
      hintStyle: const TextStyle(color: C.faint),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surface,
      indicatorColor: C.accentSoft,
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.darkPanel,
      contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: C.text,
      displayColor: C.text,
      fontFamily: fontFamily,
    ),
  );
}
