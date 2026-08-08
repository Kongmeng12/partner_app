import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ຮີວິວ')),
      body: reviews.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(reviewsProvider)),
        data: (r) => RefreshIndicator(
          color: C.accent,
          onRefresh: () async => ref.invalidate(reviewsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(
                        r.averageStars?.toStringAsFixed(2) ?? '—',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stars(r.averageStars?.round() ?? 0),
                        style: const TextStyle(fontSize: 19, color: C.accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${r.total} ຮີວິວ',
                        style: const TextStyle(fontSize: 13, color: C.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (r.items.isEmpty)
                const EmptyState(
                  message: 'ຍັງບໍ່ມີຮີວິວ\nແຂກຈະຂຽນໄດ້ຫຼັງພັກຈົບ',
                  icon: Icons.star_outline,
                )
              else
                for (final review in r.items) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Avatar(name: review.guest, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      review.guest,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      review.property,
                                      style: const TextStyle(fontSize: 11.5, color: C.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                stars(review.stars),
                                style: const TextStyle(fontSize: 13, color: C.accent),
                              ),
                            ],
                          ),
                          if (review.title?.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Text(
                              review.title!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: C.text,
                              ),
                            ),
                          ],
                          if (review.comment?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Text(
                              review.comment!,
                              style: const TextStyle(fontSize: 13.5, color: C.soft, height: 1.55),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
