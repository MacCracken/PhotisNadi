import 'package:hive/hive.dart';
import '../common/validators.dart';

part 'ritual.g.dart';

/// Represents a daily ritual or habit with completion tracking.
@HiveType(typeId: 3)
class Ritual extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  bool isCompleted;

  @HiveField(4)
  final DateTime createdAt;

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
  }) {
    if (!isValidUuid(id)) {
      throw ArgumentError('Invalid ritual ID: must be a valid UUID');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Ritual title cannot be empty');
    }
  }

  Future<void> markCompleted() async {
    isCompleted = true;
    lastCompleted = DateTime.now();
    streakCount++;
    await save();
  }

  Future<void> resetIfNeeded() async {
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
        shouldReset =
            now.month != lastReset.month || now.year != lastReset.year;
        break;
    }

    if (shouldReset) {
      if (isCompleted) {
        // User completed during the period — reset for next period, keep streak
        isCompleted = false;
      } else {
        // User did NOT complete during the period — streak is broken
        streakCount = 0;
      }
      resetTime = now;
      await save();
    }
  }

  /// ISO 8601 week number. Uses Thursday-based calculation:
  /// the week containing the year's first Thursday is week 1.
  static int weekNumber(DateTime date) {
    // Find the Thursday of this date's week
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
    final jan1 = DateTime(thursday.year, 1, 1);
    final dayOfYear = thursday.difference(jan1).inDays + 1;
    return ((dayOfYear - 1) / 7).floor() + 1;
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
