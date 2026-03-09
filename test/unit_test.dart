import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/services/task_service.dart';
import 'package:photisnadi/services/sync_service.dart';
import 'package:photisnadi/services/yeoman_service.dart';
import 'package:photisnadi/services/theme_service.dart';
import 'package:photisnadi/common/utils.dart';
import 'package:photisnadi/common/validators.dart';
import 'package:photisnadi/services/export_import_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

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

    test('Board throws on empty ID', () {
      expect(
        () => Board(
          id: '',
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

      final result = await taskService.addTaskDependency(task2!.id, task1!.id);

      expect(result, isTrue);
      expect(task2.dependsOn.contains(task1.id), isTrue);
    });

    test('should not add self dependency', () async {
      final task = await taskService.addTask('Task 1');

      final result = await taskService.addTaskDependency(task!.id, task.id);

      expect(result, isFalse);
    });

    test('should not add duplicate dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);
      final result = await taskService.addTaskDependency(task2.id, task1.id);

      expect(result, isFalse);
    });

    test('should not create circular dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);
      final result = await taskService.addTaskDependency(task1.id, task2.id);

      expect(result, isFalse);
    });

    test('should remove task dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);
      final result = await taskService.removeTaskDependency(task2.id, task1.id);

      expect(result, isTrue);
      expect(task2.dependsOn.contains(task1.id), isFalse);
    });

    test('should get task dependencies', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);
      final deps = taskService.getTaskDependencies(task2.id);

      expect(deps.length, 1);
      expect(deps.first.id, task1.id);
    });

    test('should get dependent tasks', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);
      final dependents = taskService.getDependentTasks(task1.id);

      expect(dependents.length, 1);
      expect(dependents.first.id, task2.id);
    });

    test('should detect blocked task', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);

      expect(taskService.isTaskBlocked(task2), isTrue);
    });

    test('should not block completed dependency', () async {
      final task1 = await taskService.addTask('Task 1');
      task1!.status = TaskStatus.done;
      await taskService.updateTask(task1);

      final task2 = await taskService.addTask('Task 2');
      await taskService.addTaskDependency(task2!.id, task1.id);

      expect(taskService.isTaskBlocked(task2), isFalse);
    });

    test('should remove dependency references when task deleted', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);
      await taskService.deleteTask(task1.id);

      expect(task2.dependsOn.contains(task1.id), isFalse);
    });

    test('canMoveTask returns false for blocked task moving to done', () async {
      final task1 = await taskService.addTask('Task 1');
      final task2 = await taskService.addTask('Task 2');

      await taskService.addTaskDependency(task2!.id, task1!.id);

      expect(taskService.canMoveTask(task2, TaskStatus.done), isFalse);
    });

    test('canMoveTask returns true for non-blocked task', () async {
      final task1 = await taskService.addTask('Task 1');
      task1!.status = TaskStatus.done;
      await taskService.updateTask(task1);

      final task2 = await taskService.addTask('Task 2');
      await taskService.addTaskDependency(task2!.id, task1.id);

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

  group('Due Date Tests', () {
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

    test('should add task with due date', () async {
      final dueDate = DateTime(2026, 4, 1);
      final task = await taskService.addTask(
        'Task with due date',
        dueDate: dueDate,
      );

      expect(task!.dueDate, dueDate);
    });

    test('should add task without due date', () async {
      final task = await taskService.addTask('Task without due date');

      expect(task!.dueDate, isNull);
    });

    test('should update task due date', () async {
      final task = await taskService.addTask('Test task');
      final dueDate = DateTime(2026, 5, 15);
      task!.dueDate = dueDate;
      await taskService.updateTask(task);

      final updated =
          taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.dueDate, dueDate);
    });

    test('should filter tasks due before date', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);

      await taskService.addTask(
        'Due soon',
        dueDate: DateTime(2026, 3, 10),
      );
      await taskService.addTask(
        'Due later',
        dueDate: DateTime(2026, 6, 1),
      );
      await taskService.addTask('No due date');

      taskService.setFilterDueBefore(DateTime(2026, 4, 1));
      final filtered = taskService.getFilteredTasks(project.id);

      expect(filtered.length, 1);
      expect(filtered.first.title, 'Due soon');
    });
  });

  group('Sync Serialization Tests', () {
    test('Task toSyncMap produces correct map', () {
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440050',
        title: 'Sync Task',
        description: 'A test task',
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 2, 1),
        projectId: '550e8400-e29b-41d4-a716-446655440099',
        tags: ['bug', 'ui'],
        taskKey: 'TST-1',
        dependsOn: ['550e8400-e29b-41d4-a716-446655440051'],
      );

      final map = task.toSyncMap('user-123');

      expect(map['id'], task.id);
      expect(map['user_id'], 'user-123');
      expect(map['title'], 'Sync Task');
      expect(map['description'], 'A test task');
      expect(map['status'], 'inProgress');
      expect(map['priority'], 'high');
      expect(map['project_id'], task.projectId);
      expect(map['tags'], ['bug', 'ui']);
      expect(map['task_key'], 'TST-1');
      expect(map['depends_on'],
          ['550e8400-e29b-41d4-a716-446655440051']);
      expect(map['due_date'], isNotNull);
      expect(map['created_at'], isNotNull);
      expect(map['modified_at'], isNotNull);
    });

    test('Task fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440050',
        'title': 'Parsed Task',
        'description': 'Desc',
        'status': 'inProgress',
        'priority': 'high',
        'created_at': '2026-01-01T00:00:00.000',
        'modified_at': '2026-01-02T00:00:00.000',
        'due_date': '2026-02-01T00:00:00.000',
        'project_id': '550e8400-e29b-41d4-a716-446655440099',
        'tags': ['bug'],
        'task_key': 'TST-1',
        'depends_on': ['550e8400-e29b-41d4-a716-446655440051'],
      };

      final task = TaskParsing.fromMap(map);

      expect(task.id, map['id']);
      expect(task.title, 'Parsed Task');
      expect(task.description, 'Desc');
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.high);
      expect(task.dueDate, isNotNull);
      expect(task.tags, ['bug']);
      expect(task.taskKey, 'TST-1');
      expect(task.dependsOn,
          ['550e8400-e29b-41d4-a716-446655440051']);
    });

    test('Task fromMap handles missing optional fields', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440050',
        'title': 'Minimal Task',
        'status': 'todo',
        'priority': 'medium',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final task = TaskParsing.fromMap(map);

      expect(task.title, 'Minimal Task');
      expect(task.description, isNull);
      expect(task.dueDate, isNull);
      expect(task.projectId, isNull);
      expect(task.tags, isEmpty);
      expect(task.taskKey, isNull);
      expect(task.dependsOn, isEmpty);
    });

    test('Task fromMap handles invalid status gracefully', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440050',
        'title': 'Bad Status',
        'status': 'nonexistent',
        'priority': 'nonexistent',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final task = TaskParsing.fromMap(map);

      expect(task.status, TaskStatus.todo);
      expect(task.priority, TaskPriority.medium);
    });

    test('Project toSyncMap produces correct map', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440060',
        name: 'Sync Project',
        projectKey: 'SP',
        description: 'A project',
        createdAt: DateTime(2026, 1, 1),
        color: '#FF0000',
        iconName: 'star',
        taskCounter: 5,
        isArchived: true,
      );

      final map = project.toSyncMap('user-123');

      expect(map['id'], project.id);
      expect(map['user_id'], 'user-123');
      expect(map['name'], 'Sync Project');
      expect(map['key'], 'SP');
      expect(map['description'], 'A project');
      expect(map['color'], '#FF0000');
      expect(map['icon_name'], 'star');
      expect(map['task_counter'], 5);
      expect(map['is_archived'], true);
    });

    test('Project fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440060',
        'name': 'Parsed Project',
        'key': 'PP',
        'description': 'Desc',
        'created_at': '2026-01-01T00:00:00.000',
        'modified_at': '2026-01-02T00:00:00.000',
        'color': '#00FF00',
        'icon_name': 'folder',
        'task_counter': 10,
        'is_archived': false,
      };

      final project = ProjectParsing.fromMap(map);

      expect(project.id, map['id']);
      expect(project.name, 'Parsed Project');
      expect(project.projectKey, 'PP');
      expect(project.color, '#00FF00');
      expect(project.iconName, 'folder');
      expect(project.taskCounter, 10);
      expect(project.isArchived, false);
    });

    test('Ritual toSyncMap produces correct map', () {
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440070',
        title: 'Sync Ritual',
        description: 'A ritual',
        createdAt: DateTime(2026, 1, 1),
        streakCount: 7,
        frequency: RitualFrequency.weekly,
      );

      final map = ritual.toSyncMap('user-123');

      expect(map['id'], ritual.id);
      expect(map['user_id'], 'user-123');
      expect(map['title'], 'Sync Ritual');
      expect(map['frequency'], 'weekly');
      expect(map['streak_count'], 7);
    });

    test('Ritual fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440070',
        'title': 'Parsed Ritual',
        'description': 'Desc',
        'is_completed': true,
        'created_at': '2026-01-01T00:00:00.000',
        'last_completed': '2026-01-05T00:00:00.000',
        'reset_time': null,
        'streak_count': 3,
        'frequency': 'daily',
      };

      final ritual = RitualParsing.fromMap(map);

      expect(ritual.id, map['id']);
      expect(ritual.title, 'Parsed Ritual');
      expect(ritual.isCompleted, true);
      expect(ritual.streakCount, 3);
      expect(ritual.frequency, RitualFrequency.daily);
    });

    test('Tag toSyncMap produces correct map', () {
      final tag = Tag(
        id: '550e8400-e29b-41d4-a716-446655440080',
        name: 'Bug',
        color: '#E53935',
        projectId: '550e8400-e29b-41d4-a716-446655440099',
      );

      final map = tag.toSyncMap('user-123');

      expect(map['id'], tag.id);
      expect(map['user_id'], 'user-123');
      expect(map['name'], 'Bug');
      expect(map['color'], '#E53935');
      expect(map['project_id'], tag.projectId);
    });

    test('Tag fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440080',
        'name': 'Feature',
        'color': '#1E88E5',
        'project_id': '550e8400-e29b-41d4-a716-446655440099',
      };

      final tag = TagParsing.fromMap(map);

      expect(tag.id, map['id']);
      expect(tag.name, 'Feature');
      expect(tag.color, '#1E88E5');
      expect(tag.projectId, map['project_id']);
    });

    test('Task roundtrip: toSyncMap -> fromMap preserves data', () {
      final original = Task(
        id: '550e8400-e29b-41d4-a716-446655440050',
        title: 'Roundtrip Task',
        description: 'Test desc',
        status: TaskStatus.inReview,
        priority: TaskPriority.low,
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 3, 15),
        projectId: '550e8400-e29b-41d4-a716-446655440099',
        tags: ['ui', 'bug'],
        taskKey: 'RT-1',
        dependsOn: ['550e8400-e29b-41d4-a716-446655440051'],
      );

      final map = original.toSyncMap('user-123');
      final parsed = TaskParsing.fromMap(map);

      expect(parsed.id, original.id);
      expect(parsed.title, original.title);
      expect(parsed.description, original.description);
      expect(parsed.status, original.status);
      expect(parsed.priority, original.priority);
      expect(parsed.tags, original.tags);
      expect(parsed.taskKey, original.taskKey);
      expect(parsed.dependsOn, original.dependsOn);
    });
  });

  group('SyncConflict Tests', () {
    test('SyncConflict stores all fields correctly', () {
      final now = DateTime.now();
      final earlier = now.subtract(const Duration(seconds: 3));

      final conflict = SyncConflict(
        entityType: 'task',
        entityId: '550e8400-e29b-41d4-a716-446655440050',
        entityTitle: 'Conflict Task',
        localModifiedAt: earlier,
        remoteModifiedAt: now,
        localData: {'title': 'Local version'},
        remoteData: {'title': 'Remote version'},
      );

      expect(conflict.entityType, 'task');
      expect(conflict.entityTitle, 'Conflict Task');
      expect(conflict.localModifiedAt, earlier);
      expect(conflict.remoteModifiedAt, now);
      expect(conflict.localData['title'], 'Local version');
      expect(conflict.remoteData['title'], 'Remote version');
    });
  });

  group('YeomanService Tests', () {
    late YeomanService yeomanService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      await Hive.openBox('settings');
      await Hive.openBox<Task>('tasks');
      await Hive.openBox<Ritual>('rituals');
      await Hive.openBox<Project>('projects');
      yeomanService = YeomanService();
    });

    tearDown(() async {
      yeomanService.dispose();
      await tearDownTestHive();
    });

    test('initial state is disconnected', () {
      expect(yeomanService.isInitialized, false);
      expect(yeomanService.isEnabled, false);
      expect(yeomanService.isConnected, false);
      expect(yeomanService.syncState, YeomanSyncState.idle);
    });

    test('initialize loads settings from Hive', () async {
      // Set mock client before initialize since enabled=true triggers sync
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge') {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'knowledge': []}), 200);
          }
          return http.Response(jsonEncode({'id': 'k1'}), 201);
        }
        return http.Response('OK', 200);
      });
      yeomanService.httpClient = mockClient;

      final settingsBox = Hive.box('settings');
      await settingsBox.put('yeoman_enabled', true);
      await settingsBox.put('yeoman_base_url', 'http://localhost:18789');
      await settingsBox.put('yeoman_api_key', 'sk-test-key');
      await settingsBox.put('yeoman_last_synced_at', '2026-03-01T00:00:00.000Z');

      await yeomanService.initialize();

      expect(yeomanService.isInitialized, true);
      expect(yeomanService.isEnabled, true);
      expect(yeomanService.baseUrl, 'http://localhost:18789');
      expect(yeomanService.isConnected, true);
      expect(yeomanService.lastSyncedAt, isNotNull);
    });

    test('configure saves baseUrl and apiKey', () async {
      await yeomanService.initialize();

      final result = await yeomanService.configure(
        baseUrl: 'http://localhost:18789/',
        apiKey: 'sk-test',
      );

      expect(result, true);
      expect(yeomanService.baseUrl, 'http://localhost:18789');
      expect(yeomanService.isConnected, true);

      final settingsBox = Hive.box('settings');
      expect(settingsBox.get('yeoman_base_url'), 'http://localhost:18789');
      expect(settingsBox.get('yeoman_api_key'), 'sk-test');
    });

    test('configure with password authenticates via API', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'access_token': 'jwt-test-token',
              'refresh_token': 'refresh-token',
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();

      final result = await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        password: 'admin-pass',
      );

      expect(result, true);
      expect(yeomanService.isConnected, true);
    });

    test('configure with wrong password fails', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();

      final result = await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        password: 'wrong',
      );

      expect(result, false);
    });

    test('testConnection returns true on healthy server', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response(
            jsonEncode({'status': 'healthy'}),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.testConnection();
      expect(result, true);
    });

    test('testConnection returns false on unreachable server', () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception('Connection refused');
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:99999',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.testConnection();
      expect(result, false);
    });

    test('setEnabled persists to settings', () async {
      await yeomanService.initialize();
      await yeomanService.setEnabled(enabled: true);

      final settingsBox = Hive.box('settings');
      expect(settingsBox.get('yeoman_enabled'), true);
      expect(yeomanService.isEnabled, true);

      await yeomanService.setEnabled(enabled: false);
      expect(settingsBox.get('yeoman_enabled'), false);
    });

    test('syncTasks pushes task data to brain knowledge', () async {
      final requests = <http.Request>[];
      final mockClient = http_testing.MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({'knowledge': []}),
            200,
          );
        }
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({'id': 'know_123'}),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      // Add a task
      final taskBox = Hive.box<Task>('tasks');
      const taskId = '550e8400-e29b-41d4-a716-446655440000';
      await taskBox.put(
        taskId,
        Task(
          id: taskId,
          title: 'Test Task',
          status: TaskStatus.todo,
          priority: TaskPriority.high,
          createdAt: DateTime.now(),
        ),
      );

      final result = await yeomanService.syncTasks();
      expect(result, true);

      // Verify knowledge POST was made
      final postRequests = requests.where(
        (r) => r.method == 'POST' && r.url.path == '/api/v1/brain/knowledge',
      );
      expect(postRequests, isNotEmpty);

      final postBody = jsonDecode(postRequests.first.body);
      expect(postBody['topic'], 'photis-nadi-tasks');
      expect(postBody['source'], 'photis-nadi');
    });

    test('syncRitualAnalytics computes correct stats', () async {
      final capturedBody = <String, dynamic>{};
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({'knowledge': []}),
            200,
          );
        }
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'POST') {
          capturedBody.addAll(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          return http.Response(jsonEncode({'id': 'know_456'}), 201);
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      // Add rituals
      final ritualBox = Hive.box<Ritual>('rituals');
      const ritualId1 = '550e8400-e29b-41d4-a716-446655440001';
      const ritualId2 = '550e8400-e29b-41d4-a716-446655440002';
      await ritualBox.put(
        ritualId1,
        Ritual(
          id: ritualId1,
          title: 'Morning Meditation',
          isCompleted: true,
          createdAt: DateTime.now(),
          streakCount: 5,
          frequency: RitualFrequency.daily,
        ),
      );
      await ritualBox.put(
        ritualId2,
        Ritual(
          id: ritualId2,
          title: 'Weekly Review',
          isCompleted: false,
          createdAt: DateTime.now(),
          streakCount: 3,
          frequency: RitualFrequency.weekly,
        ),
      );

      final result = await yeomanService.syncRitualAnalytics();
      expect(result, true);

      expect(capturedBody['topic'], 'photis-nadi-rituals');
      final content = jsonDecode(capturedBody['content']);
      final analytics = content['analytics'];
      expect(analytics['total_rituals'], 2);
      expect(analytics['completed_today'], 1);
      expect(analytics['longest_streak'], 5);
      expect(analytics['average_streak'], 4.0);
      expect(analytics['by_frequency']['daily']['total'], 1);
      expect(analytics['by_frequency']['weekly']['total'], 1);
    });

    test('syncAll sets state correctly on success', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge') {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'knowledge': []}), 200);
          }
          if (request.method == 'POST') {
            return http.Response(jsonEncode({'id': 'k1'}), 201);
          }
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      // Call syncAll directly (don't use setEnabled which also triggers sync)
      final result = await yeomanService.syncAll();
      expect(result, true);
      expect(yeomanService.syncState, YeomanSyncState.success);
      expect(yeomanService.lastSyncedAt, isNotNull);
    });

    test('syncAll sets error state on failure', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.syncAll();
      expect(result, false);
      expect(yeomanService.syncState, YeomanSyncState.error);
    });

    test('generateApiKey returns key on success', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/auth/api-keys' &&
            request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['name'], 'Photis Nadi MCP');
          expect(body['permissions'], contains('brain.read'));
          return http.Response(
            jsonEncode({
              'id': 'key_123',
              'name': 'Photis Nadi MCP',
              'api_key': 'sk-generated-key',
              'permissions': body['permissions'],
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-admin',
      );

      final key = await yeomanService.generateApiKey();
      expect(key, 'sk-generated-key');
    });

    test('generateApiKey returns null when not connected', () async {
      await yeomanService.initialize();
      final key = await yeomanService.generateApiKey();
      expect(key, null);
    });

    test('registerMcpTools sends correct tool manifest', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/mcp/servers' &&
            request.method == 'POST') {
          capturedBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({'server': {'id': 'srv_123'}}),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.registerMcpTools(
        apiUrl: 'http://photisnadi:8081',
        apiKey: 'test-api-key-123',
      );

      expect(result, true);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['name'], 'Photis Nadi');
      expect(capturedBody!['transport'], 'streamable-http');

      final tools = capturedBody!['tools'] as List;
      expect(tools.length, 6);

      final toolNames = tools.map((t) => t['name']).toSet();
      expect(toolNames, contains('photis_list_tasks'));
      expect(toolNames, contains('photis_create_task'));
      expect(toolNames, contains('photis_update_task'));
      expect(toolNames, contains('photis_list_projects'));
      expect(toolNames, contains('photis_list_rituals'));
      expect(toolNames, contains('photis_task_analytics'));
    });

    test('disconnect clears credentials and stops sync', () async {
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );
      await yeomanService.setEnabled(enabled: true);

      expect(yeomanService.isConnected, true);
      expect(yeomanService.isEnabled, true);

      await yeomanService.disconnect();

      expect(yeomanService.isConnected, false);
      expect(yeomanService.isEnabled, false);
      expect(yeomanService.syncState, YeomanSyncState.idle);

      final settingsBox = Hive.box('settings');
      expect(settingsBox.get('yeoman_api_key'), null);
      expect(settingsBox.get('yeoman_enabled'), false);
    });

    test('upserts knowledge by deleting existing entry first', () async {
      final deleteCalled = <String>[];
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'knowledge': [
                {'id': 'existing_123', 'topic': 'photis-nadi-tasks'}
              ]
            }),
            200,
          );
        }
        if (request.url.path.startsWith('/api/v1/brain/knowledge/') &&
            request.method == 'DELETE') {
          deleteCalled.add(request.url.pathSegments.last);
          return http.Response('', 204);
        }
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'new_456'}), 201);
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.syncTasks();
      expect(result, true);
      expect(deleteCalled, contains('existing_123'));
    });

    test('headers include API key when set', () async {
      String? capturedAuthHeader;
      final mockClient = http_testing.MockClient((request) async {
        capturedAuthHeader = request.headers['X-API-Key'];
        return http.Response(jsonEncode({'knowledge': []}), 200);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-my-key',
      );

      await yeomanService.syncTasks();
      expect(capturedAuthHeader, 'sk-my-key');
    });
  });

  group('ThemeService Tests', () {
    test('AccentColor enum has correct values', () {
      expect(AccentColor.values.length, 8);
      expect(AccentColor.indigo.label, 'Indigo');
      expect(AccentColor.rose.label, 'Rose');
      expect(AccentColor.emerald.label, 'Emerald');
    });

    test('default state is comfortable with indigo', () {
      final service = ThemeService();
      expect(service.accentColor, AccentColor.indigo);
      expect(service.layoutDensity, LayoutDensity.comfortable);
      expect(service.isCompact, false);
      expect(service.isEReaderMode, false);
      expect(service.isDarkMode, false);
    });

    test('LayoutDensity compact check works', () {
      final service = ThemeService();
      expect(service.isCompact, false);
    });
  });

  // ── Subtask Tests ──

  group('Subtask Tests', () {
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

    test('should add subtask to task', () async {
      await taskService.addTask('Parent Task');
      final task = taskService.tasks.first;

      await taskService.addSubtask(task.id, 'Subtask 1');
      await taskService.addSubtask(task.id, 'Subtask 2');

      final updated = taskService.tasks.first;
      expect(updated.subtasks.length, 2);
      expect(updated.parsedSubtasks[0].title, 'Subtask 1');
      expect(updated.parsedSubtasks[0].done, false);
    });

    test('should toggle subtask completion', () async {
      await taskService.addTask('Parent Task');
      final task = taskService.tasks.first;

      await taskService.addSubtask(task.id, 'Subtask 1');
      await taskService.toggleSubtask(task.id, 0);

      final updated = taskService.tasks.first;
      expect(updated.parsedSubtasks[0].done, true);
      expect(updated.subtasksDone, 1);

      await taskService.toggleSubtask(task.id, 0);
      final toggled = taskService.tasks.first;
      expect(toggled.parsedSubtasks[0].done, false);
    });

    test('should remove subtask', () async {
      await taskService.addTask('Parent Task');
      final task = taskService.tasks.first;

      await taskService.addSubtask(task.id, 'Sub A');
      await taskService.addSubtask(task.id, 'Sub B');
      await taskService.removeSubtask(task.id, 0);

      final updated = taskService.tasks.first;
      expect(updated.subtasks.length, 1);
      expect(updated.parsedSubtasks[0].title, 'Sub B');
    });

    test('subtask progress counts correctly', () async {
      await taskService.addTask('Parent Task');
      final task = taskService.tasks.first;

      await taskService.addSubtask(task.id, 'A');
      await taskService.addSubtask(task.id, 'B');
      await taskService.addSubtask(task.id, 'C');
      await taskService.toggleSubtask(task.id, 0);
      await taskService.toggleSubtask(task.id, 2);

      final updated = taskService.tasks.first;
      expect(updated.subtasksDone, 2);
      expect(updated.subtasks.length, 3);
    });
  });

  // ── Time Tracking Tests ──

  group('Time Tracking Tests', () {
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

    test('should log time to task', () async {
      await taskService.addTask('Tracked Task');
      final task = taskService.tasks.first;

      await taskService.logTime(task.id, 30);
      expect(taskService.tasks.first.trackedMinutes, 30);

      await taskService.logTime(task.id, 15);
      expect(taskService.tasks.first.trackedMinutes, 45);
    });

    test('should reject zero or negative minutes', () async {
      await taskService.addTask('Task');
      final task = taskService.tasks.first;

      expect(await taskService.logTime(task.id, 0), false);
      expect(await taskService.logTime(task.id, -5), false);
      expect(taskService.tasks.first.trackedMinutes, 0);
    });

    test('should set estimate', () async {
      await taskService.addTask('Task');
      final task = taskService.tasks.first;

      await taskService.setEstimate(task.id, 120);
      expect(taskService.tasks.first.estimatedMinutes, 120);

      await taskService.setEstimate(task.id, null);
      expect(taskService.tasks.first.estimatedMinutes, null);
    });

    test('formattedTrackedTime formats correctly', () {
      final now = DateTime.now();
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440001',
        title: 'Test',
        createdAt: now,
        trackedMinutes: 0,
      );
      expect(task.formattedTrackedTime, '0m');

      task.trackedMinutes = 45;
      expect(task.formattedTrackedTime, '45m');

      task.trackedMinutes = 60;
      expect(task.formattedTrackedTime, '1h');

      task.trackedMinutes = 90;
      expect(task.formattedTrackedTime, '1h 30m');
    });
  });

  // ── Recurrence Tests ──

  group('Recurrence Tests', () {
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

    test('should set recurrence on task', () async {
      await taskService.addTask('Recurring');
      final task = taskService.tasks.first;

      await taskService.setRecurrence(task.id, 'daily');
      expect(taskService.tasks.first.recurrence, 'daily');

      await taskService.setRecurrence(task.id, null);
      expect(taskService.tasks.first.recurrence, null);
    });

    test('should reject invalid recurrence values', () async {
      await taskService.addTask('Task');
      final task = taskService.tasks.first;

      expect(await taskService.setRecurrence(task.id, 'hourly'), false);
      expect(taskService.tasks.first.recurrence, null);
    });

    test('processRecurringTasks creates new task when done recurring is due',
        () async {
      final project = await taskService.addProject('Proj', 'PR');
      await taskService.addTask(
        'Daily Standup',
        projectId: project!.id,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      final task = taskService.getTasksForProject(project.id).first;
      await taskService.setRecurrence(task.id, 'daily');

      // Mark as done
      task.status = TaskStatus.done;
      await taskService.updateTask(task);

      await taskService.processRecurringTasks();

      final tasks = taskService.getTasksForProject(project.id);
      expect(tasks.length, 2);

      // The new task should be todo with the recurrence
      final newTask = tasks.firstWhere((t) => t.status == TaskStatus.todo);
      expect(newTask.title, 'Daily Standup');
      expect(newTask.recurrence, 'daily');

      // The old completed task should have recurrence cleared
      final oldTask = tasks.firstWhere((t) => t.status == TaskStatus.done);
      expect(oldTask.recurrence, null);
    });
  });

  // ── Attachment Tests ──

  group('Attachment Tests', () {
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

    test('should add attachment to task', () async {
      await taskService.addTask('Task With Files');
      final task = taskService.tasks.first;

      await taskService.addAttachment(task.id, '/tmp/doc.pdf');
      await taskService.addAttachment(task.id, '/tmp/image.png');

      final updated = taskService.tasks.first;
      expect(updated.attachments.length, 2);
      expect(updated.attachments[0], '/tmp/doc.pdf');
    });

    test('should remove attachment by index', () async {
      await taskService.addTask('Task');
      final task = taskService.tasks.first;

      await taskService.addAttachment(task.id, '/tmp/a.txt');
      await taskService.addAttachment(task.id, '/tmp/b.txt');
      await taskService.removeAttachment(task.id, 0);

      final updated = taskService.tasks.first;
      expect(updated.attachments.length, 1);
      expect(updated.attachments[0], '/tmp/b.txt');
    });

    test('removeAttachment rejects invalid index', () async {
      await taskService.addTask('Task');
      final task = taskService.tasks.first;

      expect(await taskService.removeAttachment(task.id, 0), false);
      expect(await taskService.removeAttachment(task.id, -1), false);
    });
  });

  // ── Project Sharing Tests ──

  group('Project Sharing Tests', () {
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

    test('should share project with user', () async {
      final project = await taskService.addProject('Shared', 'SH');
      expect(project, isNotNull);

      await taskService.shareProject(project!.id, 'user-abc');
      expect(taskService.getProjectSharedUsers(project.id), ['user-abc']);
    });

    test('should not duplicate shared user', () async {
      final project = await taskService.addProject('Shared', 'SH');

      await taskService.shareProject(project!.id, 'user-abc');
      await taskService.shareProject(project.id, 'user-abc');
      expect(taskService.getProjectSharedUsers(project.id).length, 1);
    });

    test('should unshare project', () async {
      final project = await taskService.addProject('Shared', 'SH');

      await taskService.shareProject(project!.id, 'user-abc');
      await taskService.shareProject(project.id, 'user-def');
      await taskService.unshareProject(project.id, 'user-abc');

      expect(taskService.getProjectSharedUsers(project.id), ['user-def']);
    });
  });

  // ── Sync Serialization with new fields ──

  group('Extended Sync Serialization Tests', () {
    test('Task toSyncMap includes subtasks and time tracking', () {
      final now = DateTime.now();
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440002',
        title: 'Full Task',
        createdAt: now,
        subtasks: ['0:Design', '1:Code'],
        estimatedMinutes: 120,
        trackedMinutes: 45,
        recurrence: 'weekly',
      );

      final map = task.toSyncMap('user1');
      expect(map['subtasks'], ['0:Design', '1:Code']);
      expect(map['estimated_minutes'], 120);
      expect(map['tracked_minutes'], 45);
      expect(map['recurrence'], 'weekly');
    });

    test('Task fromMap handles new fields', () {
      final data = {
        'id': '550e8400-e29b-41d4-a716-446655440003',
        'title': 'From Map',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'todo',
        'priority': 'medium',
        'subtasks': ['0:Item1', '1:Item2'],
        'estimated_minutes': 60,
        'tracked_minutes': 30,
        'recurrence': 'daily',
      };

      final task = TaskParsing.fromMap(data);
      expect(task.subtasks.length, 2);
      expect(task.estimatedMinutes, 60);
      expect(task.trackedMinutes, 30);
      expect(task.recurrence, 'daily');
    });

    test('Task fromMap handles missing new fields gracefully', () {
      final data = {
        'id': '550e8400-e29b-41d4-a716-446655440004',
        'title': 'Old Task',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'todo',
        'priority': 'low',
      };

      final task = TaskParsing.fromMap(data);
      expect(task.subtasks, isEmpty);
      expect(task.estimatedMinutes, null);
      expect(task.trackedMinutes, 0);
      expect(task.recurrence, null);
    });
  });

  // ── Validator Tests ──

  group('Validator Tests', () {
    test('isValidHexColor accepts valid colors', () {
      expect(isValidHexColor('#FF0000'), isTrue);
      expect(isValidHexColor('#ff0000'), isTrue);
      expect(isValidHexColor('FF0000'), isTrue);
      expect(isValidHexColor('#FF000080'), isTrue); // 8-char RGBA
    });

    test('isValidHexColor rejects invalid colors', () {
      expect(isValidHexColor(''), isFalse);
      expect(isValidHexColor('#FFF'), isFalse); // 3-char
      expect(isValidHexColor('#GGGGGG'), isFalse);
      expect(isValidHexColor('not-a-color'), isFalse);
    });

    test('normalizeHexColor normalizes formats', () {
      expect(normalizeHexColor('ff0000'), '#FF0000');
      expect(normalizeHexColor('#ff0000'), '#FF0000');
      expect(normalizeHexColor('  #ff0000  '), '#FF0000');
    });

    test('isValidProjectKey validates keys', () {
      expect(isValidProjectKey('AB'), isTrue);
      expect(isValidProjectKey('ABCDE'), isTrue);
      expect(isValidProjectKey('A1'), isTrue);
      expect(isValidProjectKey(''), isFalse);
      expect(isValidProjectKey('A'), isFalse); // too short
      expect(isValidProjectKey('ABCDEF'), isFalse); // too long
      expect(isValidProjectKey('ab'), isFalse); // lowercase
      expect(isValidProjectKey('A B'), isFalse); // space
    });

    test('isValidUuid validates UUIDs', () {
      expect(isValidUuid('550e8400-e29b-41d4-a716-446655440000'), isTrue);
      expect(isValidUuid('not-a-uuid'), isFalse);
      expect(isValidUuid(''), isFalse);
    });

    test('capitalizeFirst works correctly', () {
      expect(capitalizeFirst('hello'), 'Hello');
      expect(capitalizeFirst(''), '');
      expect(capitalizeFirst('a'), 'A');
      expect(capitalizeFirst('Hello'), 'Hello');
    });

    test('generateProjectKey generates correct keys', () {
      expect(generateProjectKey('My Project'), 'MP');
      expect(generateProjectKey('A Big Cool Project'), 'ABC');
      expect(generateProjectKey('Solo'), 'SOL');
      expect(generateProjectKey('Hi'), 'HI');
      expect(generateProjectKey('A'), 'A');
      expect(generateProjectKey(''), '');
      expect(generateProjectKey('   '), '');
    });
  });

  // ── Utils Tests ──

  group('Utils Tests', () {
    test('parseColor parses valid hex colors', () {
      final color = parseColor('#FF0000');
      expect(color.value, isNonZero);
    });

    test('parseColor returns blue for invalid input', () {
      final color = parseColor('not-a-color');
      expect(color, Colors.blue);
    });

    test('parseColor handles missing hash prefix', () {
      final color = parseColor('FF0000');
      expect(color.value, isNonZero);
    });

    test('formatDate formats correctly', () {
      final date = DateTime(2026, 3, 9);
      expect(formatDate(date), '9/3/2026');
    });

    test('formatPriority formats all priorities', () {
      expect(formatPriority(TaskPriority.low), 'Low');
      expect(formatPriority(TaskPriority.medium), 'Medium');
      expect(formatPriority(TaskPriority.high), 'High');
    });

    test('formatStatus formats all statuses', () {
      expect(formatStatus(TaskStatus.todo), 'Todo');
      expect(formatStatus(TaskStatus.inProgress), 'InProgress');
      expect(formatStatus(TaskStatus.done), 'Done');
    });

    test('getPriorityColor returns correct colors', () {
      expect(getPriorityColor(TaskPriority.high), Colors.red);
      expect(getPriorityColor(TaskPriority.medium), Colors.orange);
      expect(getPriorityColor(TaskPriority.low), Colors.green);
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

      expect(ritual.isCompleted, isTrue); // Not reset
      await tearDownTestHive();
    });

    test('resetIfNeeded resets weekly ritual next week', () async {
      await setUpTestHive();
      _registerAdapters();
      final box = await Hive.openBox<Ritual>('rituals');
      final lastWeek = DateTime.now().subtract(const Duration(days: 8));
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
      // Jan 1 2026 is a Thursday
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

  // ── Board Model Tests ──

  group('Board Model Tests', () {
    test('Board creates with valid data', () {
      final board = Board(
        id: '550e8400-e29b-41d4-a716-446655440070',
        title: 'Test Board',
        createdAt: DateTime.now(),
      );
      expect(board.title, 'Test Board');
    });

    test('Board rejects empty ID', () {
      expect(
        () => Board(id: '', title: 'Test', createdAt: DateTime.now()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board rejects empty title', () {
      expect(
        () => Board(
          id: '550e8400-e29b-41d4-a716-446655440071',
          title: '',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board.defaultBoard creates valid board', () {
      final board = Board.defaultBoard('test-id');
      expect(board.title, 'Default');
      expect(board.columns.length, 5);
    });

    test('Board.bugTracking template has correct columns', () {
      final board = Board.bugTracking('test-id');
      expect(board.title, 'Bug Tracking');
      expect(board.columns.any((c) => c.title == 'New'), isTrue);
    });

    test('Board.sprint template has correct columns', () {
      final board = Board.sprint('test-id');
      expect(board.title, 'Sprint');
      expect(board.columns.any((c) => c.title == 'Backlog'), isTrue);
    });

    test('BoardColumn creates correctly', () {
      final col = BoardColumn(
        id: '550e8400-e29b-41d4-a716-446655440072',
        title: 'Test',
        status: TaskStatus.todo,
      );
      expect(col.title, 'Test');
      expect(col.status, TaskStatus.todo);
    });
  });

  // ── Filter/Sort Tests ──

  group('Filter and Sort Tests', () {
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

    test('setSearchQuery updates and notifies', () {
      int notifyCount = 0;
      taskService.addListener(() => notifyCount++);
      taskService.setSearchQuery('test');
      expect(taskService.searchQuery, 'test');
      expect(notifyCount, 1);
    });

    test('setFilterStatus updates and notifies', () {
      taskService.setFilterStatus(TaskStatus.todo);
      expect(taskService.filterStatus, TaskStatus.todo);
    });

    test('setFilterPriority updates and notifies', () {
      taskService.setFilterPriority(TaskPriority.high);
      expect(taskService.filterPriority, TaskPriority.high);
    });

    test('toggleFilterTag adds and removes tags', () {
      taskService.toggleFilterTag('bug');
      expect(taskService.filterTags.contains('bug'), isTrue);
      taskService.toggleFilterTag('bug');
      expect(taskService.filterTags.contains('bug'), isFalse);
    });

    test('clearFilterTags clears all tags', () {
      taskService.toggleFilterTag('bug');
      taskService.toggleFilterTag('feature');
      taskService.clearFilterTags();
      expect(taskService.filterTags, isEmpty);
    });

    test('setFilterDueBefore updates filter', () {
      final date = DateTime(2026, 12, 31);
      taskService.setFilterDueBefore(date);
      expect(taskService.filterDueBefore, date);
    });

    test('setFilterDueAfter updates filter', () {
      final date = DateTime(2026, 1, 1);
      taskService.setFilterDueAfter(date);
      expect(taskService.filterDueAfter, date);
    });

    test('setSortBy toggles ascending on same sort', () {
      taskService.setSortBy(TaskSortBy.title);
      expect(taskService.sortBy, TaskSortBy.title);
      expect(taskService.sortAscending, isFalse);
      taskService.setSortBy(TaskSortBy.title);
      expect(taskService.sortAscending, isTrue);
    });

    test('setSortBy resets ascending on different sort', () {
      taskService.setSortBy(TaskSortBy.title);
      taskService.setSortBy(TaskSortBy.priority);
      expect(taskService.sortBy, TaskSortBy.priority);
      expect(taskService.sortAscending, isFalse);
    });

    test('clearFilters resets all filters', () {
      taskService.setSearchQuery('test');
      taskService.setFilterStatus(TaskStatus.todo);
      taskService.setFilterPriority(TaskPriority.high);
      taskService.toggleFilterTag('bug');
      taskService.setFilterDueBefore(DateTime.now());
      taskService.setFilterDueAfter(DateTime.now());
      expect(taskService.hasActiveFilters, isTrue);

      taskService.clearFilters();
      expect(taskService.hasActiveFilters, isFalse);
      expect(taskService.searchQuery, '');
      expect(taskService.filterStatus, isNull);
      expect(taskService.filterPriority, isNull);
      expect(taskService.filterTags, isEmpty);
      expect(taskService.filterDueBefore, isNull);
      expect(taskService.filterDueAfter, isNull);
    });

    test('getFilteredTasks filters by search query', () async {
      final project = await taskService.addProject('Test', 'TE');
      await taskService.addTask('Alpha task', projectId: project!.id);
      await taskService.addTask('Beta task', projectId: project.id);

      taskService.setSearchQuery('alpha');
      final results = taskService.getFilteredTasks(project.id);
      expect(results.length, 1);
      expect(results.first.title, 'Alpha task');
    });

    test('getFilteredTasks filters by status', () async {
      final project = await taskService.addProject('Test', 'TE');
      final task = await taskService.addTask('Task', projectId: project!.id);
      task!.status = TaskStatus.done;
      await taskService.updateTask(task);

      taskService.setFilterStatus(TaskStatus.done);
      final results = taskService.getFilteredTasks(project.id);
      expect(results.length, 1);
    });

    test('getFilteredTasks filters by priority', () async {
      final project = await taskService.addProject('Test', 'TE');
      await taskService.addTask('Task', projectId: project!.id, priority: TaskPriority.high);
      await taskService.addTask('Task2', projectId: project.id, priority: TaskPriority.low);

      taskService.setFilterPriority(TaskPriority.high);
      final results = taskService.getFilteredTasks(project.id);
      expect(results.length, 1);
    });

    test('getFilteredTasks sorts by title', () async {
      final project = await taskService.addProject('Test', 'TE');
      await taskService.addTask('Charlie', projectId: project!.id);
      await taskService.addTask('Alpha', projectId: project.id);
      await taskService.addTask('Bravo', projectId: project.id);

      taskService.setSortBy(TaskSortBy.title);
      taskService.setSortBy(TaskSortBy.title); // ascending
      final results = taskService.getFilteredTasks(project.id);
      expect(results[0].title, 'Alpha');
      expect(results[1].title, 'Bravo');
      expect(results[2].title, 'Charlie');
    });

    test('getFilteredTasks sorts by due date with nulls last', () async {
      final project = await taskService.addProject('Test', 'TE');
      await taskService.addTask('No date', projectId: project!.id);
      await taskService.addTask('Has date', projectId: project.id, dueDate: DateTime(2026, 6, 1));

      taskService.setSortBy(TaskSortBy.dueDate);
      taskService.setSortBy(TaskSortBy.dueDate); // ascending
      final results = taskService.getFilteredTasks(project.id);
      expect(results.first.title, 'Has date');
      expect(results.last.title, 'No date');
    });
  });

  // ── Export/Import Tests ──

  group('Export Import Tests', () {
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

    test('exportAllJson produces valid JSON', () async {
      await taskService.addProject('Test Project', 'TP');
      await taskService.addTask('Task 1');
      await taskService.addRitual('Daily Ritual');

      final json = ExportImportService.exportAllJson(taskService);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['version'], 1);
      expect(data['exported_at'], isNotNull);
      expect(data['projects'], isA<List>());
      expect((data['projects'] as List).length, greaterThanOrEqualTo(1));
      expect(data['tasks'], isA<List>());
      expect((data['tasks'] as List).length, greaterThanOrEqualTo(1));
      expect(data['rituals'], isA<List>());
      expect((data['rituals'] as List).length, greaterThanOrEqualTo(1));
    });

    test('exportProjectJson exports single project', () async {
      final project = await taskService.addProject('Test Project', 'TP');
      await taskService.addTask('Task 1', projectId: project!.id);
      await taskService.addTask('Task 2', projectId: project.id);

      final json = ExportImportService.exportProjectJson(taskService, project.id);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect((data['projects'] as List).length, 1);
      expect((data['tasks'] as List).length, 2);
    });

    test('exportTasksCsv produces valid CSV', () async {
      await taskService.addTask('Test Task');

      final csv = ExportImportService.exportTasksCsv(taskService);
      final lines = csv.trim().split('\n');

      expect(lines.length, 2); // header + 1 task
      expect(lines[0], contains('Key,Title,Status'));
      expect(lines[1], contains('Test Task'));
    });

    test('exportTasksCsv escapes commas in values', () async {
      await taskService.addTask('Task, with comma');

      final csv = ExportImportService.exportTasksCsv(taskService);
      expect(csv, contains('"Task, with comma"'));
    });

    test('importJson round-trips with exportAllJson', () async {
      await taskService.addProject('Test Project', 'TP');
      await taskService.addTask('Task 1');
      await taskService.addRitual('Ritual 1');

      final exported = ExportImportService.exportAllJson(taskService);

      // Create a fresh service
      await tearDownTestHive();
      await setUpTestHive();
      _registerAdapters();
      final freshService = TaskService();
      await freshService.init();

      final summary = await ExportImportService.importJson(freshService, exported);
      expect(summary.projects, greaterThanOrEqualTo(1));
      expect(summary.tasks, greaterThanOrEqualTo(1));
      expect(summary.rituals, greaterThanOrEqualTo(1));
      expect(freshService.projects.length, greaterThanOrEqualTo(1));
      expect(freshService.tasks.length, greaterThanOrEqualTo(1));
      expect(freshService.rituals.length, greaterThanOrEqualTo(1));
    });

    test('ImportSummary toString formats correctly', () {
      const summary = ImportSummary(projects: 2, tasks: 5, rituals: 3, tags: 1);
      expect(summary.toString(), 'Imported 2 projects, 5 tasks, 3 rituals, 1 tags');
    });
  });

  // ── ThemeService Tests ──

  group('ThemeService Tests', () {
    test('default values are correct', () {
      final service = ThemeService();
      expect(service.isEReaderMode, isFalse);
      expect(service.isDarkMode, isFalse);
      expect(service.accentColor, AccentColor.indigo);
      expect(service.layoutDensity, LayoutDensity.comfortable);
      expect(service.isCompact, isFalse);
    });

    test('AccentColor enum has correct labels', () {
      expect(AccentColor.indigo.label, 'Indigo');
      expect(AccentColor.teal.label, 'Teal');
      expect(AccentColor.rose.label, 'Rose');
    });

    test('AccentColor enum has non-zero colors', () {
      for (final color in AccentColor.values) {
        expect(color.color.value, isNonZero);
      }
    });
  });

  // ── SyncService Model Tests ──

  group('SyncService Models Tests', () {
    test('SyncConflict creates correctly', () {
      final conflict = SyncConflict(
        entityType: 'task',
        entityId: 'test-id',
        entityTitle: 'Test Task',
        localModifiedAt: DateTime(2026, 1, 1),
        remoteModifiedAt: DateTime(2026, 1, 2),
        localData: {'title': 'local'},
        remoteData: {'title': 'remote'},
      );
      expect(conflict.entityType, 'task');
      expect(conflict.entityTitle, 'Test Task');
    });

    test('SyncException toString formats correctly', () {
      final ex = SyncException('test error', cause: 'root cause');
      expect(ex.toString(), 'SyncException: test error');
    });

    test('RetryConfig has expected defaults', () {
      expect(RetryConfig.maxRetries, 3);
      expect(RetryConfig.initialDelay, const Duration(seconds: 1));
    });

    test('NetworkConfig has expected defaults', () {
      expect(NetworkConfig.requestTimeout, const Duration(seconds: 30));
      expect(NetworkConfig.connectionTimeout, const Duration(seconds: 10));
    });
  });
}
