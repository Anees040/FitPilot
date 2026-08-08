import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/engines/notification_feed_engine.dart';
import 'package:fitpilot/domain/entities/app_notification.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';

const _engine = NotificationFeedEngine();

/// Everything on, no quiet hours — so each test can switch off exactly the one
/// thing it is about.
const _allOn = NotificationPreferences(
  mealRemindersEnabled: true,
  burnRemindersEnabled: true,
  streakRiskEnabled: true,
  milestonesEnabled: true,
  programRemindersEnabled: true,
  weighInEnabled: true,
  waterRemindersEnabled: true,
);

DayStatus _status({int toBurn = 0}) => DayStatus(
  total: KcalRange(1500, 1700),
  burnedKcal: 0,
  net: KcalRange(1500, 1700),
  toBurn: toBurn,
  state: toBurn > 0 ? DayState.unburned : DayState.cleared,
  wiggleRoomKcal: 300,
);

StreakState _streak({
  StreakPhase phase = StreakPhase.safe,
  int current = 0,
  DateTime? deadline,
  int stillToBurn = 0,
}) => StreakState(
  phase: phase,
  currentStreak: current,
  graceDeadline: deadline,
  kcalStillToBurn: stillToBurn,
);

NotificationContext _ctx({
  required DateTime now,
  NotificationPreferences prefs = _allOn,
  DayStatus? status,
  StreakState? streak,
  int loggedMeals = 0,
  String? program,
  bool programDone = false,
  DateTime? lastWeighIn,
}) => NotificationContext(
  now: now,
  prefs: prefs,
  dayStatus: status ?? _status(),
  streak: streak ?? _streak(),
  loggedMealsToday: loggedMeals,
  todaysProgramSession: program,
  programSessionDone: programDone,
  lastWeighIn: lastWeighIn,
);

Set<NotificationCategory> _categories(List<AppNotification> list) =>
    list.map((n) => n.category).toSet();

