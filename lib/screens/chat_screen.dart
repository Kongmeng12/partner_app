import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The conversations list — every booking the partner can talk about, with the
/// unread ones first.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ແຊັດກັບແຂກ')),
      body: bookings.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookingsProvider)),
        data: (page) {
          // A cancelled or long-finished stay is rarely worth chatting about,
          // so the list leads with the ones still in play.
          final items = [...page.items]..sort((a, b) {
              int rank(BookingSummary x) => switch (x.status) {
                    'staying' => 0,
                    'confirmed' => 1,
                    'pending' => 2,
                    'done' => 3,
                    _ => 4,
                  };
              return rank(a).compareTo(rank(b));
            });

          if (items.isEmpty) {
            return const EmptyState(
              message: 'ຍັງບໍ່ມີການຈອງ ຈຶ່ງຍັງບໍ່ມີແຊັດ',
              icon: Icons.chat_bubble_outline,
            );
          }

          return RefreshIndicator(
            color: C.accent,
            onRefresh: () async => ref.invalidate(bookingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
              itemBuilder: (_, i) {
                final b = items[i];
                return ListTile(
                  leading: Avatar(name: b.guest),
                  title: Text(
                    b.guest,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${b.code} · ${laoDateRange(b.checkIn, b.checkOut)}',
                    style: const TextStyle(fontSize: 12, color: C.muted),
                  ),
                  trailing: StatusPill(map: bookingStatusPill, status: b.status, compact: true),
                  onTap: () => context.go('/chats/${b.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Opening the thread is the moment the partner has seen it.
    Future.microtask(
      () => ref.read(chatProvider(widget.bookingId).notifier).markRead(),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(chatProvider(widget.bookingId).notifier).send(text);
      _input.clear();
      _scrollToEnd();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider(widget.bookingId));
    final booking = ref.watch(bookingDetailProvider(widget.bookingId));

    // New messages arriving from the poll should bring the view with them.
    ref.listen(chatProvider(widget.bookingId), (_, __) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.value?.guestName ?? 'ແຊັດ'),
            Text(
              booking.value?.code ?? '',
              style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const LoadingBlock(),
              error: (e, _) => ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(chatProvider(widget.bookingId)),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      message: 'ຍັງບໍ່ມີຂໍ້ຄວາມ\nທັກທາຍແຂກກ່ອນໄດ້ເລີຍ',
                      icon: Icons.chat_bubble_outline,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _Bubble(message: list[i]),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                color: C.surface,
                border: Border(top: BorderSide(color: C.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'ພິມຂໍ້ຄວາມ...',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: C.accent),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    // An admin joining the thread is worth labelling — the guest and the
    // property should know support is in the room.
    final fromAdmin = message.senderType == 'admin';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? C.accent
              : fromAdmin
                  ? C.infoBg
                  : C.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(R.lg),
            topRight: const Radius.circular(R.lg),
            bottomLeft: Radius.circular(mine ? R.lg : 4),
            bottomRight: Radius.circular(mine ? 4 : R.lg),
          ),
          border: mine ? null : Border.all(color: C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fromAdmin && !mine)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'ທີມງານ LaoStay',
                  style: TextStyle(fontSize: 10.5, color: C.infoFg, fontWeight: FontWeight.w700),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: mine ? Colors.white : C.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              laoAgo(message.sentAt),
              style: TextStyle(
                fontSize: 10.5,
                color: mine ? Colors.white70 : C.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
