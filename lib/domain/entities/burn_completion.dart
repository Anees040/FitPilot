class BurnCompletion {
  final String id;
  final String activity;
  final int minutes;
  final int kcal;

  const BurnCompletion({
    required this.id,
    required this.activity,
    required this.minutes,
    required this.kcal,
  });

  factory BurnCompletion.fromMap(Map<String, dynamic> map) {
    return BurnCompletion(
      id: map['id'] as String,
      activity: map['activity'] as String,
      minutes: map['minutes'] as int,
      kcal: map['kcal'] as int,
    );
  }
}
