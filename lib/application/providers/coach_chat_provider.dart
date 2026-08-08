import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/protein_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/data/ai/coach_service.dart';
import 'package:fitpilot/data/repositories/chat_repository.dart';
import 'package:fitpilot/domain/entities/chat_message.dart';

/// Exposes the ChatRepository. No guest guard: `chat_messages` is local-only,
/// so nothing it writes is ever queued for sync.
final chatRepositoryProvider = FutureProvider<ChatRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ChatRepository(db);
});

/// Swapped in tests so the provider can be driven without a network.
final coachServiceProvider = Provider<CoachService>((ref) => CoachService());

/// The coach conversation plus its in-flight state.
class CoachChatState {
  final List<ChatMessage> messages;

  /// True while waiting on the server — drives the typing indicator.
  final bool isTyping;

  /// User-ready failure text for the last send, or null.
  final String? error;

  const CoachChatState({
    this.messages = const [],
    this.isTyping = false,
    this.error,
  });

  bool get isEmpty => messages.isEmpty;

  CoachChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    String? error,
    bool clearError = false,
  }) {
    return CoachChatState(
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
    return CoachChatState(messages: await repo.latest());
  }

  /// Sends [text] and appends the reply.
  ///
  /// The user's bubble is written immediately so the conversation feels
  /// responsive; a failure leaves it in place and surfaces [CoachChatState.error]
  /// so [retry] can re-send without duplicating it.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final current = state.valueOrNull ?? const CoachChatState();
    if (current.isTyping) return;

    final message = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    final repo = await ref.read(chatRepositoryProvider.future);
    await repo.insert(message);

    final withUser = [...current.messages, message];
    state = AsyncData(
      current.copyWith(messages: withUser, isTyping: true, clearError: true),
    );

    await _ask(withUser);
  }

  /// Re-sends the existing transcript after a failure. The user's message is
  /// already in the list, so nothing is appended.
  Future<void> retry() async {
    final current = state.valueOrNull;
    if (current == null || current.messages.isEmpty || current.isTyping) return;

    state = AsyncData(current.copyWith(isTyping: true, clearError: true));
    await _ask(current.messages);
  }

  Future<void> _ask(List<ChatMessage> history) async {
    try {
      final reply = await ref.read(coachServiceProvider).send(
        history: history,
        context: await _buildContext(),
      );

      final answer = ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.model,
        content: reply,
        createdAt: DateTime.now(),
      );

      final repo = await ref.read(chatRepositoryProvider.future);
      await repo.insert(answer);

      state = AsyncData(
        CoachChatState(messages: [...history, answer], isTyping: false),
      );
    } catch (e) {
      state = AsyncData(
        CoachChatState(
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

  /// Wipes the transcript on disk and in memory.
  Future<void> clear() async {
    final repo = await ref.read(chatRepositoryProvider.future);
    await repo.clearAll();
    state = const AsyncData(CoachChatState());
  }
}
