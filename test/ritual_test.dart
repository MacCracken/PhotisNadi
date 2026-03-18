import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/services/task_service.dart';

bool _adaptersRegistered = false;

void _registerAdapters() {
  if (_adaptersRegistered) return;
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(TaskPriorityAdapter());
  Hive.registerAdapter(RitualAdapter());
  Hive.registerAdapter(RitualFrequencyAdapter());
  Hive.registerAdapter(BoardAdapter());
  Hive.registerAdapter(BoardColumnAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(TagAdapter());
  _adaptersRegistered = true;
}

void main() {
  group('Ritual Reset Tests', () {
    test('daily ritual should reset on new day', () {
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440001',
        title: 'Daily Ritual',
        isCompleted: true,
        createdAt: DateTime(2024, 1, 1),
        resetTime: DateTime(2024, 1, 1, 23, 0),
        frequency: RitualFrequency.daily,
      );

      final now = DateTime(2024, 1, 2, 8, 0);
      final lastReset = ritual.resetTime ?? ritual.createdAt;
      final shouldReset = now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(shouldReset, isTrue);
    });

    test('daily ritual should not reset on same day', () {
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440002',
        title: 'Daily Ritual',
        isCompleted: true,
        createdAt: DateTime(2024, 1, 1),
        resetTime: DateTime(2024, 1, 1, 8, 0),
        frequency: RitualFrequency.daily,
      );

      final now = DateTime(2024, 1, 1, 20, 0);
      final lastReset = ritual.resetTime ?? ritual.createdAt;
      final shouldReset = now.day != lastReset.day ||
          now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(shouldReset, isFalse);
    });

    test('weekly ritual should reset on new week', () {
      final lastReset = DateTime(2024, 1, 1);
      final now = DateTime(2024, 1, 8);

      final nowWeek = Ritual.weekNumber(now);
      final lastWeek = Ritual.weekNumber(lastReset);
      final shouldReset = nowWeek != lastWeek || now.year != lastReset.year;

      expect(shouldReset, isTrue);
    });

    test('weekly ritual should not reset in same week', () {
      final lastReset = DateTime(2024, 1, 1);
      final now = DateTime(2024, 1, 3);

      final nowWeek = Ritual.weekNumber(now);
      final lastWeek = Ritual.weekNumber(lastReset);
      final shouldReset = nowWeek != lastWeek || now.year != lastReset.year;

      expect(shouldReset, isFalse);
    });

    test('monthly ritual should reset on new month', () {
      final lastReset = DateTime(2024, 1, 15);
      final now = DateTime(2024, 2, 1);

      final shouldReset =
          now.month != lastReset.month || now.year != lastReset.year;

      expect(shouldReset, isTrue);
    });

    test('monthly ritual should not reset in same month', () {
      final lastReset = DateTime(2024, 1, 1);
      final now = DateTime(2024, 1, 31);

      final shouldReset =
          now.month != lastReset.month || now.year != lastReset.year;

      expect(shouldReset, isFalse);
    });
  });

  // ── Ritual Model Tests ──

  group('Ritual Model Tests', () {
    test('markCompleted updates fields', () async {
      await setUpTestHive();
      _registerAdapters();
      final box = await Hive.openBox<Ritual>('rituals');
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440060',
        title: 'Test Ritual',
        createdAt: DateTime.now(),
      );
      await box.put(ritual.id, ritual);

      await ritual.markCompleted();

      expect(ritual.isCompleted, isTrue);
      expect(ritual.lastCompleted, isNotNull);
      expect(ritual.streakCount, 1);
      await tearDownTestHive();
    });

    test('resetIfNeeded resets daily ritual next day', () async {
      await setUpTestHive();
      _registerAdapters();
      final box = await Hive.openBox<Ritual>('rituals');
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440061',
        title: 'Daily Ritual',
        createdAt: yesterday,
        isCompleted: true,
        resetTime: yesterday,
        frequency: RitualFrequency.daily,
      );
      await box.put(ritual.id, ritual);

      await ritual.resetIfNeeded();

      expect(ritual.isCompleted, isFalse);
      expect(ritual.resetTime, isNotNull);
      await tearDownTestHive();
    });

    test('resetIfNeeded does not reset same day', () async {
      await setUpTestHive();
      _registerAdapters();
      final box = await Hive.openBox<Ritual>('rituals');
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440062',
        title: 'Daily Ritual',
        createdAt: DateTime.now(),
        isCompleted: true,
        resetTime: DateTime.now(),
        frequency: RitualFrequency.daily,
      );
      await box.put(ritual.id, ritual);

      await ritual.resetIfNeeded();

      expect(ritual.isCompleted, isTrue);
      await tearDownTestHive();
    });

    test('resetIfNeeded resets weekly ritual next week', () async {
      await setUpTestHive();
      _registerAdapters();
      final box = await Hive.openBox<Ritual>('rituals');
      // Use 15 days ago to guarantee crossing an ISO week boundary
      final lastWeek = DateTime.now().subtract(const Duration(days: 15));
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440063',
        title: 'Weekly Ritual',
        createdAt: lastWeek,
        isCompleted: true,
        resetTime: lastWeek,
        frequency: RitualFrequency.weekly,
      );
      await box.put(ritual.id, ritual);

      await ritual.resetIfNeeded();

      expect(ritual.isCompleted, isFalse);
      await tearDownTestHive();
    });

    test('resetIfNeeded resets monthly ritual next month', () async {
      await setUpTestHive();
      _registerAdapters();
      final box = await Hive.openBox<Ritual>('rituals');
      final lastMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month - 1,
        DateTime.now().day,
      );
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440064',
        title: 'Monthly Ritual',
        createdAt: lastMonth,
        isCompleted: true,
        resetTime: lastMonth,
        frequency: RitualFrequency.monthly,
      );
      await box.put(ritual.id, ritual);

      await ritual.resetIfNeeded();

      expect(ritual.isCompleted, isFalse);
      await tearDownTestHive();
    });

    test('weekNumber calculates correctly', () {
      expect(Ritual.weekNumber(DateTime(2026, 1, 1)), 1);
      expect(Ritual.weekNumber(DateTime(2026, 1, 8)), 2);
    });

    test('copyWith creates copy with overrides', () {
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440065',
        title: 'Original',
        createdAt: DateTime(2026, 1, 1),
      );
      final copy = ritual.copyWith(title: 'Updated');
      expect(copy.title, 'Updated');
      expect(copy.id, ritual.id);
    });
  });

  // ── Ritual Model Extended Tests ──

  group('Ritual Model Extended Tests', () {
    test('weekNumber returns correct ISO week', () {
      expect(Ritual.weekNumber(DateTime(2026, 1, 1)), greaterThan(0));
      final d1 = DateTime(2026, 3, 9);
      final d2 = DateTime(2026, 3, 13);
      expect(Ritual.weekNumber(d1), Ritual.weekNumber(d2));
    });

    test('copyWith preserves all fields', () {
      final original = Ritual(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Meditate',
        description: '10 min',
        isCompleted: true,
        createdAt: DateTime(2026, 1, 1),
        lastCompleted: DateTime(2026, 3, 1),
        streakCount: 5,
        frequency: RitualFrequency.weekly,
      );

      final copy = original.copyWith(title: 'Exercise');
      expect(copy.title, 'Exercise');
      expect(copy.description, '10 min');
      expect(copy.isCompleted, true);
      expect(copy.streakCount, 5);
      expect(copy.frequency, RitualFrequency.weekly);
    });

    test('constructor rejects empty title', () {
      expect(
        () => Ritual(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          title: '',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects invalid UUID', () {
      expect(
        () => Ritual(
          id: 'bad-id',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });

  // ── Ritual Mixin Extended Tests ──

  group('Ritual Mixin Extended Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('deleteRitual removes ritual', () async {
      final ritual = await taskService.addRitual('Temp');
      expect(ritual, isNotNull);

      final result = await taskService.deleteRitual(ritual!.id);
      expect(result, true);
      expect(taskService.rituals.any((r) => r.id == ritual.id), false);
    });

    test('toggleRitualCompletion marks complete', () async {
      final ritual = await taskService.addRitual('Toggle');
      expect(ritual, isNotNull);

      await taskService.toggleRitualCompletion(ritual!.id);
      var loaded = taskService.rituals.firstWhere((r) => r.id == ritual.id);
      expect(loaded.isCompleted, true);
      expect(loaded.streakCount, 1);

      await taskService.toggleRitualCompletion(ritual.id);
      loaded = taskService.rituals.firstWhere((r) => r.id == ritual.id);
      expect(loaded.isCompleted, false);
    });

    test('toggleRitualCompletion returns false for non-existent', () async {
      expect(await taskService.toggleRitualCompletion('nonexistent'), false);
    });

    test('checkRitualResets resets completed daily rituals', () async {
      final ritual = await taskService.addRitual('Daily Reset');
      expect(ritual, isNotNull);

      ritual!.isCompleted = true;
      ritual.resetTime = DateTime.now().subtract(const Duration(days: 1));
      await taskService.updateRitual(ritual);

      await taskService.checkRitualResets();

      final loaded = taskService.rituals.firstWhere((r) => r.id == ritual.id);
      expect(loaded.isCompleted, false);
    });

    test('addRitual with description', () async {
      final ritual =
          await taskService.addRitual('Described', description: 'Some details');
      expect(ritual, isNotNull);
      expect(ritual!.description, 'Some details');
    });
  });

  // ── Undo/Restore Tests ──

  group('Undo/Restore Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('restoreTask re-adds deleted task with original fields', () async {
      final task = await taskService.addTask('Deletable',
          description: 'desc', priority: TaskPriority.high);
      expect(task, isNotNull);

      await taskService.deleteTask(task!.id);
      expect(taskService.tasks.where((t) => t.id == task.id).length, 0);

      await taskService.restoreTask(task);
      expect(taskService.tasks.where((t) => t.id == task.id).length, 1);
      final restored = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(restored.title, 'Deletable');
      expect(restored.description, 'desc');
      expect(restored.priority, TaskPriority.high);
    });

    test('restoreRitual re-adds deleted ritual', () async {
      final ritual = await taskService.addRitual('Deletable Ritual',
          description: 'ritual desc');
      expect(ritual, isNotNull);

      await taskService.deleteRitual(ritual!.id);
      expect(taskService.rituals.where((r) => r.id == ritual.id).length, 0);

      await taskService.restoreRitual(ritual);
      expect(taskService.rituals.where((r) => r.id == ritual.id).length, 1);
      final restored = taskService.rituals.firstWhere((r) => r.id == ritual.id);
      expect(restored.title, 'Deletable Ritual');
      expect(restored.description, 'ritual desc');
    });

    test('restored items appear in repository listings', () async {
      final task = await taskService.addTask('Listed');
      expect(task, isNotNull);

      await taskService.deleteTask(task!.id);
      expect(taskService.tasks.length, 0);

      await taskService.restoreTask(task);
      expect(taskService.tasks.length, 1);
    });

    test('restore updates listeners', () async {
      int notifyCount = 0;
      taskService.addListener(() => notifyCount++);

      final task = await taskService.addTask('Notify');
      expect(task, isNotNull);
      final countAfterAdd = notifyCount;

      await taskService.restoreTask(task!);
      expect(notifyCount, greaterThan(countAfterAdd));
    });
  });
}
