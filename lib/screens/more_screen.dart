import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../providers/auth.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(authProvider).partner;
    final payouts = ref.watch(payoutsProvider).value;
    final reviews = ref.watch(reviewsProvider).value;
    final unreadNotifications = ref.watch(notificationsProvider).value?.unread ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('ເພີ່ມເຕີມ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Avatar(name: partner?.ownerName ?? '?', size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner?.ownerName ?? '—',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          partner?.email ?? '',
                          style: const TextStyle(fontSize: 12.5, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(map: partnerStatusPill, status: partner?.status, compact: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.home_work_outlined,
            title: 'ທີ່ພັກ & ຫ້ອງ',
            subtitle: '${partner?.propertyCount ?? 0} ທີ່ພັກ',
            onTap: () => context.go('/more/properties'),
          ),
          _Tile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'ການໂອນເງິນ',
            subtitle: payouts == null
                ? null
                : payouts.pendingCount > 0
                    ? 'ລໍໂອນ ${kip(payouts.pendingTotal)}'
                    : 'ບໍ່ມີລາຍການລໍໂອນ',
            onTap: () => context.go('/more/payouts'),
          ),
          _Tile(
            icon: Icons.star_outline,
            title: 'ຮີວິວ',
            subtitle: reviews == null
                ? null
                : reviews.total == 0
                    ? 'ຍັງບໍ່ມີຮີວິວ'
                    : '${reviews.total} ຮີວິວ · ${reviews.averageStars?.toStringAsFixed(2) ?? '—'} ດາວ',
            onTap: () => context.go('/more/reviews'),
          ),
          _Tile(
            icon: Icons.notifications_none,
            title: 'ແຈ້ງເຕືອນ',
            subtitle: unreadNotifications > 0 ? '$unreadNotifications ອັນທີ່ຍັງບໍ່ອ່ານ' : null,
            badge: unreadNotifications,
            onTap: () => context.go('/notifications'),
          ),
          _Tile(
            icon: Icons.person_outline,
            title: 'ໂປຣໄຟລ໌ & ບັນຊີທະນາຄານ',
            onTap: () => context.go('/more/profile'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('ອອກຈາກລະບົບ?'),
                  content: const Text('ທ່ານຈະຕ້ອງເຂົ້າສູ່ລະບົບໃໝ່ໃນຄັ້ງຕໍ່ໄປ'),
                  actions: [
                    TextButton(onPressed: () => ctx.pop(false), child: const Text('ຍົກເລີກ')),
                    FilledButton(onPressed: () => ctx.pop(true), child: const Text('ອອກ')),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authProvider.notifier).signOut();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: C.dangerFg,
              side: const BorderSide(color: C.dangerBg),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('ອອກຈາກລະບົບ'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.lg)),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.bg,
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Icon(icon, size: 20, color: C.soft),
          ),
          title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: C.muted)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: C.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: C.faint),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
