import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/features/plan/presentation/widgets/burn_log_sheet.dart';

const _option = BurnOption(
  activity: 'Running',
  minutes: 30,
  kcal: 300,
  met: 7.0,
);

void main() {
  testWidgets('prefills the suggested duration and shows the derived kcal', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('30'), findsOneWidget);
    // 7 x 3.5 x 70 / 200 x 30 = 257.25 -> 257
    expect(find.textContaining('257'), findsWidgets);
  });

  testWidgets('stepping the duration down recalculates the kcal', (
    tester,
  ) async {
    await _pumpSheet(tester);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(find.text('25'), findsOneWidget);
    // 8.575 x 25 = 214.4 -> 214, and the old value is gone.
    expect(find.textContaining('214'), findsWidgets);
    expect(find.textContaining('257'), findsNothing);
  });

  testWidgets('stepping up recalculates the kcal', (tester) async {
    await _pumpSheet(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('35'), findsOneWidget);
    // 8.575 x 35 = 300.1 -> 300
    expect(find.textContaining('300'), findsWidgets);
  });

  testWidgets('logging a session sends the chosen minutes to the notifier', (
    tester,
  ) async {
    final notifier = _RecordingBurnNotifier();
    await _pumpSheet(tester, notifier: notifier);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Log this'));
    await tester.pumpAndSettle();

    expect(notifier.loggedMinutes, 25);
    expect(notifier.loggedKcal, 214);
    expect(notifier.loggedActivity, 'Running');
  });

  testWidgets('does not call the legacy full-surplus markDone path', (
    tester,
  ) async {
    final notifier = _RecordingBurnNotifier();
    await _pumpSheet(tester, notifier: notifier);

    await tester.tap(find.textContaining('Log this'));
    await tester.pumpAndSettle();

    expect(notifier.markDoneCalls, 0);
    expect(notifier.loggedMinutes, 30);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  _RecordingBurnNotifier? notifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _FakeProfileNotifier()),
        burnPlanProvider.overrideWith(
          () => notifier ?? _RecordingBurnNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.getLightTheme(),
        home: const Scaffold(body: BurnLogSheet(option: _option)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<Profile> build() async => Profile(
    name: 'Anees',
    weightKg: 70.0,
    heightCm: 175,
    age: 25,
    updatedAt: DateTime(2026, 1, 1),
  );
}

class _RecordingBurnNotifier extends BurnPlanNotifier {
  int? loggedMinutes;
  int? loggedKcal;
  String? loggedActivity;
  int markDoneCalls = 0;

  @override
  Future<BurnPlanState> build() async => BurnPlanState(
    frame: BurnPlanFrame.burnToday,
    kcalToBurnOrEat: 500,
    options: const [_option],
    targetDate: DateTime(2026, 1, 1),
  );

  @override
  Future<void> markDone(BurnOption option) async {
    markDoneCalls++;
  }

  @override
  Future<void> logBurn(BurnOption option, {int? minutes, int? kcal}) async {
    loggedActivity = option.activity;
    loggedMinutes = minutes;
    loggedKcal = kcal;
  }
}
