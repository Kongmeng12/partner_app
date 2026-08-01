import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _icons = {
    'booking': Icons.receipt_long_outlined,
    'payment': Icons.payments_outlined,
    'review': Icons.star_outline,
    'account': Icons.verified_user_outlined,
    'promo': Icons.local_offer_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ແຈ້ງເຕືອນ'),
        actions: [
          if ((feed.value?.unread ?? 0) > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref.read(actionsProvider).markAllNotificationsRead();
                } on ApiException catch (e) {
                  if (context.mounted) showMessage(context, e.message, error: true);
                }
              },
              child: const Text('ອ່ານທັງໝົດ'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: feed.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(notificationsProvider)),
        data: (f) => f.items.isEmpty
            ? const EmptyState(message: 'ຍັງບໍ່ມີແຈ້ງເຕືອນ', icon: Icons.notifications_none)
            : RefreshIndicator(
                color: C.accent,
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: f.items.length,
                  separatorBuilder: (_, __) => const Divider(indent: 68, height: 1),
                  itemBuilder: (_, i) {
                    final n = f.items[i];
                    return Container(
                      color: n.isRead ? null : C.accentSoft.withValues(alpha: 0.35),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: n.isRead ? C.bg : C.accentSoft,
                            borderRadius: BorderRadius.circular(R.md),
                          ),
                          child: Icon(
                            _icons[n.type] ?? Icons.notifications_none,
                            size: 20,
                            color: n.isRead ? C.soft : C.accentDark,
                          ),
                        ),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              n.body,
                              style: const TextStyle(fontSize: 12.5, color: C.soft, height: 1.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              laoAgo(n.createdAt),
                              style: const TextStyle(fontSize: 11, color: C.faint),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