void main() {
  group('global controls', () {
    test('global mute silences everything', () {
      final out = _engine.generate(
        _ctx(
          now: DateTime(2026, 8, 10, 19),
          prefs: _allOn.copyWith(globalMute: true),
          status: _status(toBurn: 400),
        ),
      );
      expect(out, isEmpty);
    });

    test('quiet hours silence everything inside the window', () {
      final prefs = _allOn.copyWith(
        quietHoursEnabled: true,
        quietFrom: '22:00',
        quietTo: '07:00',
      );
      // 23:30 is inside an overnight window.
      expect(
        _engine.generate(
          _ctx(now: DateTime(2026, 8, 10, 23, 30), prefs: prefs),
        ),
        isEmpty,
      );
      // 05:00 is still inside it, on the other side of midnight.
      expect(
        _engine.generate(_ctx(now: DateTime(2026, 8, 10, 5), prefs: prefs)),
        isEmpty,
      );
    });

    test('an overnight quiet window leaves daytime alone', () {
      final prefs = _allOn.copyWith(
        quietHoursEnabled: true,
        quietFrom: '22:00',
        quietTo: '07:00',
      );
      final out = _engine.generate(
        _ctx(
          now: DateTime(2026, 8, 10, 19),
          prefs: prefs,
          status: _status(toBurn: 400),
        ),
      );
      expect(out, isNotEmpty);
    });

    test('a same-day quiet window is handled too', () {
      final prefs = _allOn.copyWith(
        quietHoursEnabled: true,
        quietFrom: '13:00',
        quietTo: '15:00',
      );
      expect(
        _engine.generate(_ctx(now: DateTime(2026, 8, 10, 14), prefs: prefs)),
        isEmpty,
      );
    });
  });

  group('per-category toggles', () {
    test('each category is suppressed by its own switch', () {
      final evening = DateTime(2026, 8, 10, 19);
      final withBurn = _ctx(prefs: _allOn, now: evening, status: _status(toBurn: 400));
      expect(_categories(_engine.generate(withBurn)),
          contains(NotificationCategory.burnReminder));

      final off = _ctx(
        now: evening,
        prefs: _allOn.copyWith(burnRemindersEnabled: false),
        status: _status(toBurn: 400),
      );
      expect(_categories(_engine.generate(off)),
          isNot(contains(NotificationCategory.burnReminder)));
    });
  });

  group('meal reminders', () {
    test('fire inside a meal window when nothing is logged', () {
      final out = _engine.generate(_ctx(now: DateTime(2026, 8, 10, 8)));
      expect(_categories(out), contains(NotificationCategory.mealReminder));
    });

    test('stay quiet between meal windows', () {
      final out = _engine.generate(_ctx(now: DateTime(2026, 8, 10, 16)));
      expect(_categories(out), isNot(contains(NotificationCategory.mealReminder)));
    });

    test('stop once three meals are logged', () {
      final out = _engine.generate(
        _ctx(now: DateTime(2026, 8, 10, 19), loggedMeals: 3),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.mealReminder)));
    });
  });

  group('burn reminders', () {
    test('fire in the evening when a surplus is open', () {
      final out = _engine.generate(
        _ctx(now: DateTime(2026, 8, 10, 19), status: _status(toBurn: 320)),
      );
      final burn = out.firstWhere(
        (n) => n.category == NotificationCategory.burnReminder,
      );
      expect(burn.title, contains('320'));
      expect(burn.payload, '/plan');
    });

    test('stay silent when there is nothing left to burn', () {
      final out = _engine.generate(
        _ctx(now: DateTime(2026, 8, 10, 19), status: _status(toBurn: 0)),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.burnReminder)));
    });

    test('do not fire at breakfast', () {
      final out = _engine.generate(
        _ctx(now: DateTime(2026, 8, 10, 8), status: _status(toBurn: 320)),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.burnReminder)));
    });
  });

  group('streak risk', () {
    test('fires inside the final 8 hours of grace', () {
      final now = DateTime(2026, 8, 10, 19);
      final out = _engine.generate(
        _ctx(
          now: now,
          streak: _streak(
            phase: StreakPhase.overPending,
            current: 12,
            deadline: now.add(const Duration(hours: 4)),
            stillToBurn: 210,
          ),
        ),
      );
      final risk = out.firstWhere(
        (n) => n.category == NotificationCategory.streakRisk,
      );
      expect(risk.title, contains('12-day'));
      expect(risk.body, contains('210'));
    });

    test('stays quiet while the deadline is far away', () {
      final now = DateTime(2026, 8, 10, 19);
      final out = _engine.generate(
        _ctx(
          now: now,
          streak: _streak(
            phase: StreakPhase.overPending,
            current: 12,
            deadline: now.add(const Duration(hours: 20)),
          ),
        ),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.streakRisk)));
    });

    test('stays quiet when the streak is not at risk', () {
      final out = _engine.generate(
        _ctx(
          now: DateTime(2026, 8, 10, 19),
          streak: _streak(phase: StreakPhase.safe, current: 12),
        ),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.streakRisk)));
    });
  });

  group('milestones', () {
    test('celebrate whole weeks only', () {
      for (final streak in [7, 14, 28]) {
        final out = _engine.generate(
          _ctx(now: DateTime(2026, 8, 10, 9), streak: _streak(current: streak)),
        );
        expect(_categories(out), contains(NotificationCategory.milestone),
            reason: '$streak days should be a milestone');
      }
    });

    test('ignore days that are not a whole week', () {
      final out = _engine.generate(
        _ctx(now: DateTime(2026, 8, 10, 9), streak: _streak(current: 9)),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.milestone)));
    });
  });

  group('programme and weigh-in', () {
    test('a pending session is announced', () {
      final out = _engine.generate(
        _ctx(now: DateTime(2026, 8, 10, 9), program: 'Push Day A'),
      );
      final entry = out.firstWhere(
        (n) => n.category == NotificationCategory.programDay,
      );
      expect(entry.title, contains('Push Day A'));
    });

    test('a finished session is not', () {
      final out = _engine.generate(
        _ctx(
          now: DateTime(2026, 8, 10, 9),
          program: 'Push Day A',
          programDone: true,
        ),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.programDay)));
    });

    test('weigh-in fires on the chosen weekday only', () {
      // 2026-08-10 is a Monday.
      final monday = DateTime(2026, 8, 10, 9);
      expect(
        _categories(_engine.generate(_ctx(now: monday))),
        contains(NotificationCategory.weighIn),
      );

      final tuesday = DateTime(2026, 8, 11, 9);
      expect(
        _categories(_engine.generate(_ctx(now: tuesday))),
        isNot(contains(NotificationCategory.weighIn)),
      );
    });

    test('weigh-in is skipped when already weighed today', () {
      final monday = DateTime(2026, 8, 10, 9);
      final out = _engine.generate(
        _ctx(now: monday, lastWeighIn: DateTime(2026, 8, 10, 7)),
      );
      expect(_categories(out), isNot(contains(NotificationCategory.weighIn)));
    });
  });

  test('ids are deterministic, so repeat runs cannot duplicate', () {
    final now = DateTime(2026, 8, 10, 19);
    final first = _engine.generate(_ctx(now: now, status: _status(toBurn: 300)));
    final second = _engine.generate(_ctx(now: now, status: _status(toBurn: 300)));

    expect(first.map((n) => n.id).toList(), second.map((n) => n.id).toList());
    expect(first.map((n) => n.id).toSet().length, first.length,
        reason: 'ids must be unique within a single run');
  });

  test('every generated notification carries a title and a body', () {
    final out = _engine.generate(
      _ctx(
        now: DateTime(2026, 8, 10, 19),
        status: _status(toBurn: 300),
        streak: _streak(current: 14),
        program: 'Leg Day',
      ),
    );

    expect(out, isNotEmpty);
    for (final n in out) {
      expect(n.title.trim(), isNotEmpty);
      expect(n.body.trim(), isNotEmpty);
    }
  });
}
