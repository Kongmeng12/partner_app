import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(bookingFilterProvider);
    final bookings = ref.watch(bookingsProvider);
    final counts = ref.watch(bookingCountsProvider).value ?? const {};

    String label(String base, String? key) {
      final n = key == null ? counts['all'] : counts[key];
      return n == null ? base : '$base ($n)';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ການຈອງ'),
        actions: [
          IconButton(
            tooltip: 'ບັນທຶກ Walk-in',
            onPressed: () => context.go('/bookings/walk-in'),
            icon: const Icon(Icons.person_add_alt),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          FilterChips(
            selected: filter,
            onSelect: (v) => ref.read(bookingFilterProvider.notifier).set(v),
            options: [
              (null, label('ທັງໝົດ', null)),
              ('pending', label('ລໍຖ້າ', 'pending')),
              ('confirmed', label('ຢືນຢັນ', 'confirmed')),
              ('staying', label('ກຳລັງພັກ', 'staying')),
              // `completed` is the API's word for a finished stay — the v1
              // `done` this chip used to send is not a status any more, so the
              // list answered 400 and the count never matched.
              ('completed', label('ສຳເລັດ', 'completed')),
              ('cancelled', label('ຍົກເລີກ', 'cancelled')),
              if ((counts['no_show'] ?? 0) > 0) ('no_show', label('ບໍ່ມາ', 'no_show')),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: bookings.when(
              loading: () => const LoadingBlock(),
              error: (e, _) =>
                  ErrorRetry(error: e, onRetry: () => ref.invalidate(bookingsProvider)),
              data: (page) => page.items.isEmpty
                  ? const EmptyState(
                      message: 'ຍັງບໍ່ມີການຈອງໃນໝວດນີ້',
                      icon: Icons.receipt_long_outlined,
                    )
                  : RefreshIndicator(
                      color: C.accent,
                      onRefresh: () async {
                        ref.invalidate(bookingsProvider);
                        ref.invalidate(bookingCountsProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => BookingCard(booking: page.items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});

  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/bookings/${booking.id}'),
        borderRadius: BorderRadius.circular(R.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(name: booking.guest, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.guest,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              booking.code,
                              style: const TextStyle(
                                fontSize: 12,
                                color: C.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (booking.isWalkIn) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: C.infoBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Walk-in',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: C.infoFg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  StatusPill(map: bookingStatusPill, status: booking.status, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 15, color: C.faint),
                  const SizedBox(width: 5),
                  Text(
                    '${laoDateRange(booking.checkIn, booking.checkOut)} · ${booking.nights} ຄືນ',
                    style: const TextStyle(fontSize: 12.5, color: C.soft),
                  ),
                  const Spacer(),
                  Text(
                    kip(booking.total),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.meeting_room_outlined, size: 15, color: C.faint),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${booking.roomType ?? 'ຫ້ອງ'}'
                      '${booking.quantity > 1 ? ' × ${booking.quantity}' : ''}'
                      ' · ${booking.guests} ຄົນ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: C.soft),
                    ),
                  ),
                  if (booking.paymentStatus != null)
                    StatusPill(
                      map: paymentStatusPill,
                      status: booking.paymentStatus,
                      compact: true,
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
