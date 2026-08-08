import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/dates.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Every thread this property is part of.
///
/// A partner never starts a conversation — only a guest can, which is what
/// keeps the platform from becoming a channel for properties to message people
/// who never contacted them. So there is no "new message" button here.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ແຊັດ')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(conversationsProvider),
        child: conversations.when(
          loading: () => const LoadingBlock(),
          error: (e, _) => ErrorRetry(
            error: e,
            onRetry: () => ref.invalidate(conversationsProvider),
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    message: 'ຍັງບໍ່ມີຂໍ້ຄວາມ\nແຂກຈະເປັນຜູ້ເລີ່ມສົນທະນາກ່ອນ',
                    icon: Icons.chat_bubble_outline,
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: data.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) => _ConversationTile(conversation: data.items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unread > 0;

    return ListTile(
      onTap: () => context.go('/chats/${conversation.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: unread ? C.accentSoft : C.neutralBg,
        child: Text(
          initials(conversation.counterpartName),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: unread ? C.accentDark : C.soft,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.counterpartName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                color: C.text,
              ),
            ),
          ),
          if (conversation.lastMessageAt != null)
            Text(
              laoAgo(conversation.lastMessageAt),
              style: const TextStyle(fontSize: 11, color: C.faint),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // A deleted message keeps its place in the thread but has no
                // text, so the preview says so rather than showing nothing.
                conversation.lastMessage == null
                    ? 'ຂໍ້ຄວາມຖືກລຶບແລ້ວ'
                    : '${conversation.lastMessageMine ? 'ທ່ານ: ' : ''}${conversation.lastMessage}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: unread ? C.text : C.muted,
                  fontStyle: conversation.lastMessage == null ? FontStyle.italic : null,
                ),
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: C.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${conversation.unread}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One thread.
///
/// Keyed by conversation, not booking: a conversation may have no booking
/// behind it at all, and a guest who books twice keeps one thread rather than
/// splitting the history in half.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

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
    // Opening the thread is reading it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider(widget.conversationId).notifier).markRead();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
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
    // Cleared immediately: a partner typing the next line should not have to
    // wait for the round trip, and the text is already captured.
    _input.clear();

    try {
      await ref.read(chatProvider(widget.conversationId).notifier).send(text);
      _scrollToEnd();
    } on ApiException catch (e) {
      if (mounted) {
        _input.text = text; // put it back rather than lose what they wrote
        showMessage(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ລຶບຂໍ້ຄວາມນີ້?'),
        content: const Text('ແຂກຈະເຫັນວ່າ "ຂໍ້ຄວາມຖືກລຶບແລ້ວ" ແທນເນື້ອໃນ'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('ຍົກເລີກ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.dangerFg),
            onPressed: () => ctx.pop(true),
            child: const Text('ລຶບ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(chatProvider(widget.conversationId).notifier).deleteMessage(message.id);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider(widget.conversationId));
    final conversations = ref.watch(conversationsProvider);
    final conversation = conversations.value?.items
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conversation?.counterpartName ?? 'ແຊັດ', style: const TextStyle(fontSize: 16)),
            if (conversation?.bookingCode != null)
              Text(
                conversation!.bookingCode!,
                style: const TextStyle(fontSize: 11.5, color: C.muted),
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
                onRetry: () => ref.invalidate(chatProvider(widget.conversationId)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    message: 'ຍັງບໍ່ມີຂໍ້ຄວາມໃນການສົນທະນານີ້',
                    icon: Icons.chat_bubble_outline,
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _Bubble(
                    message: items[i],
                    onLongPress: items[i].mine && !items[i].isDeleted
                        ? () => _confirmDelete(items[i])
                        : null,
                  ),
                );
              },
            ),
          ),

          if (conversation?.isClosed == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: C.neutralBg,
              child: const Text(
                'ການສົນທະນານີ້ປິດແລ້ວ — ສົ່ງຂໍ້ຄວາມໃໝ່ບໍ່ໄດ້',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: C.neutralFg),
              ),
            )
          else
            _Composer(controller: _input, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onLongPress});

  final ChatMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: message.isDeleted
                ? C.neutralBg
                : mine
                    ? C.accent
                    : C.surface,
            border: mine ? null : Border.all(color: C.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(R.lg),
              topRight: const Radius.circular(R.lg),
              bottomLeft: Radius.circular(mine ? R.lg : 4),
              bottomRight: Radius.circular(mine ? 4 : R.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.isDeleted ? 'ຂໍ້ຄວາມຖືກລຶບແລ້ວ' : (message.text ?? ''),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontStyle: message.isDeleted ? FontStyle.italic : null,
                  color: message.isDeleted
                      ? C.neutralFg
                      : mine
                          ? Colors.white
                          : C.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                laoTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: mine && !message.isDeleted
                      ? Colors.white.withValues(alpha: 0.75)
                      : C.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'ພິມຂໍ້ຄວາມ...',
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            style: IconButton.styleFrom(backgroundColor: C.accent),
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 19, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
