import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The guest's note from the booking screen, tinted with the accent so it
/// reads as "needs your attention" rather than as one more record row.
class SpecialRequestCard extends StatelessWidget {
  const SpecialRequestCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.accentSoft,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined, size: 19, color: C.accentDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ຄວາມຕ້ອງການເພີ່ມເຕີມຈາກແຂກ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.accentDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(fontSize: 13.5, color: C.text, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
