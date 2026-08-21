import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Read-only by design: money leaves the platform when someone with the finance
/// role releases it in the WebAdmin, never from here.
class PayoutsScreen extends ConsumerWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(payoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ການໂອນເງິນ')),
      body: payouts.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(payoutsProvider)),
        data: (p) => RefreshIndicator(
          color: C.accent,
          onRefresh: () async => ref.invalidate(payoutsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'ລໍໂອນ',
                      value: kipShort(p.pendingTotal),
                      caption: '${p.pendingCount} ງວດ',
                      accent: p.pendingCount > 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'ໂອນແລ້ວທັງໝົດ',
                      value: kipShort(p.paidTotal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (p.items.isEmpty)
                const EmptyState(
                  message: 'ຍັງບໍ່ມີງວດການໂອນ\nງວດຈະຖືກສ້າງທຸກອາທິດຫຼັງແຂກເຊັກເອົາ',
                  icon: Icons.account_balance_wallet_outlined,
                )
              else
                for (final payout in p.items) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  laoDateRange(payout.periodStart, payout.periodEnd),
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              StatusPill(
                                map: payoutStatusPill,
                                status: payout.status,
                                compact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          MoneyRow(label: 'ຍອດຂາຍ', amount: payout.gross),
                          MoneyRow(
                            label: 'ຄ່າຄອມມິຊຊັນ',
                            amount: payout.commission,
                            negative: true,
                          ),
                          const Divider(height: 18),
                          MoneyRow(label: 'ໄດ້ຮັບ', amount: payout.net, strong: true),
                          if (payout.paidAt != null) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'ໂອນເມື່ອ ${laoDateTime(payout.paidAt)}',
                                style: const TextStyle(fontSize: 11.5, color: C.faint),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
              const Text(
                'ການໂອນດຳເນີນການໂດຍທີມການເງິນ PhaPhak ທຸກອາທິດ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: C.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
