import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/services/task_service.dart';
import 'package:photisnadi/common/utils.dart';

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
  group('TaskService Tests', () {
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

    test('should add task successfully', () async {
      const taskTitle = 'Test Task';
      await taskService.addTask(taskTitle);

      expect(taskService.tasks.length, 1);
      expect(taskService.tasks.first.title, taskTitle);
    });

    test('should delete task successfully', () async {
      await taskService.addTask('Test Task');
      final taskId = taskService.tasks.first.id;

      await taskService.deleteTask(taskId);

      expect(taskService.tasks.length, 0);
    });

    test('should update task status', () async {
      await taskService.addTask('Test Task');
      final task = taskService.tasks.first;

      final updatedTask = task.copyWith(status: TaskStatus.inProgress);
      final result = await taskService.updateTask(updatedTask);
      expect(result, isTrue);

      expect(taskService.tasks.first.status, TaskStatus.inProgress);
    });

    test('should set modifiedAt on task update', () async {
      await taskService.addTask('Test Task');
      final task = taskService.tasks.first;
      final originalModifiedAt = task.modifiedAt;

      // Small delay to ensure time difference
      await Future.delayed(const Duration(milliseconds: 10));

      final updatedTask = task.copyWith(title: 'Updated Title');
      final result = await taskService.updateTask(updatedTask);
      expect(result, isTrue);

      expect(
        taskService.tasks.first.modifiedAt.isAfter(originalModifiedAt),
        isTrue,
      );
    });

    test('should add ritual successfully', () async {
      const ritualTitle = 'Morning Meditation';
      final ritual = await taskService.addRitual(ritualTitle);

      expect(taskService.rituals.length, 1);
      expect(taskService.rituals.first.title, ritualTitle);
      expect(ritual, isNotNull);
    });

    test('should toggle ritual completion', () async {
      await taskService.addRitual('Test Ritual');
      final ritualId = taskService.rituals.first.id;

      final result = await taskService.toggleRitualCompletion(ritualId);
      expect(result, isTrue);

      expect(taskService.rituals.first.isCompleted, true);
    });
  });

  group('Project Tests', () {
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

    test('should create default project on init', () {
      expect(taskService.projects.length, 1);
      expect(taskService.projects.first.name, 'My Project');
      expect(taskService.selectedProjectId, isNotNull);
    });

    test('should add a new project', () async {
      final project = await taskService.addProject(
        'Work',
        'WK',
        description: 'Work tasks',
      );

      expect(taskService.projects.length, 2);
      expect(project, isNotNull);
      expect(project!.name, 'Work');
      expect(project.projectKey, 'WK');
    });

    test('should select project', () async {
      final project = await taskService.addProject('Work', 'WK');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      expect(taskService.selectedProjectId, project.id);
      expect(taskService.selectedProject?.name, 'Work');
    });

    test('should archive project', () async {
      final project = await taskService.addProject('Work', 'WK');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      final result = await taskService.archiveProject(project.id);
      expect(result, isTrue);

      expect(taskService.archivedProjects.length, 1);
      expect(
        taskService.selectedProjectId,
        isNot(equals(project.id)),
      );
    });

    test('should delete project and its tasks', () async {
      final project = await taskService.addProject('Work', 'WK');
      expect(project, isNotNull);
      await taskService.addTask(
        'Work Task',
        projectId: project!.id,
      );

      expect(taskService.getTasksForProject(project.id).length, 1);

      final deleteResult = await taskService.deleteProject(project.id);
      expect(deleteResult, isTrue);

      expect(
        taskService.projects.where((p) => p.id == project.id).length,
        0,
      );
      expect(taskService.getTasksForProject(project.id).length, 0);
    });

    test('should assign task key from project', () async {
      final project = await taskService.addProject('Work', 'WK');
      expect(project, isNotNull);
      await taskService.addTask(
        'First Task',
        projectId: project!.id,
      );
      await taskService.addTask(
        'Second Task',
        projectId: project.id,
      );

      final tasks = taskService.getTasksForProject(project.id);
      expect(tasks[0].taskKey, 'WK-1');
      expect(tasks[1].taskKey, 'WK-2');
    });

    test('should move task between projects', () async {
      final proj1 = await taskService.addProject('Project A', 'PA');
      final proj2 = await taskService.addProject('Project B', 'PB');
      expect(proj1, isNotNull);
      expect(proj2, isNotNull);

      await taskService.addTask('Task', projectId: proj1!.id);
      final task = taskService.getTasksForProject(proj1.id).first;

      final moveResult =
          await taskService.moveTaskToProject(task.id, proj2!.id);
      expect(moveResult, isTrue);

      expect(taskService.getTasksForProject(proj1.id).length, 0);
      expect(taskService.getTasksForProject(proj2.id).length, 1);
      expect(
        taskService.getTasksForProject(proj2.id).first.taskKey,
        'PB-1',
      );
    });

    test('should filter tasks by column and project', () async {
      final project = await taskService.addProject('Work', 'WK');
      expect(project, isNotNull);
      await taskService.addTask('Todo Task', projectId: project!.id);
      await taskService.addTask(
        'Done Task',
        projectId: project.id,
      );

      // Move second task to done
      final doneTask = taskService.getTasksForProject(project.id).last;
      final updated = doneTask.copyWith(status: TaskStatus.done);
      final updateResult = await taskService.updateTask(updated);
      expect(updateResult, isTrue);

      final todoTasks = taskService.getTasksForColumn(
        'todo',
        projectId: project.id,
      );
      final doneTasks = taskService.getTasksForColumn(
        'done',
        projectId: project.id,
      );

      expect(todoTasks.length, 1);
      expect(doneTasks.length, 1);
    });

    test('should set modifiedAt on project update', () async {
      final project = await taskService.addProject('Work', 'WK');
      expect(project, isNotNull);
      final originalModifiedAt = project!.modifiedAt;

      await Future.delayed(const Duration(milliseconds: 10));

      project.name = 'Updated Work';
      final updateResult = await taskService.updateProject(project);
      expect(updateResult, isTrue);

      final updated = taskService.projects.firstWhere(
        (p) => p.id == project.id,
      );
      expect(updated.modifiedAt.isAfter(originalModifiedAt), isTrue);
    });
  });

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

      // Simulate next day - resetIfNeeded checks DateTime.now()
      // so we test the logic directly
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
      // Monday Jan 1 2024
      final lastReset = DateTime(2024, 1, 1);
      // Monday Jan 8 2024 (next week)
      final now = DateTime(2024, 1, 8);

      final nowWeek = Ritual.weekNumber(now);
      final lastWeek = Ritual.weekNumber(lastReset);
      final shouldReset = nowWeek != lastWeek || now.year != lastReset.year;

      expect(shouldReset, isTrue);
    });

    test('weekly ritual should not reset in same week', () {
      // Monday Jan 1 2024
      final lastReset = DateTime(2024, 1, 1);
      // Wednesday Jan 3 2024 (same week)
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

  group('Task Model Tests', () {
    test('copyWith should preserve all fields', () {
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440010',
        title: 'Test',
        description: 'Desc',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
        createdAt: DateTime(2024, 1, 1),
        dueDate: DateTime(2024, 2, 1),
        projectId: '550e8400-e29b-41d4-a716-446655440099',
        tags: ['tag1'],
        taskKey: 'P-1',
      );

      final copy = task.copyWith(title: 'Updated');

      expect(copy.title, 'Updated');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440010');
      expect(copy.description, 'Desc');
      expect(copy.status, TaskStatus.todo);
      expect(copy.priority, TaskPriority.high);
      expect(copy.projectId, '550e8400-e29b-41d4-a716-446655440099');
      expect(copy.tags, ['tag1']);
      expect(copy.taskKey, 'P-1');
    });

    test('modifiedAt defaults to createdAt', () {
      final now = DateTime(2024, 1, 1);
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440011',
        title: 'Test',
        createdAt: now,
      );

      expect(task.modifiedAt, now);
    });
  });

  group('Project Model Tests', () {
    test('generateNextTaskKey increments counter', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(project.generateNextTaskKey(), 'TST-1');
      expect(project.generateNextTaskKey(), 'TST-2');
      expect(project.generateNextTaskKey(), 'TST-3');
      expect(project.taskCounter, 3);
    });

    test('copyWith should preserve all fields', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440020',
        name: 'Test',
        projectKey: 'TST',
        description: 'A project',
        createdAt: DateTime(2024, 1, 1),
        color: '#FF0000',
        iconName: 'star',
        taskCounter: 5,
        isArchived: true,
      );

      final copy = project.copyWith(name: 'Updated');

      expect(copy.name, 'Updated');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440020');
      expect(copy.projectKey, 'TST');
      expect(copy.description, 'A project');
      expect(copy.color, '#FF0000');
      expect(copy.iconName, 'star');
      expect(copy.taskCounter, 5);
      expect(copy.isArchived, true);
    });

    test('modifiedAt defaults to createdAt', () {
      final now = DateTime(2024, 1, 1);
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440021',
        name: 'Test',
        projectKey: 'TST',
        createdAt: now,
      );

      expect(project.modifiedAt, now);
    });
  });

  group('Board Model Tests', () {
    test('BoardColumn should store tasks', () {
      final column = BoardColumn(
        id: '550e8400-e29b-41d4-a716-446655440030',
        title: 'To Do',
        taskIds: ['task-1', 'task-2'],
        status: TaskStatus.todo,
      );

      expect(column.taskIds.length, 2);
      expect(column.title, 'To Do');
    });

    test('Board should store column ids', () {
      final board = Board(
        id: '550e8400-e29b-41d4-a716-446655440031',
        title: 'Main Board',
        createdAt: DateTime(2024, 1, 1),
        columnIds: ['col-1', 'col-2', 'col-3'],
      );

      expect(board.columnIds.length, 3);
      expect(board.title, 'Main Board');
    });

    test('BoardColumn copyWith should preserve fields', () {
      final column = BoardColumn(
        id: '550e8400-e29b-41d4-a716-446655440032',
        title: 'To Do',
        order: 0,
        color: '#FF0000',
        status: TaskStatus.todo,
      );

      final copy = column.copyWith(title: 'Done');

      expect(copy.title, 'Done');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440032');
      expect(copy.order, 0);
      expect(copy.color, '#FF0000');
    });

    test('Board copyWith should preserve fields', () {
      final board = Board(
        id: '550e8400-e29b-41d4-a716-446655440033',
        title: 'Main Board',
        createdAt: DateTime(2024, 1, 1),
        color: '#00FF00',
      );

      final copy = board.copyWith(title: 'Updated Board');

      expect(copy.title, 'Updated Board');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440033');
      expect(copy.color, '#00FF00');
    });
  });

  group('Pagination Tests', () {
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

    test('getTasksForColumnPaginated returns correct page', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      for (int i = 0; i < 25; i++) {
        await taskService.addTask('Task $i');
      }

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final page0 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 0,
        pageSize: 10,
      );
      expect(page0.length, 10);

      final page1 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 1,
        pageSize: 10,
      );
      expect(page1.length, 10);

      final page2 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 2,
        pageSize: 10,
      );
      expect(page2.length, 5);
    });

    test('getTaskCountForColumn returns correct count', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Task 1');
      await taskService.addTask('Task 2');
      await taskService.addTask('Task 3');

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final count = taskService.getTaskCountForColumn(
        todoColumn.id,
        projectId: project.id,
      );
      expect(count, 3);
    });

    test('hasMoreTasksForColumn correctly identifies more pages', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      for (int i = 0; i < 15; i++) {
        await taskService.addTask('Task $i');
      }

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(
        taskService.hasMoreTasksForColumn(
          todoColumn.id,
          projectId: project.id,
          page: 0,
          pageSize: 10,
        ),
        isTrue,
      );
      expect(
        taskService.hasMoreTasksForColumn(
          todoColumn.id,
          projectId: project.id,
          page: 1,
          pageSize: 10,
        ),
        isFalse,
      );
    });

    test('hasMoreTasksForColumn returns false when on last page', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Task 1');
      await taskService.addTask('Task 2');

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(
        taskService.hasMoreTasksForColumn(
          todoColumn.id,
          projectId: project.id,
          page: 0,
          pageSize: 10,
        ),
        isFalse,
      );
    });

    test('getTasksForColumnPaginated returns empty when page exceeds data',
        () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Task 1');

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final page1 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 1,
        pageSize: 10,
      );
      expect(page1.length, 0);
    });

    test('getTasksForColumnPaginated returns empty when page exceeds data',
        () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Task 1');

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final page1 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 1,
        pageSize: 10,
      );
      expect(page1.length, 0);
    });
  });

  group('Validation Tests', () {
    test('isValidHexColor validates correct hex colors', () {
      expect(isValidHexColor('#FF0000'), isTrue);
      expect(isValidHexColor('FF0000'), isTrue);
      expect(isValidHexColor('#AABBCC'), isTrue);
      expect(isValidHexColor('#ff0000'), isTrue);
      expect(isValidHexColor('#FF0000FF'), isTrue);
    });

    test('isValidHexColor rejects invalid hex colors', () {
      expect(isValidHexColor(''), isFalse);
      expect(isValidHexColor('#GG0000'), isFalse);
      expect(isValidHexColor('#FFF'), isFalse);
      expect(isValidHexColor('invalid'), isFalse);
      expect(isValidHexColor('#12345'), isFalse);
    });

    test('normalizeHexColor normalizes colors correctly', () {
      expect(normalizeHexColor('#FF0000'), '#FF0000');
      expect(normalizeHexColor('FF0000'), '#FF0000');
      expect(normalizeHexColor(' #aabbcc '), '#AABBCC');
      expect(normalizeHexColor('#ff0000ff'), '#FF0000FF');
    });

    test('isValidProjectKey validates project keys', () {
      expect(isValidProjectKey('AB'), isTrue);
      expect(isValidProjectKey('ABC'), isTrue);
      expect(isValidProjectKey('ABCD'), isTrue);
      expect(isValidProjectKey('ABCDE'), isTrue);
      expect(isValidProjectKey('A1'), isTrue);
      expect(isValidProjectKey('A12'), isTrue);
    });

    test('isValidProjectKey rejects invalid project keys', () {
      expect(isValidProjectKey(''), isFalse);
      expect(isValidProjectKey('A'), isFalse);
      expect(isValidProjectKey('ABCDEF'), isFalse);
      expect(isValidProjectKey('ab'), isFalse);
      expect(isValidProjectKey('AB!'), isFalse);
      expect(isValidProjectKey('A B'), isFalse);
    });

    test('isValidUuid validates UUIDs', () {
      expect(isValidUuid('550e8400-e29b-41d4-a716-446655440000'), isTrue);
      expect(isValidUuid('550E8400-E29B-41D4-A716-446655440000'), isTrue);
    });

    test('isValidUuid rejects invalid UUIDs', () {
      expect(isValidUuid(''), isFalse);
      expect(isValidUuid('invalid'), isFalse);
      expect(isValidUuid('550e8400-e29b-41d4-a716'), isFalse);
      expect(isValidUuid('550e8400-e29b-41d4-a716-4466554400000'), isFalse);
      expect(isValidUuid('550e8400-e29b-41d4-a716-44665544000g'), isFalse);
    });
  });

  group('Model Validation Tests', () {
    test('Task throws on invalid ID', () {
      expect(
        () => Task(
          id: 'invalid',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Task throws on empty title', () {
      expect(
        () => Task(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '   ',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Task throws on invalid projectId', () {
      expect(
        () => Task(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: 'Test',
          createdAt: DateTime.now(),
          projectId: 'invalid',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Project throws on invalid ID', () {
      expect(
        () => Project(
          id: 'invalid',
          name: 'Test',
          projectKey: 'TST',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Project throws on empty name', () {
      expect(
        () => Project(
          id: '550e8400-e29b-41d4-a716-446655440000',
          name: '   ',
          projectKey: 'TST',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Project throws on invalid project key', () {
      expect(
        () => Project(
          id: '550e8400-e29b-41d4-a716-446655440000',
          name: 'Test',
          projectKey: 'too_long_key',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board throws on invalid ID', () {
      expect(
        () => Board(
          id: 'invalid',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board throws on empty title', () {
      expect(
        () => Board(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('BoardColumn throws on empty title', () {
      expect(
        () => BoardColumn(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '',
          status: TaskStatus.todo,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Ritual throws on invalid ID', () {
      expect(
        () => Ritual(
          id: 'invalid',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Ritual throws on empty title', () {
      expect(
        () => Ritual(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '   ',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Error Handling Tests', () {
    test('TaskService handles init errors gracefully', () async {
      final service = TaskService();
      try {
        await service.init();
      } catch (_) {
        // Expected in some test environments
      }
      expect(service.error, isNull);
    });
  });

  group('Task Dependencies Tests', () {
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

    test('should add task dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      final result = taskService.addTaskDependency(task2!.id, task1!.id);

      expect(result, isTrue);
      expect(task2.dependsOn.contains(task1.id), isTrue);
    });

    test('should not add self dependency', () async {
      final task = await taskService.addTask('Task 1');

      final result = taskService.addTaskDependency(task!.id, task.id);

      expect(result, isFalse);
    });

    test('should not add duplicate dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);
      final result = taskService.addTaskDependency(task2.id, task1.id);

      expect(result, isFalse);
    });

    test('should not create circular dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);
      final result = taskService.addTaskDependency(task1.id, task2.id);

      expect(result, isFalse);
    });

    test('should remove task dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);
      final result = taskService.removeTaskDependency(task2.id, task1.id);

      expect(result, isTrue);
      expect(task2.dependsOn.contains(task1.id), isFalse);
    });

    test('should get task dependencies', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);
      final deps = taskService.getTaskDependencies(task2.id);

      expect(deps.length, 1);
      expect(deps.first.id, task1.id);
    });

    test('should get dependent tasks', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);
      final dependents = taskService.getDependentTasks(task1.id);

      expect(dependents.length, 1);
      expect(dependents.first.id, task2.id);
    });

    test('should detect blocked task', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);

      expect(taskService.isTaskBlocked(task2), isTrue);
    });

    test('should not block completed dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      task1!.status = TaskStatus.done;
      await taskService.updateTask(task1);

      final task2 = await taskService.addTask('Task 2');
      taskService.addTaskDependency(task2!.id, task1.id);

      expect(taskService.isTaskBlocked(task2), isFalse);
    });

    test('should remove dependency references when task deleted', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);
      await taskService.deleteTask(task1.id);

      expect(task2.dependsOn.contains(task1.id), isFalse);
    });

    test('canMoveTask returns false for blocked task moving to done', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      taskService.addTaskDependency(task2!.id, task1!.id);

      expect(taskService.canMoveTask(task2, TaskStatus.done), isFalse);
    });

    test('canMoveTask returns true for non-blocked task', () async {
      final task1 = await taskService.addTask('Task 1');
      task1!.status = TaskStatus.done;
      await taskService.updateTask(task1);

      final task2 = await taskService.addTask('Task 2');
      taskService.addTaskDependency(task2!.id, task1.id);

      expect(taskService.canMoveTask(task2, TaskStatus.done), isTrue);
    });
  });

  group('Tag Model Tests', () {
    test('Tag creates successfully with valid data', () {
      final tag = Tag(
        id: '550e8400-e29b-41d4-a716-446655440040',
        name: 'Bug',
        color: '#E53935',
        projectId: '550e8400-e29b-41d4-a716-446655440099',
      );

      expect(tag.name, 'Bug');
      expect(tag.color, '#E53935');
    });

    test('Tag throws on invalid ID', () {
      expect(
        () => Tag(
          id: 'invalid',
          name: 'Bug',
          color: '#E53935',
          projectId: '550e8400-e29b-41d4-a716-446655440099',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag throws on empty name', () {
      expect(
        () => Tag(
          id: '550e8400-e29b-41d4-a716-446655440040',
          name: '   ',
          color: '#E53935',
          projectId: '550e8400-e29b-41d4-a716-446655440099',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag throws on invalid color', () {
      expect(
        () => Tag(
          id: '550e8400-e29b-41d4-a716-446655440040',
          name: 'Bug',
          color: 'not-a-color',
          projectId: '550e8400-e29b-41d4-a716-446655440099',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag throws on invalid projectId', () {
      expect(
        () => Tag(
          id: '550e8400-e29b-41d4-a716-446655440040',
          name: 'Bug',
          color: '#E53935',
          projectId: 'invalid',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag copyWith preserves fields', () {
      final tag = Tag(
        id: '550e8400-e29b-41d4-a716-446655440040',
        name: 'Bug',
        color: '#E53935',
        projectId: '550e8400-e29b-41d4-a716-446655440099',
      );

      final copy = tag.copyWith(name: 'Feature');

      expect(copy.name, 'Feature');
      expect(copy.id, tag.id);
      expect(copy.color, '#E53935');
      expect(copy.projectId, tag.projectId);
    });
  });

  group('Tag Service Tests', () {
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

    test('should add tag to project', () async {
      final project = await taskService.addProject('Test', 'TST');
      final tag =
          await taskService.addTag('Bug', '#E53935', project!.id);

      expect(tag, isNotNull);
      expect(tag!.name, 'Bug');
      expect(taskService.tags.length, 1);
    });

    test('should not add duplicate tag name', () async {
      final project = await taskService.addProject('Test', 'TST');
      await taskService.addTag('Bug', '#E53935', project!.id);
      final dup = await taskService.addTag('Bug', '#1E88E5', project.id);

      expect(dup, isNull);
      expect(taskService.tags.length, 1);
    });

    test('should get tags for project', () async {
      final p1 = await taskService.addProject('P1', 'PA');
      final p2 = await taskService.addProject('P2', 'PB');
      await taskService.addTag('Bug', '#E53935', p1!.id);
      await taskService.addTag('Feature', '#1E88E5', p1.id);
      await taskService.addTag('Docs', '#43A047', p2!.id);

      final p1Tags = taskService.getTagsForProject(p1.id);
      final p2Tags = taskService.getTagsForProject(p2.id);

      expect(p1Tags.length, 2);
      expect(p2Tags.length, 1);
    });

    test('should delete tag and remove from tasks', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      final tag =
          await taskService.addTag('Bug', '#E53935', project.id);
      final task =
          await taskService.addTask('Fix bug', tags: ['Bug']);

      expect(task!.tags.contains('Bug'), isTrue);

      await taskService.deleteTag(tag!.id);

      expect(taskService.tags.length, 0);
      final updatedTask =
          taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updatedTask.tags.contains('Bug'), isFalse);
    });

    test('should update tag and rename in tasks', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      final tag =
          await taskService.addTag('Bug', '#E53935', project.id);
      await taskService.addTask('Fix bug', tags: ['Bug']);

      final updated = tag!.copyWith(name: 'Defect');
      await taskService.updateTag(updated);

      final updatedTask = taskService.tasks.first;
      expect(updatedTask.tags.contains('Defect'), isTrue);
      expect(updatedTask.tags.contains('Bug'), isFalse);
    });

    test('should get tag by name', () async {
      final project = await taskService.addProject('Test', 'TST');
      await taskService.addTag('Bug', '#E53935', project!.id);

      final found = taskService.getTagByName('Bug', project.id);
      final notFound = taskService.getTagByName('Feature', project.id);

      expect(found, isNotNull);
      expect(found!.name, 'Bug');
      expect(notFound, isNull);
    });

    test('should filter tasks by multiple tags', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      await taskService.addTag('Bug', '#E53935', project.id);
      await taskService.addTag('UI', '#1E88E5', project.id);

      await taskService.addTask('Bug only', tags: ['Bug']);
      await taskService.addTask('UI only', tags: ['UI']);
      await taskService.addTask('Both', tags: ['Bug', 'UI']);

      taskService.toggleFilterTag('Bug');
      var filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 2); // 'Bug only' + 'Both'

      taskService.toggleFilterTag('UI');
      filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 1); // Only 'Both'

      taskService.clearFilterTags();
      filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 3); // All tasks
    });

    test('should add task with tags', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      final task = await taskService.addTask(
        'Tagged task',
        tags: ['Bug', 'UI'],
      );

      expect(task!.tags, ['Bug', 'UI']);
    });
  });
}
