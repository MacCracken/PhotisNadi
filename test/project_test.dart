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

    test('shareProject adds user', () async {
      final project = await taskService.addProject('Shared', 'SHR');
      expect(project, isNotNull);

      final result = await taskService.shareProject(project!.id, 'user-1');
      expect(result, true);

      final users = taskService.getProjectSharedUsers(project.id);
      expect(users, contains('user-1'));
    });

    test('shareProject is idempotent', () async {
      final project = await taskService.addProject('Shared', 'SHR');
      expect(project, isNotNull);

      await taskService.shareProject(project!.id, 'user-1');
      await taskService.shareProject(project.id, 'user-1');

      final users = taskService.getProjectSharedUsers(project.id);
      expect(users.where((u) => u == 'user-1').length, 1);
    });

    test('unshareProject removes user', () async {
      final project = await taskService.addProject('Shared', 'SHR');
      expect(project, isNotNull);

      await taskService.shareProject(project!.id, 'user-1');
      await taskService.shareProject(project.id, 'user-2');

      await taskService.unshareProject(project.id, 'user-1');
      final users = taskService.getProjectSharedUsers(project.id);
      expect(users, isNot(contains('user-1')));
      expect(users, contains('user-2'));
    });

    test('getProjectSharedUsers returns empty for unknown project', () {
      final users = taskService.getProjectSharedUsers('nonexistent');
      expect(users, isEmpty);
    });

    test('shareProject adds user to shared list', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final result = await taskService.shareProject(project!.id, 'user-1');
      expect(result, isTrue);

      final users = taskService.getProjectSharedUsers(project.id);
      expect(users, contains('user-1'));
    });

    test('shareProject returns false for missing project', () async {
      final result = await taskService.shareProject(
          '550e8400-e29b-41d4-a716-446655440999', 'user-1');
      expect(result, isFalse);
    });

    test('unshareProject removes user from shared list', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      await taskService.shareProject(project!.id, 'user-1');
      final result = await taskService.unshareProject(project.id, 'user-1');
      expect(result, isTrue);

      final users = taskService.getProjectSharedUsers(project.id);
      expect(users, isNot(contains('user-1')));
    });

    test('unshareProject returns false for missing project', () async {
      final result = await taskService.unshareProject(
          '550e8400-e29b-41d4-a716-446655440999', 'user-1');
      expect(result, isFalse);
    });

    test('getProjectSharedUsers returns empty for no shares', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final users = taskService.getProjectSharedUsers(project!.id);
      expect(users, isEmpty);
    });

    test('getProjectSharedUsers returns empty for missing project', () {
      final users = taskService
          .getProjectSharedUsers('550e8400-e29b-41d4-a716-446655440999');
      expect(users, isEmpty);
    });
  });

  // ── Project Archive Tests ──

  group('Project Archive Tests', () {
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

    test('archiveProject sets isArchived', () async {
      final project = await taskService.addProject('Archive Me', 'ARC');
      expect(project, isNotNull);

      final result = await taskService.archiveProject(project!.id);
      expect(result, true);

      expect(taskService.archivedProjects.any((p) => p.id == project.id), true);
      expect(taskService.activeProjects.any((p) => p.id == project.id), false);
    });

    test('archiveProject clears selection if archived is selected', () async {
      final project = await taskService.addProject('Archive Me', 'ARC');
      taskService.selectProject(project!.id);
      expect(taskService.selectedProjectId, project.id);

      await taskService.archiveProject(project.id);
      expect(taskService.selectedProjectId, isNot(project.id));
    });

    test('archiveProject returns false for non-existent project', () async {
      final result = await taskService.archiveProject('nonexistent');
      expect(result, false);
    });
  });

  // ── Column Management Tests ──

  group('Column Mixin Tests', () {
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

    test('addColumn adds to active board', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final newCol = BoardColumn(
        id: 'custom-col',
        title: 'Custom',
        order: 0,
        status: TaskStatus.inReview,
      );
      final result = await taskService.addColumn(project!.id, newCol);
      expect(result, true);

      final updated =
          taskService.projects.firstWhere((p) => p.id == project.id);
      expect(updated.activeColumns.any((c) => c.id == 'custom-col'), true);
    });

    test('addColumn returns false for non-existent project', () async {
      final result = await taskService.addColumn(
          'nonexistent',
          BoardColumn(
            id: 'col',
            title: 'Col',
            order: 0,
            status: TaskStatus.todo,
          ));
      expect(result, false);
    });

    test('updateColumn modifies existing column', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final columns = project!.activeColumns;
      final todoCol = columns.firstWhere((c) => c.status == TaskStatus.todo);
      final updated = todoCol.copyWith(title: 'Backlog');

      final result = await taskService.updateColumn(project.id, updated);
      expect(result, true);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(proj.activeColumns.any((c) => c.title == 'Backlog'), true);
    });

    test('deleteColumn removes column and reorders', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final initialCount = project!.activeColumns.length;
      final colToDelete = project.activeColumns.last;
      final result = await taskService.deleteColumn(project.id, colToDelete.id);
      expect(result, true);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(proj.activeColumns.length, initialCount - 1);
    });

    test('reorderColumns reorders columns', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final ids = project!.activeColumns.map((c) => c.id).toList();
      final reversed = ids.reversed.toList();

      final result = await taskService.reorderColumns(project.id, reversed);
      expect(result, true);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(proj.activeColumns.first.id, reversed.first);
    });

    test('getColumnStatus returns correct status', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final todoCol = project!.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(taskService.getColumnStatus(todoCol.id), TaskStatus.todo);
    });

    test('getColumnStatus defaults to todo for unknown column', () {
      expect(taskService.getColumnStatus('nonexistent'), TaskStatus.todo);
    });
  });

  // ── Column Management Tests (extended) ──

  group('Column Management Tests', () {
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

    test('addColumn adds column to project', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      final initialCols = project!.activeColumns.length;

      final col = BoardColumn(
        id: 'custom-col',
        title: 'Custom',
        status: TaskStatus.inReview,
      );
      final result = await taskService.addColumn(project.id, col);
      expect(result, isTrue);

      final updated =
          taskService.projects.firstWhere((p) => p.id == project.id);
      expect(updated.activeColumns.length, initialCols + 1);
    });

    test('addColumn returns false for missing project', () async {
      final col = BoardColumn(
        id: 'x',
        title: 'X',
        status: TaskStatus.todo,
      );
      final result = await taskService.addColumn(
          '550e8400-e29b-41d4-a716-446655440999', col);
      expect(result, isFalse);
    });

    test('updateColumn modifies existing column', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final firstCol = project!.activeColumns.first;
      final updated = firstCol.copyWith(title: 'Renamed');
      final result = await taskService.updateColumn(project.id, updated);
      expect(result, isTrue);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(proj.activeColumns.first.title, 'Renamed');
    });

    test('updateColumn returns false for missing project', () async {
      final col = BoardColumn(id: 'x', title: 'X', status: TaskStatus.todo);
      final result = await taskService.updateColumn(
          '550e8400-e29b-41d4-a716-446655440999', col);
      expect(result, isFalse);
    });

    test('deleteColumn removes column', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      final initialCols = project!.activeColumns.length;
      final colId = project.activeColumns.last.id;

      final result = await taskService.deleteColumn(project.id, colId);
      expect(result, isTrue);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(proj.activeColumns.length, initialCols - 1);
    });

    test('deleteColumn returns false for missing project', () async {
      final result = await taskService.deleteColumn(
          '550e8400-e29b-41d4-a716-446655440999', 'col');
      expect(result, isFalse);
    });

    test('reorderColumns changes column order', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final colIds =
          project!.activeColumns.map((c) => c.id).toList().reversed.toList();
      final result = await taskService.reorderColumns(project.id, colIds);
      expect(result, isTrue);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(proj.activeColumns.first.id, colIds.first);
    });

    test('reorderColumns returns false for missing project', () async {
      final result = await taskService
          .reorderColumns('550e8400-e29b-41d4-a716-446655440999', ['a']);
      expect(result, isFalse);
    });

    test('getColumnStatus returns correct status', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final todoCol =
          project!.activeColumns.firstWhere((c) => c.status == TaskStatus.todo);
      final status =
          taskService.getColumnStatus(todoCol.id, projectId: project.id);
      expect(status, TaskStatus.todo);
    });

    test('getColumnStatus returns todo for missing column', () async {
      final status = taskService.getColumnStatus('nonexistent');
      expect(status, TaskStatus.todo);
    });

    test('getColumnStatus searches all projects when no projectId', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final doneCol =
          project!.activeColumns.firstWhere((c) => c.status == TaskStatus.done);
      final status = taskService.getColumnStatus(doneCol.id);
      expect(status, TaskStatus.done);
    });
  });

  // ── Board Management Tests ──

  group('Board Management Tests', () {
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

    test('addBoard adds board to project', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final board = Board(
        id: 'new-board',
        title: 'Sprint Board',
        createdAt: DateTime.now(),
      );
      final result = await taskService.addBoard(project!.id, board);
      expect(result, true);

      final updated =
          taskService.projects.firstWhere((p) => p.id == project.id);
      expect(updated.boards.any((b) => b.id == 'new-board'), true);
      expect(updated.activeBoardId, 'new-board');
    });

    test('addBoard returns false for non-existent project', () async {
      final board = Board(id: 'b', title: 'B', createdAt: DateTime.now());
      expect(await taskService.addBoard('nonexistent', board), false);
    });

    test('updateBoard updates existing board', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final board = Board(
        id: 'new-board',
        title: 'Sprint',
        createdAt: DateTime.now(),
      );
      await taskService.addBoard(project!.id, board);

      final updated = Board(
        id: 'new-board',
        title: 'Sprint v2',
        createdAt: board.createdAt,
      );
      final result = await taskService.updateBoard(project.id, updated);
      expect(result, true);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(proj.boards.firstWhere((b) => b.id == 'new-board').title,
          'Sprint v2');
    });

    test('deleteBoard removes board', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final board = Board(
        id: 'second-board',
        title: 'Second',
        createdAt: DateTime.now(),
      );
      await taskService.addBoard(project!.id, board);

      final proj = taskService.projects.firstWhere((p) => p.id == project.id);
      final boardCount = proj.boards.length;

      final result = await taskService.deleteBoard(project.id, 'second-board');
      expect(result, true);

      final afterDelete =
          taskService.projects.firstWhere((p) => p.id == project.id);
      expect(afterDelete.boards.length, boardCount - 1);
    });

    test('deleteBoard prevents deleting last board', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      final proj = taskService.projects.firstWhere((p) => p.id == project!.id);
      expect(proj.boards.length, 1);

      final result =
          await taskService.deleteBoard(project!.id, proj.boards.first.id);
      expect(result, false);
    });

    test('selectBoard changes active board', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      final board = Board(
        id: 'alt-board',
        title: 'Alt',
        createdAt: DateTime.now(),
      );
      await taskService.addBoard(project.id, board);

      final originalBoardId = project.boards.first.id;
      taskService.selectBoard(originalBoardId);

      final updated =
          taskService.projects.firstWhere((p) => p.id == project.id);
      expect(updated.activeBoardId, originalBoardId);
    });
  });
}
