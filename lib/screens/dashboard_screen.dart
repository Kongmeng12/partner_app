import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/auth.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The home tab. Minimal, in the logo's colours: one orange card for today,
/// then white cards, with orange kept for the things that need the front
/// desk to act.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(authProvider).partner;
    final dashboard = ref.watch(dashboardProvider);
    final unread = ref.watch(notificationsProvider).value?.unread ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset('assets/images/logo.png', width: 36, height: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ສະບາຍດີ, ${partner?.ownerName ?? 'Partner'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    laoFullDate(todayUtc()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: C.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TodayHero(dashboard: d),

              if (d.pendingBookings > 0) ...[
                const SizedBox(height: 12),
                _ActionRow(
                  icon: Icons.pending_actions,
                  text: 'ມີ ${d.pendingBookings} ການຈອງລໍການຢືນຢັນ',
                  onTap: () => context.go('/bookings'),
                ),
              ],

              const SizedBox(height: 24),
              _SectionHeader(
                title: 'ແຂກເຂົ້າພັກມື້ນີ້',
                actionLabel: 'ທັງໝົດ',
                onAction: () => context.go('/bookings'),
              ),
              if (d.guestChoseCount + d.propertyChoosesCount > 0) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(
                      icon: Icons.person_outline,
                      label: 'ແຂກເລືອກຫ້ອງເອງ',
                      count: d.guestChoseCount,
                    ),
                    _CountChip(
                      icon: Icons.apartment_outlined,
                      label: 'ໂຮງແຮມເລືອກໃຫ້',
                      count: d.propertyChoosesCount,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              _PlainCard(
                child: d.arrivals.isEmpty
                    ? const _EmptyLine('ບໍ່ມີແຂກເຂົ້າພັກມື້ນີ້')
                    : Column(
                        children: [
                          for (var i = 0; i < d.arrivals.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: C.divider),
                            _ArrivalRow(arrival: d.arrivals[i]),
                          ],
                        ],
                      ),
              ),

              if (d.roomsToAssignCount > 0) ...[
                const SizedBox(height: 24),
                _SectionHeader(title: 'ລໍຖ້າໂຮງແຮມເລືອກຫ້ອງ', count: d.roomsToAssignCount),
                _PlainCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < d.roomsToAssign.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: C.divider),
                        _ToAssignRow(booking: d.roomsToAssign[i]),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const _SectionHeader(title: 'ການເງິນ'),
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

              const SizedBox(height: 20),
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

/// Today at a glance, on the logo's orange.
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.dashboard});
  final PartnerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final fill = d.capacity == 0 ? 0.0 : (d.soldTonight / d.capacity).clamp(0.0, 1.0);

    return Material(
      color: C.accent,
      borderRadius: BorderRadius.circular(R.xl),
      child: InkWell(
        onTap: () => context.go('/calendar'),
        borderRadius: BorderRadius.circular(R.xl),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ມື້ນີ້',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              // The swoosh under the logo's wordmark, as a quiet echo.
              const SizedBox(width: 40, height: 8, child: CustomPaint(painter: _Swoosh())),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeroFigure(value: d.arrivalCount, label: 'ເຂົ້າພັກ'),
                  _HeroFigure(value: d.departureCount, label: 'ອອກ'),
                  _HeroFigure(value: d.stayingCount, label: 'ພັກຢູ່'),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ອັດຕາເຂົ້າພັກຄືນນີ້',
                      style: TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                  ),
                  Text(
                    '${d.occupancyPercent}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fill,
                  minHeight: 6,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${d.soldTonight}/${d.capacity} ຫ້ອງ',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Swoosh extends CustomPainter {
  const _Swoosh();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(1, size.height - 1)
      ..quadraticBezierTo(size.width / 2, 1, size.width - 1, size.height - 3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.actionLabel, this.onAction});

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.text),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: C.accent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(R.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        color: C.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: C.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A white card with a hairline border, no shadow.
class _PlainCard extends StatelessWidget {
  const _PlainCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Text(text, style: const TextStyle(color: C.muted, fontSize: 13.5)),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(R.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.lg),
            border: Border.all(color: C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: C.accentSoft, shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: C.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: C.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label, required this.count});

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: C.soft),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, color: C.soft)),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text),
          ),
        ],
      ),
    );
  }
}

/// Small rounded label: the assigned room in orange, or a quiet reminder that
/// the front desk still has to pick one.
class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.strong = false});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? C.accentSoft : C.surface,
        borderRadius: BorderRadius.circular(R.sm),
        border: strong ? null : Border.all(color: C.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: strong ? C.accentDark : C.muted,
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
    final roomNumbers =
        (arrival['roomNumbers'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final roomType = strOf(arrival['roomType'], 'ຫ້ອງ');
    final quantity = intOf(arrival['quantity'], 1);

    final Widget trailing;
    if (roomNumbers.isNotEmpty) {
      trailing = _Tag('ຫ້ອງ ${roomNumbers.join(', ')}', strong: true);
    } else if (arrival['roomChoice'] == 'property') {
      trailing = const _Tag('ລໍກຳນົດຫ້ອງ');
    } else {
      trailing = StatusPill(
        map: bookingStatusPill,
        status: strOf(arrival['status']),
        compact: true,
      );
    }

    return InkWell(
      onTap: () => context.go('/bookings/${strOf(arrival['id'])}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Avatar(name: guest, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${strOf(arrival['code'])} · $roomType'
                    '${quantity > 1 ? ' × $quantity' : ''}'
                    ' · ${intOf(arrival['guests'], 1)} ຄົນ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ToAssignRow extends StatelessWidget {
  const _ToAssignRow({required this.booking});
  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final day = parseDay(booking['checkIn']);
    final isToday = day != null && day == todayUtc();
    final quantity = intOf(booking['quantity'], 1);

    return InkWell(
      onTap: () => context.go('/bookings/${strOf(booking['id'])}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // The arrival day as a small calendar leaf: soonest is what matters.
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isToday ? C.accent : C.accentSoft,
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Column(
                children: [
                  Text(
                    day == null ? '—' : '${day.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: isToday ? Colors.white : C.accentDark,
                    ),
                  ),
                  Text(
                    isToday ? 'ມື້ນີ້' : laoDate(booking['checkIn']).split(' ').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isToday ? Colors.white : C.accentDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strOf(booking['guest']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${strOf(booking['roomType'], 'ຫ້ອງ')}'
                    '${quantity > 1 ? ' × $quantity' : ''}'
                    ' · ${intOf(booking['nights'], 1)} ຄືນ'
                    ' · ${intOf(booking['guests'], 1)} ຄົນ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ກຳນົດຫ້ອງ',
              style: TextStyle(fontSize: 12.5, color: C.accent, fontWeight: FontWeight.w700),
            ),
            const Icon(Icons.chevron_right, size: 18, color: C.accent),
          ],
        ),
      ),
    );
  }
}
