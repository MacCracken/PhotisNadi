import 'package:hive/hive.dart';

part 'ritual.g.dart';

/// Represents a daily ritual or habit with completion tracking.
@HiveType(typeId: 3)
class Ritual extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  String? description;
  
  @HiveField(3)
  bool isCompleted;
  
  @HiveField(4)
  DateTime createdAt;
  
  @HiveField(5)
  DateTime? lastCompleted;
  
  @HiveField(6)
  DateTime? resetTime;
  
  @HiveField(7)
  int streakCount;
  
  @HiveField(8)
  RitualFrequency frequency;

  Ritual({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    required this.createdAt,
    this.lastCompleted,
    this.resetTime,
    this.streakCount = 0,
    this.frequency = RitualFrequency.daily,
  });

  void markCompleted() {
    isCompleted = true;
    lastCompleted = DateTime.now();
    streakCount++;
    save();
  }

  void resetIfNeeded() {
    final now = DateTime.now();
    final lastReset = resetTime ?? createdAt;

    bool shouldReset = false;

    switch (frequency) {
      case RitualFrequency.daily:
        shouldReset = now.day != lastReset.day ||
            now.month != lastReset.month ||
            now.year != lastReset.year;
        break;
      case RitualFrequency.weekly:
        // Reset if we're in a different ISO week
        final nowWeek = weekNumber(now);
        final lastWeek = weekNumber(lastReset);
        shouldReset = nowWeek != lastWeek || now.year != lastReset.year;
        break;
      case RitualFrequency.monthly:
        shouldReset = now.month != lastReset.month ||
            now.year != lastReset.year;
        break;
    }

    if (shouldReset && isCompleted) {
      isCompleted = false;
      resetTime = now;
      save();
    }
  }

  static int weekNumber(DateTime date) {
    final jan1 = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(jan1).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Ritual copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? lastCompleted,
    DateTime? resetTime,
    int? streakCount,
    RitualFrequency? frequency,
  }) {
    return Ritual(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      lastCompleted: lastCompleted ?? this.lastCompleted,
      resetTime: resetTime ?? this.resetTime,
      streakCount: streakCount ?? this.streakCount,
      frequency: frequency ?? this.frequency,
    );
  }
}

@HiveType(typeId: 4)
enum RitualFrequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  monthly,
}