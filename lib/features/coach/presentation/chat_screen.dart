import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/coach_chat_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/coach_mark.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/domain/entities/chat_conversation.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';
import 'package:fitpilot/features/coach/presentation/chat_markdown.dart';

/// The in-app AI coach.
///
/// Threaded like any modern assistant: a drawer lists past chats, each with its
/// own actions, and the coach mark in the app bar starts a fresh one. Scope is
/// enforced server-side by the system instruction, so this screen stays a
/// transcript plus navigation.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const starters = [
    'How do I burn 300 kcal fast?',
    'What should I eat for dinner?',
    'How does the burn plan work?',
    'Cheap ways to hit my protein target?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    if (!requireOnline(context, ref, feature: 'Coach')) return;

    _input.clear();
    await ref.read(coachChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = ref.watch(coachChatProvider);
    final state = chat.valueOrNull ?? const CoachChatState();

    ref.listen(coachChatProvider, (_, next) {
      if (next.valueOrNull?.messages.isNotEmpty ?? false) _scrollToBottom();
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      drawer: const _ConversationDrawer(),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Chat history',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            const CoachMark(size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coach', style: theme.textTheme.h2),
                  if (state.conversation != null)
                    Text(
                      state.conversation!.title,
                      style: theme.textTheme.overline.copyWith(
                        color: theme.extension<AppColors>()!.textDisabled,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () async {
              await ref.read(coachChatProvider.notifier).startNew();
              _input.clear();
            },
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: chat.hasError && state.isEmpty
                  ? ErrorState(
                      reason: "Couldn't open the coach.",
                      onRetry: () => ref.invalidate(coachChatProvider),
                    )
                  : state.isEmpty
                  ? _EmptyState(onStarter: _send)
                  : _Transcript(state: state, controller: _scroll),
            ),
            _InputBar(
              controller: _input,
              enabled: !state.isTyping,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Transcript extends ConsumerWidget {
  final CoachChatState state;
  final ScrollController controller;

  const _Transcript({required this.state, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = (state.isTyping ? 1 : 0) + (state.error != null ? 1 : 0);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: state.messages.length + extras,
      itemBuilder: (context, index) {
        if (index < state.messages.length) {
          return _Bubble(message: state.messages[index]);
        }
        if (state.isTyping && index == state.messages.length) {
          return const _TypingBubble();
        }
        return _ErrorRow(
          message: state.error!,
          onRetry: () => ref.read(coachChatProvider.notifier).retry(),
        );
      },
    );
  }
}

/// The drawer: past chats, each with rename and delete.
class _ConversationDrawer extends ConsumerWidget {
  const _ConversationDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final listAsync = ref.watch(conversationListProvider);
    final active = ref.watch(coachChatProvider).valueOrNull?.conversation?.id;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  const CoachMark(size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Your chats', style: theme.textTheme.h2),
                  ),
                  IconButton(
                    tooltip: 'New chat',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await ref.read(coachChatProvider.notifier).startNew();
                    },
                  ),
                ],
              ),
            ),
            Divider(color: ext.hairline, height: 1),
            Expanded(
              child: listAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    "Couldn't load your chats.",
                    style: theme.textTheme.caption,
                  ),
                ),
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 34,
                            color: ext.textDisabled,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No chats yet.\nAsk the coach something to start one.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.caption,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: conversations.length,
                    itemBuilder: (context, i) => _ConversationRow(
                      conversation: conversations[i],
                      isActive: conversations[i].id == active,
                    ),
                  );
                },
              ),
            ),
            if (listAsync.valueOrNull?.isNotEmpty ?? false) ...[
              Divider(color: ext.hairline, height: 1),
              TextButton.icon(
                onPressed: () => _confirmDeleteAll(context, ref),
                icon: Icon(Icons.delete_sweep_outlined, size: 18, color: ext.error),
                label: Text(
                  'Delete all chats',
                  style: theme.textTheme.caption.copyWith(color: ext.error),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all chats?'),
        content: const Text(
          'Every conversation on this device is removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(coachChatProvider.notifier).deleteAll();
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _ConversationRow extends ConsumerWidget {
  final ChatConversation conversation;
  final bool isActive;

  const _ConversationRow({required this.conversation, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          conversation.title,
          style: theme.textTheme.body.copyWith(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? theme.colorScheme.primary : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${conversation.messageCount} message'
          '${conversation.messageCount == 1 ? '' : 's'} · '
          '${conversation.relativeAge()}',
          style: theme.textTheme.overline.copyWith(color: ext.textDisabled),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 18, color: ext.textDisabled),
          onSelected: (value) async {
            if (value == 'rename') {
              await _rename(context, ref);
            } else if (value == 'delete') {
              await _delete(context, ref);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 17),
                  SizedBox(width: 10),
                  Text('Rename'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 17),
                  SizedBox(width: 10),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: () async {
          Navigator.of(context).pop();
          await ref.read(coachChatProvider.notifier).open(conversation.id);
        },
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: conversation.title);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Rename chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(hintText: 'Chat name'),
            onSubmitted: (v) => Navigator.of(c).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (result == null || result.trim().isEmpty) return;
      await ref.read(coachChatProvider.notifier).rename(conversation.id, result);
    } finally {
      // Disposed only after the dialog route has finished animating out. The
      // TextField is still mounted and still listening during that animation,
      // so disposing the moment showDialog returns left it depending on a dead
      // controller — which surfaced as '_dependents.isEmpty is not true' and a
      // "dirty widget in the wrong build scope" crash on Save.
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text('"${conversation.title}" will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(coachChatProvider.notifier).delete(conversation.id);
  }
}

class _EmptyState extends StatelessWidget {
  final void Function(String) onStarter;

  const _EmptyState({required this.onStarter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 28),
          const CoachMark(size: 68),
          const SizedBox(height: 18),
          Text(
            'Ask your coach',
            style: theme.textTheme.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Training, food, calories and how to use FitPilot — ask anything.',
            style: theme.textTheme.body.copyWith(color: ext.textDisabled),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          for (final starter in _ChatScreenState.starters)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onStarter(starter),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: ext.surfaceRaised,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: ext.hairline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(starter, style: theme.textTheme.body),
                      ),
                      Icon(
                        Icons.north_east_rounded,
                        size: 15,
                        color: ext.textDisabled,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: CoachMark(size: 26),
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.74,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary.withValues(alpha: 0.16)
                        : ext.surfaceRaised,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 5),
                      bottomRight: Radius.circular(isUser ? 5 : 18),
                    ),
                    border: isUser ? null : Border.all(color: ext.hairline),
                  ),
                  // Coach replies arrive with light markdown; rendering it is
                  // what makes an answer scannable rather than a wall of
                  // asterisks.
                  child: ChatMessageBody(content: message.content),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    message.clockLabel,
                    style: theme.textTheme.overline.copyWith(
                      color: ext.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The coach mark turning, plus three fading dots.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: ThinkingCoachMark(size: 26),
          ),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: ext.surfaceRaised,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: ext.hairline),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_controller.value - i * 0.2) % 1.0;
                  final opacity = t < 0.5 ? 0.3 + t : 1.3 - t;
                  return Padding(
                    padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
                    child: Opacity(
                      opacity: opacity.clamp(0.3, 1.0),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: ext.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.caption.copyWith(color: ext.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final canSend = widget.enabled && widget.controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: ext.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ext.surfaceRaised,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ext.hairline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.body,
                cursorColor: theme.colorScheme.primary,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: widget.enabled
                      ? 'Ask about food or training…'
                      : 'Coach is thinking…',
                  hintStyle: theme.textTheme.caption.copyWith(
                    color: ext.textDisabled,
                  ),
                ),
                onSubmitted: canSend ? widget.onSend : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: canSend
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.28),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: canSend
                  ? () => widget.onSend(widget.controller.text)
                  : null,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
