import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../models/models.dart';
import '../providers/auth.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(authProvider).partner;
    final dashboard = ref.watch(dashboardProvider);
    final unread = ref.watch(notificationsProvider).value?.unread ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(partner?.ownerName ?? 'PhaPhak Partner'),
            const Text(
              'ພາບລວມມື້ນີ້',
              style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: C.accent,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: dashboard.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
        data: (d) => RefreshIndicator(
          color: C.accent,
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'ເຂົ້າພັກມື້ນີ້',
                      value: '${d.arrivalCount}',
                      caption: 'ອອກ ${d.departureCount} · ພັກຢູ່ ${d.stayingCount}',
                      accent: d.arrivalCount > 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'ອັດຕາເຂົ້າພັກ',
                      value: '${d.occupancyPercent}%',
                      caption: '${d.soldTonight}/${d.capacity} ຫ້ອງ',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'ລາຍຮັບອາທິດນີ້',
                      value: kipShort(d.weekNet),
                      caption: '${d.weekBookings} ການຈອງ',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'ລໍໂອນ',
                      value: kipShort(d.payoutPendingAmount),
                      caption: '${d.payoutPendingCount} ງວດ',
                      onTap: () => context.go('/more/payouts'),
                    ),
                  ),
                ],
              ),

              if (d.pendingBookings > 0) ...[
                const SizedBox(height: 14),
                _PendingBanner(count: d.pendingBookings),
              ],

              const SizedBox(height: 16),
              SectionCard(
                title: 'ແຂກເຂົ້າພັກມື້ນີ້',
                trailing: TextButton(
                  onPressed: () => context.go('/bookings'),
                  child: const Text('ທັງໝົດ'),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: d.arrivals.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'ບໍ່ມີແຂກເຂົ້າພັກມື້ນີ້',
                          style: TextStyle(color: C.muted, fontSize: 13.5),
                        ),
                      )
                    : Column(
                        children: [
                          for (final a in d.arrivals)
                            _ArrivalRow(arrival: a),
                        ],
                      ),
              ),

              const SizedBox(height: 14),
              SectionCard(
                title: 'ອາທິດນີ້',
                child: Column(
                  children: [
                    LabelledRow(label: 'ການຈອງທີ່ພັກຈົບ', value: '${d.weekBookings} ລາຍການ'),
                    MoneyRow(label: 'ຍອດຂາຍລວມ', amount: d.weekGross),
                    MoneyRow(label: 'ຄ່າຄອມມິຊຊັນ', amount: d.weekCommission, negative: true),
                    const Divider(height: 20),
                    MoneyRow(label: 'ທ່ານໄດ້ຮັບ', amount: d.weekNet, strong: true),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/bookings/walk-in'),
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Walk-in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/calendar'),
                      icon: const Icon(Icons.price_change_outlined, size: 18),
                      label: const Text('ຕັ້ງລາຄາ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/bookings'),
      borderRadius: BorderRadius.circular(R.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.warnBg,
          borderRadius: BorderRadius.circular(R.lg),
        ),
        child: Row(
          children: [
            const Icon(Icons.pending_actions, color: C.warnFg, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ມີ $count ການຈອງລໍການຢືນຢັນ',
                style: const TextStyle(
                  color: C.warnFg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: C.warnFg, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ArrivalRow extends StatelessWidget {
  const _ArrivalRow({required this.arrival});
  final Map<String, dynamic> arrival;

  @override
  Widget build(BuildContext context) {
    final guest = strOf(arrival['guest']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Avatar(name: guest),
      title: Text(guest, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${strOf(arrival['code'])} · ຫ້ອງ ${strOf(arrival['room'])} · ${intOf(arrival['guests'], 1)} ຄົນ',
        style: const TextStyle(fontSize: 12, color: C.muted),
      ),
      trailing: StatusPill(map: bookingStatusPill, status: strOf(arrival['status']), compact: true),
      onTap: () => context.go('/bookings/${strOf(arrival['id'])}'),
    );
  }
}
