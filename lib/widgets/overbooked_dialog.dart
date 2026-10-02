import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/dates.dart';
import '../models/room_unit.dart';
import '../theme/tokens.dart';

/// Says so, plainly, when taking a room out of service left some future night
/// with more guests than rooms — the API has already lowered every night it
/// could, and never cancels a guest to make the numbers fit. Silent when the
/// list is empty, so callers can await it unconditionally.
Future<void> warnIfOverbooked(BuildContext context, List<OverbookedNight> nights) async {
  if (nights.isEmpty || !context.mounted) return;
  final first = nights.first;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: C.dangerFg, size: 30),
      title: const Text('ມີຄືນທີ່ແຂກຫຼາຍກວ່າຫ້ອງ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ຫຼັງປິດຫ້ອງນີ້ ຄືນລຸ່ມນີ້ມີແຂກຈອງຫຼາຍກວ່າຫ້ອງທີ່ເຫຼືອ. '
            'ລະບົບບໍ່ໄດ້ຍົກເລີກໃຜ — ເປີດຫ້ອງຄືນ, ຍ້າຍແຂກ ຫຼື ຕິດຕໍ່ແຂກ.',
            style: TextStyle(fontSize: 13.5, color: C.soft, height: 1.5),
          ),
          const SizedBox(height: 12),
          for (final n in nights.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '• ${laoDate(n.date)} — ຈອງ ${n.sold} · ມີຫ້ອງ ${n.rooms}',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.text),
              ),
            ),
          if (nights.length > 6)
            Text(
              'ແລະ ອີກ ${nights.length - 6} ຄືນ',
              style: const TextStyle(fontSize: 12.5, color: C.muted),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => ctx.pop(), child: const Text('ເຂົ້າໃຈແລ້ວ')),
        FilledButton(
          onPressed: () {
            ctx.pop();
            context.go('/calendar/day/${first.date}');
          },
          child: Text('ເບິ່ງ ${laoDate(first.date)}'),
        ),
      ],
    ),
  );
}
