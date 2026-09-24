import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/money.dart';
import '../theme/tokens.dart';

/// A status chip. Colour and label both come from `theme/tokens.dart`, so an
/// unknown status still renders — showing its raw value rather than a blank.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.map, required this.status, this.compact = false});

  final Map<String, Pill> map;
  final String? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pill = pillFor(map, status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: pill.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        pill.label,
        style: TextStyle(
          color: pill.fg,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

/// A titled white card — the surface every list and form sits on.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: C.text,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// A number with its caption — the dashboard's building block.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.accent = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent ? C.accentSoft : C.surface,
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: accent ? C.accentSoft : C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: accent ? C.accentDark : C.text,
                height: 1.15,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, style: const TextStyle(fontSize: 11, color: C.faint)),
            ],
          ],
        ),
      ),
    );
  }
}

class LabelledRow extends StatelessWidget {
  const LabelledRow({super.key, required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: const TextStyle(fontSize: 13, color: C.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                color: C.text,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Money on its own line, right-aligned against a caption.
class MoneyRow extends StatelessWidget {
  const MoneyRow({super.key, required this.label, required this.amount, this.strong = false, this.negative = false});

  final String label;
  final int amount;
  final bool strong;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: strong ? C.text : C.soft,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${negative ? '−' : ''}${kip(amount)}',
            style: TextStyle(
              fontSize: strong ? 16 : 13.5,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              color: negative ? C.dangerFg : C.text,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: C.faint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.muted, fontSize: 14),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Shows the message the API sent — it is bilingual and actionable — plus a
/// retry. A generic "something went wrong" would throw that away.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: C.dangerFg),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.soft, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ລອງໃໝ່'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2.5, color: C.accent),
        ),
      );
}

/// A property or room photo. Falls back to a tinted placeholder rather than a
/// broken-image glyph — a listing without photos is normal, not an error.
class Photo extends StatelessWidget {
  const Photo({super.key, this.url, this.width = 64, this.height = 64, this.radius = R.md});

  final String? url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: C.infoBg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Icon(Icons.home_outlined, color: C.faint, size: 22),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: AppConfig.resolveUrl(url!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}

/// Round initial badge for a guest, coloured deterministically from their name
/// so the same person keeps the same colour everywhere.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  static const _palette = [
    Color(0xFF8A6B4A),
    Color(0xFF6E7B4E),
    Color(0xFFB07850),
    Color(0xFF8A6E56),
    Color(0xFFA98E5F),
    Color(0xFFD13A0E),
    Color(0xFF3A2A1E),
  ];

  @override
  Widget build(BuildContext context) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final color = _palette[hash % _palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Snackbars carry the API's own message, which already explains the problem in
/// both languages.
void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? C.dangerFg : C.darkPanel,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
}

/// A pill-shaped tap target for a quick bulk action or preset — "select all",
/// "this month" — distinct from [FilterChips]' selected/unselected toggle
/// chips: a `QuickChip` fires an action rather than holding a selection state.
class QuickChip extends StatelessWidget {
  const QuickChip({super.key, required this.label, required this.onTap, this.selected = false});

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? C.accentSoft : C.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? C.accent : C.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? C.accentDark : C.soft,
          ),
        ),
      ),
    );
  }
}

/// A horizontal row of filter chips.
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  /// `(value, label)` — a null value means "all".
  final List<(String?, String)> options;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == value,
                onSelected: (_) => onSelect(value),
                showCheckmark: false,
                backgroundColor: C.surface,
                selectedColor: C.accentSoft,
                side: BorderSide(color: selected == value ? C.accent : C.border),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected == value ? C.accentDark : C.soft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
