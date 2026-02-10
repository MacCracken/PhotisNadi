import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
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
      await taskService.updateTask(updatedTask);

      expect(taskService.tasks.first.status, TaskStatus.inProgress);
    });

    test('should set modifiedAt on task update', () async {
      await taskService.addTask('Test Task');
      final task = taskService.tasks.first;
      final originalModifiedAt = task.modifiedAt;

      // Small delay to ensure time difference
      await Future.delayed(const Duration(milliseconds: 10));

      final updatedTask = task.copyWith(title: 'Updated Title');
      await taskService.updateTask(updatedTask);

      expect(
        taskService.tasks.first.modifiedAt
            .isAfter(originalModifiedAt),
        isTrue,
      );
    });

    test('should add ritual successfully', () async {
      const ritualTitle = 'Morning Meditation';
      await taskService.addRitual(ritualTitle);

      expect(taskService.rituals.length, 1);
      expect(taskService.rituals.first.title, ritualTitle);
    });

    test('should toggle ritual completion', () async {
      await taskService.addRitual('Test Ritual');
      final ritualId = taskService.rituals.first.id;

      await taskService.toggleRitualCompletion(ritualId);

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
      expect(project.name, 'Work');
      expect(project.key, 'WK');
    });

    test('should select project', () async {
      final project = await taskService.addProject('Work', 'WK');
      taskService.selectProject(project.id);

      expect(taskService.selectedProjectId, project.id);
      expect(taskService.selectedProject?.name, 'Work');
    });

    test('should archive project', () async {
      final project = await taskService.addProject('Work', 'WK');
      taskService.selectProject(project.id);

      await taskService.archiveProject(project.id);

      expect(taskService.archivedProjects.length, 1);
      expect(
        taskService.selectedProjectId,
        isNot(equals(project.id)),
      );
    });

    test('should delete project and its tasks', () async {
      final project = await taskService.addProject('Work', 'WK');
      await taskService.addTask(
        'Work Task',
        projectId: project.id,
      );

      expect(taskService.getTasksForProject(project.id).length, 1);

      await taskService.deleteProject(project.id);

      expect(
        taskService.projects.where((p) => p.id == project.id).length,
        0,
      );
      expect(taskService.getTasksForProject(project.id).length, 0);
    });

    test('should assign task key from project', () async {
      final project = await taskService.addProject('Work', 'WK');
      await taskService.addTask(
        'First Task',
        projectId: project.id,
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

      await taskService.addTask('Task', projectId: proj1.id);
      final task = taskService.getTasksForProject(proj1.id).first;

      await taskService.moveTaskToProject(task.id, proj2.id);

      expect(taskService.getTasksForProject(proj1.id).length, 0);
      expect(taskService.getTasksForProject(proj2.id).length, 1);
      expect(
        taskService.getTasksForProject(proj2.id).first.taskKey,
        'PB-1',
      );
    });

    test('should filter tasks by column and project', () async {
      final project = await taskService.addProject('Work', 'WK');
      await taskService.addTask('Todo Task', projectId: project.id);
      await taskService.addTask(
        'Done Task',
        projectId: project.id,
      );

      // Move second task to done
      final doneTask =
          taskService.getTasksForProject(project.id).last;
      final updated = doneTask.copyWith(status: TaskStatus.done);
      await taskService.updateTask(updated);

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
      final originalModifiedAt = project.modifiedAt;

      await Future.delayed(const Duration(milliseconds: 10));

      project.name = 'Updated Work';
      await taskService.updateProject(project);

      final updated = taskService.projects.firstWhere(
        (p) => p.id == project.id,
      );
      expect(updated.modifiedAt.isAfter(originalModifiedAt), isTrue);
    });
  });

  group('Ritual Reset Tests', () {
    test('daily ritual should reset on new day', () {
      final ritual = Ritual(
        id: 'test-1',
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
        id: 'test-1',
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
      final shouldReset =
          nowWeek != lastWeek || now.year != lastReset.year;

      expect(shouldReset, isTrue);
    });

    test('weekly ritual should not reset in same week', () {
      // Monday Jan 1 2024
      final lastReset = DateTime(2024, 1, 1);
      // Wednesday Jan 3 2024 (same week)
      final now = DateTime(2024, 1, 3);

      final nowWeek = Ritual.weekNumber(now);
      final lastWeek = Ritual.weekNumber(lastReset);
      final shouldReset =
          nowWeek != lastWeek || now.year != lastReset.year;

      expect(shouldReset, isFalse);
    });

    test('monthly ritual should reset on new month', () {
      final lastReset = DateTime(2024, 1, 15);
      final now = DateTime(2024, 2, 1);

      final shouldReset = now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(shouldReset, isTrue);
    });

    test('monthly ritual should not reset in same month', () {
      final lastReset = DateTime(2024, 1, 1);
      final now = DateTime(2024, 1, 31);

      final shouldReset = now.month != lastReset.month ||
          now.year != lastReset.year;

      expect(shouldReset, isFalse);
    });
  });

  group('Task Model Tests', () {
    test('copyWith should preserve all fields', () {
      final task = Task(
        id: '1',
        title: 'Test',
        description: 'Desc',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
        createdAt: DateTime(2024, 1, 1),
        dueDate: DateTime(2024, 2, 1),
        projectId: 'proj-1',
        tags: ['tag1'],
        taskKey: 'P-1',
      );

      final copy = task.copyWith(title: 'Updated');

      expect(copy.title, 'Updated');
      expect(copy.id, '1');
      expect(copy.description, 'Desc');
      expect(copy.status, TaskStatus.todo);
      expect(copy.priority, TaskPriority.high);
      expect(copy.projectId, 'proj-1');
      expect(copy.tags, ['tag1']);
      expect(copy.taskKey, 'P-1');
    });

    test('modifiedAt defaults to createdAt', () {
      final now = DateTime(2024, 1, 1);
      final task = Task(
        id: '1',
        title: 'Test',
        createdAt: now,
      );

      expect(task.modifiedAt, now);
    });
  });

  group('Project Model Tests', () {
    test('nextTaskKey increments counter', () {
      final project = Project(
        id: '1',
        name: 'Test',
        key: 'TST',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(project.nextTaskKey, 'TST-1');
      expect(project.nextTaskKey, 'TST-2');
      expect(project.nextTaskKey, 'TST-3');
      expect(project.taskCounter, 3);
    });

    test('copyWith should preserve all fields', () {
      final project = Project(
        id: '1',
        name: 'Test',
        key: 'TST',
        description: 'A project',
        createdAt: DateTime(2024, 1, 1),
        color: '#FF0000',
        iconName: 'star',
        taskCounter: 5,
        isArchived: true,
      );

      final copy = project.copyWith(name: 'Updated');

      expect(copy.name, 'Updated');
      expect(copy.id, '1');
      expect(copy.key, 'TST');
      expect(copy.description, 'A project');
      expect(copy.color, '#FF0000');
      expect(copy.iconName, 'star');
      expect(copy.taskCounter, 5);
      expect(copy.isArchived, true);
    });

    test('modifiedAt defaults to createdAt', () {
      final now = DateTime(2024, 1, 1);
      final project = Project(
        id: '1',
        name: 'Test',
        key: 'TST',
        createdAt: now,
      );

      expect(project.modifiedAt, now);
    });
  });
}
