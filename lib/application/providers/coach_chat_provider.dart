import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/protein_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/data/ai/coach_service.dart';
import 'package:fitpilot/data/repositories/chat_repository.dart';
import 'package:fitpilot/domain/entities/chat_conversation.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';

/// Exposes the ChatRepository. No guest guard: chat is local-only, so nothing
/// it writes is ever queued for sync.
final chatRepositoryProvider = FutureProvider<ChatRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ChatRepository(db);
});

/// Swapped in tests so the provider can be driven without a network.
final coachServiceProvider = Provider<CoachService>((ref) => CoachService());

/// Every thread, newest activity first. Drives the sidebar.
final conversationListProvider = FutureProvider<List<ChatConversation>>((
  ref,
) async {
  // Rebuilds whenever the active chat changes, so a new title or a new message
  // reorders the sidebar without any manual invalidation.
  ref.watch(coachChatProvider);
  final repo = await ref.watch(chatRepositoryProvider.future);
  return repo.conversations();
});

/// The coach conversation plus its in-flight state.
class CoachChatState {
  /// Null before the first thread is opened or created.
  final ChatConversation? conversation;
  final List<ChatMessage> messages;

  /// True while waiting on the server — drives the typing indicator.
  final bool isTyping;

  /// User-ready failure text for the last send, or null.
  final String? error;

  const CoachChatState({
    this.conversation,
    this.messages = const [],
    this.isTyping = false,
    this.error,
  });

  bool get isEmpty => messages.isEmpty;

  CoachChatState copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    bool? isTyping,
    String? error,
    bool clearError = false,
  }) {
    return CoachChatState(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final coachChatProvider =
    AsyncNotifierProvider<CoachChatNotifier, CoachChatState>(
      CoachChatNotifier.new,
    );

class CoachChatNotifier extends AsyncNotifier<CoachChatState> {
  @override
  Future<CoachChatState> build() async {
    final repo = await ref.watch(chatRepositoryProvider.future);

    // Resume the most recent thread rather than opening a blank one: reopening
    // the coach mid-conversation should carry on where it left off.
    final existing = await repo.conversations();
    if (existing.isEmpty) return const CoachChatState();

    final latest = existing.first;
    return CoachChatState(
      conversation: latest,
      messages: await repo.messagesIn(latest.id),
    );
  }

  /// Starts a fresh thread.
  ///
  /// The row is only written once the first message is sent — see [send] — so
  /// opening the coach and backing out does not litter the sidebar.
  Future<void> startNew() async {
    final repo = await ref.read(chatRepositoryProvider.future);
    await repo.pruneEmpty();
    state = const AsyncData(CoachChatState());
  }

  /// Switches to an existing thread.
  Future<void> open(String conversationId) async {
    final repo = await ref.read(chatRepositoryProvider.future);
    final all = await repo.conversations();
    final match = all.where((c) => c.id == conversationId).firstOrNull;
    if (match == null) return;

    state = AsyncData(
      CoachChatState(
        conversation: match,
        messages: await repo.messagesIn(conversationId),
      ),
    );
  }

  Future<void> rename(String conversationId, String title) async {
    final repo = await ref.read(chatRepositoryProvider.future);
    await repo.renameConversation(conversationId, title);

    final current = state.valueOrNull;
    if (current?.conversation?.id == conversationId) {
      state = AsyncData(
        current!.copyWith(
          conversation: current.conversation!.copyWith(title: title.trim()),
        ),
      );
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> delete(String conversationId) async {
    final repo = await ref.read(chatRepositoryProvider.future);
    await repo.deleteConversation(conversationId);

    // Deleting the open thread drops the user into a blank one rather than a
    // dangling reference to something that no longer exists.
    final current = state.valueOrNull;
    if (current?.conversation?.id == conversationId) {
      state = const AsyncData(CoachChatState());
    } else {
      ref.invalidateSelf();
    }
  }

  Future<void> deleteAll() async {
    final repo = await ref.read(chatRepositoryProvider.future);
    await repo.deleteAllConversations();
    state = const AsyncData(CoachChatState());
  }

  /// Sends [text] and appends the reply.
  ///
  /// The user's bubble is written immediately so the conversation feels
  /// responsive; a failure leaves it in place and surfaces
  /// [CoachChatState.error] so [retry] can re-send without duplicating it.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final current = state.valueOrNull ?? const CoachChatState();
    if (current.isTyping) return;

    final repo = await ref.read(chatRepositoryProvider.future);

    // The thread is created on first send, and titled from that message — so
    // the sidebar shows what the chat is about without asking the user to name
    // it.
    var conversation = current.conversation;
    conversation ??= await repo.createConversation(
      title: ChatConversation.titleFromMessage(trimmed),
    );

    final message = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );
    await repo.insert(conversation.id, message);

    final withUser = [...current.messages, message];
    state = AsyncData(
      current.copyWith(
        conversation: conversation,
        messages: withUser,
        isTyping: true,
        clearError: true,
      ),
    );

    await _ask(conversation, withUser);
  }

  /// Re-sends the existing transcript after a failure. The user's message is
  /// already in the list, so nothing is appended.
  Future<void> retry() async {
    final current = state.valueOrNull;
    if (current == null || current.messages.isEmpty || current.isTyping) return;
    final conversation = current.conversation;
    if (conversation == null) return;

    state = AsyncData(current.copyWith(isTyping: true, clearError: true));
    await _ask(conversation, current.messages);
  }

  Future<void> _ask(
    ChatConversation conversation,
    List<ChatMessage> history,
  ) async {
    try {
      final reply = await ref
          .read(coachServiceProvider)
          .send(history: history, context: await _buildContext());

      final answer = ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.model,
        content: reply,
        createdAt: DateTime.now(),
      );

      final repo = await ref.read(chatRepositoryProvider.future);
      await repo.insert(conversation.id, answer);

      state = AsyncData(
        CoachChatState(
          conversation: conversation,
          messages: [...history, answer],
          isTyping: false,
        ),
      );
    } catch (e) {
      state = AsyncData(
        CoachChatState(
          conversation: conversation,
          messages: history,
          isTyping: false,
          error: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Best-effort snapshot of the user's day. Every field is optional, so a
  /// failure here degrades the answer rather than blocking the message.
  Future<CoachContext?> _buildContext() async {
    try {
      final today = await ref.read(todayProvider.future);
      final profile = await ref.read(profileProvider.future);
      final protein = ref.read(proteinTodayProvider);
      // The streak lives on progressProvider, which also owns the day history
      // it is derived from — reading it here keeps one source of truth.
      final streak = (await ref.read(progressProvider.future)).streak;

      return CoachContext(
        name: profile.name,
        todayKcal: today.dayStatus.total.midpoint,
        targetKcal: profile.targetOverride,
        toBurn: today.dayStatus.toBurn,
        streakDays: streak.currentStreak,
        activeProgram: profile.activeProgramId,
        proteinTodayG: protein.consumedG.round(),
        proteinTargetG: protein.targetG,
      );
    } catch (_) {
      return null;
    }
  }

  /// Wipes the open thread's messages, keeping the thread itself.
  Future<void> clear() async {
    final current = state.valueOrNull;
    final conversation = current?.conversation;
    if (conversation == null) return;

    final repo = await ref.read(chatRepositoryProvider.future);
    await repo.clearMessagesIn(conversation.id);
    state = AsyncData(CoachChatState(conversation: conversation));
  }
}
