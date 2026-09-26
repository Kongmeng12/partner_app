import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/money.dart';
import '../models/models.dart';
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
                              PopupMenuButton<void>(
                                tooltip: 'ເພີ່ມເຕີມ',
                                icon: const Icon(Icons.more_vert, size: 20, color: C.faint),
                                itemBuilder: (_) => [
                                  PopupMenuItem<void>(
                                    enabled: review.canRequestHide,
                                    onTap: () => _requestHide(context, ref, review),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.visibility_off_outlined, size: 18),
                                        SizedBox(width: 10),
                                        Text('ຂໍເຊື່ອງຮີວິວນີ້'),
                                      ],
                                    ),
                                  ),
                                ],
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
                          if (review.hideRequestStatus == 'pending')
                            const _RequestNote(
                              icon: Icons.hourglass_top_rounded,
                              text: 'ຂໍເຊື່ອງແລ້ວ · ລໍ admin ກວດ',
                              bg: C.warnBg,
                              fg: C.warnFg,
                            )
                          else if (review.hideRequestStatus == 'dismissed')
                            const _RequestNote(
                              icon: Icons.info_outline,
                              text: 'admin ກວດແລ້ວ ແລະ ບໍ່ເຊື່ອງຮີວິວນີ້',
                              bg: C.neutralBg,
                              fg: C.neutralFg,
                            ),
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

  Future<void> _requestHide(BuildContext context, WidgetRef ref, Review review) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HideRequestSheet(review: review),
    );
    if (sent == true && context.mounted) {
      showMessage(context, 'ສົ່ງຄຳຂໍແລ້ວ · admin ຈະກວດ ແລະ ຕັດສິນ');
    }
  }
}

class _RequestNote extends StatelessWidget {
  const _RequestNote({required this.icon, required this.text, required this.bg, required this.fg});

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(R.sm)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the partner wants the review hidden. The values are the API's
/// `report_reason`; the admin sees the same labels.
class _HideRequestSheet extends ConsumerStatefulWidget {
  const _HideRequestSheet({required this.review});
  final Review review;

  @override
  ConsumerState<_HideRequestSheet> createState() => _HideRequestSheetState();
}

class _HideRequestSheetState extends ConsumerState<_HideRequestSheet> {
  static const _reasons = {
    'fake': 'ຮີວິວປອມ / ບໍ່ແມ່ນແຂກແທ້',
    'offensive': 'ຄຳຫຍາບຄາຍ',
    'spam': 'ສະແປມ / ໂຄສະນາ',
    'other': 'ອື່ນໆ',
  };

  final _detail = TextEditingController();
  String? _reason;
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  /// "Other" says nothing on its own, so it needs the partner's words.
  bool get _ready =>
      _reason != null && (_reason != 'other' || _detail.text.trim().length >= 5);

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref.read(actionsProvider).requestHideReview(widget.review.id, _reason!, _detail.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ຂໍເຊື່ອງຮີວິວນີ້',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'ຮີວິວຍັງສະແດງຢູ່ຈົນກວ່າ admin ຈະກວດ ແລະ ອະນຸມັດ',
            style: TextStyle(fontSize: 13, color: C.muted),
          ),
          const SizedBox(height: 16),
          const Text('ເຫດຜົນ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _reasons.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _reason == e.key,
                  selectedColor: C.accentSoft,
                  onSelected: _busy ? null : (_) => setState(() => _reason = e.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _detail,
            maxLines: 3,
            maxLength: 1000,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _reason == 'other' ? 'ລາຍລະອຽດ (ຕ້ອງໃສ່)' : 'ລາຍລະອຽດ (ບໍ່ບັງຄັບ)',
              hintText: 'ເຊັ່ນ: ຄືນນັ້ນບໍ່ມີແຂກພັກຫ້ອງນີ້',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_busy || !_ready) ? null : _send,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('ສົ່ງຄຳຂໍໃຫ້ admin'),
          ),
        ],
      ),
    );
  }
}
