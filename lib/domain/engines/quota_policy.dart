/// Client-side quota policy mirror (actual enforcement is server-side in Milestone C).
class QuotaPolicy {
  final int dailyLimit;

  const QuotaPolicy({this.dailyLimit = 3});

  /// Whether the user can still use photo logging today.
  bool canUsePhoto(int usedToday) => usedToday < dailyLimit;

  /// How many photo uses remain today (never negative).
  int remaining(int usedToday) {
    final r = dailyLimit - usedToday;
    return r < 0 ? 0 : r;
  }

  /// When the quota resets — local midnight tonight.
  DateTime nextResetAt(DateTime now) {
    return DateTime(now.year, now.month, now.day + 1);
  }
}
