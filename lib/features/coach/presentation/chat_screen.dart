import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/coach_chat_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';

/// The in-app AI coach.
///
/// Scope is enforced server-side by the system instruction, so this screen
/// stays a plain transcript: bubbles, a typing indicator and an input bar.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _starters = [
    'How do I burn 300 kcal fast?',
    'What should I eat for dinner?',
    'How does the burn plan work?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // Runs after the new bubble is laid out, otherwise the extent is stale.
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

  Future<void> _confirmClear() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: Text(
          'This deletes every message on this device. It cannot be undone.',
          style: theme.textTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(coachChatProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = ref.watch(coachChatProvider);

    ref.listen(coachChatProvider, (_, next) {
      if (next.valueOrNull?.messages.isNotEmpty ?? false) _scrollToBottom();
    });

    final state = chat.valueOrNull ?? const CoachChatState();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Coach'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _confirmClear();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear conversation')),
            ],
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
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: state.messages.length +
                          (state.isTyping ? 1 : 0) +
                          (state.error != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < state.messages.length) {
                          return _Bubble(message: state.messages[index]);
                        }
                        if (state.isTyping && index == state.messages.length) {
                          return const _TypingBubble();
                        }
                        return _ErrorRow(
                          message: state.error!,
                          onRetry: () =>
                              ref.read(coachChatProvider.notifier).retry(),
                        );
                      },
                    ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: theme.colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text('Ask your coach', style: theme.textTheme.h1, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Training, food, calories and how to use FitPilot — ask anything.',
            style: theme.textTheme.body.copyWith(color: ext.textDisabled),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          for (final starter in _ChatScreenState._starters)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onStarter(starter),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
                      Icon(Icons.north_east_rounded, size: 15, color: ext.textDisabled),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : ext.surfaceRaised,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: isUser ? null : Border.all(color: ext.hairline),
            ),
            child: Text(message.content, style: theme.textTheme.body),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              message.clockLabel,
              style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots that fade in sequence while the coach is thinking.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ext.surfaceRaised,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: ext.hairline),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Stagger each dot by a third of the cycle.
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
            );
          },
        ),
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
    // Keeps the send button's enabled state in step with the text.
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
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.body,
                cursorColor: theme.colorScheme.primary,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: widget.enabled ? 'Ask about food or training…' : 'Coach is typing…',
                  hintStyle: theme.textTheme.caption.copyWith(color: ext.textDisabled),
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
              onTap: canSend ? () => widget.onSend(widget.controller.text) : null,
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
