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

  // ── Due Date Tests ──

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

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
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

  // ── Task Service Query Tests ──

  group('Task Service Query Tests', () {
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

    test('getTasksForProject returns project tasks', () async {
      final project = await taskService.addProject('Test', 'TST');
      await taskService.addTask('In Project', projectId: project!.id);
      await taskService.addTask('Also In Project', projectId: project.id);

      final tasks = taskService.getTasksForProject(project.id);
      expect(tasks.length, 2);
    });

    test('getTasksForSelectedProject returns selected project tasks', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      await taskService.addTask('Selected', projectId: project.id);

      final tasks = taskService.getTasksForSelectedProject();
      expect(tasks.any((t) => t.title == 'Selected'), true);
    });

    test('getTasksForColumn returns tasks by status', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      final t = await taskService.addTask('Todo Task', projectId: project.id);
      expect(t, isNotNull);

      final todoCol = project.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final tasks =
          taskService.getTasksForColumn(todoCol.id, projectId: project.id);
      expect(tasks.any((t) => t.title == 'Todo Task'), true);
    });

    test('getTaskCountForColumn returns count', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      await taskService.addTask('T1', projectId: project.id);
      await taskService.addTask('T2', projectId: project.id);

      final todoCol = project.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(
          taskService.getTaskCountForColumn(todoCol.id, projectId: project.id),
          2);
    });

    test('getTasksForColumnPaginated respects page size', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      for (var i = 0; i < 5; i++) {
        await taskService.addTask('Task $i', projectId: project.id);
      }

      final todoCol = project.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final page0 = taskService.getTasksForColumnPaginated(
        todoCol.id,
        projectId: project.id,
        page: 0,
        pageSize: 3,
      );
      expect(page0.length, 3);

      final page1 = taskService.getTasksForColumnPaginated(
        todoCol.id,
        projectId: project.id,
        page: 1,
        pageSize: 3,
      );
      expect(page1.length, 2);
    });

    test('hasMoreTasksForColumn checks pagination', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      for (var i = 0; i < 5; i++) {
        await taskService.addTask('Task $i', projectId: project.id);
      }

      final todoCol = project.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(
          taskService.hasMoreTasksForColumn(
            todoCol.id,
            projectId: project.id,
            page: 0,
            pageSize: 3,
          ),
          true);
      expect(
          taskService.hasMoreTasksForColumn(
            todoCol.id,
            projectId: project.id,
            page: 1,
            pageSize: 3,
          ),
          false);
    });

    test('clearError clears error state', () {
      taskService.clearError();
      expect(taskService.error, isNull);
    });

    test('isLoading is false after init', () {
      expect(taskService.isLoading, false);
    });

    test('init creates default project when none exist', () {
      // After init, there should be at least one project
      expect(taskService.projects, isNotEmpty);
      expect(taskService.selectedProjectId, isNotNull);
    });
  });

  // ── Recurring Tasks Tests ──

  group('Recurring Tasks Tests', () {
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

    test('processRecurringTasks creates next daily occurrence', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = await taskService.addTask('Daily Task', dueDate: yesterday);
      expect(task, isNotNull);

      // Set as recurring and complete
      await taskService.setRecurrence(task!.id, 'daily');
      task.status = TaskStatus.done;
      await taskService.updateTask(task);

      final countBefore = taskService.tasks.length;
      await taskService.processRecurringTasks();
      expect(taskService.tasks.length, greaterThan(countBefore));

      // Original should have recurrence cleared
      final original = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(original.recurrence, isNull);
    });

    test('processRecurringTasks skips tasks without due date', () async {
      final task = await taskService.addTask('No Due');
      await taskService.setRecurrence(task!.id, 'daily');
      task.status = TaskStatus.done;
      await taskService.updateTask(task);

      final countBefore = taskService.tasks.length;
      await taskService.processRecurringTasks();
      // No new task created since no due date
      expect(taskService.tasks.length, countBefore);
    });

    test('processRecurringTasks handles weekly recurrence', () async {
      final pastDue = DateTime.now().subtract(const Duration(days: 7));
      final task = await taskService.addTask('Weekly Task', dueDate: pastDue);
      await taskService.setRecurrence(task!.id, 'weekly');
      task.status = TaskStatus.done;
      await taskService.updateTask(task);

      final countBefore = taskService.tasks.length;
      await taskService.processRecurringTasks();
      expect(taskService.tasks.length, greaterThan(countBefore));
    });

    test('processRecurringTasks handles monthly recurrence', () async {
      final pastDue = DateTime.now().subtract(const Duration(days: 31));
      final task = await taskService.addTask('Monthly Task', dueDate: pastDue);
      await taskService.setRecurrence(task!.id, 'monthly');
      task.status = TaskStatus.done;
      await taskService.updateTask(task);

      final countBefore = taskService.tasks.length;
      await taskService.processRecurringTasks();
      expect(taskService.tasks.length, greaterThan(countBefore));
    });
  });

  // ── Filter and Sort Tests ──

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
      await taskService.addTask('Task',
          projectId: project!.id, priority: TaskPriority.high);
      await taskService.addTask('Task2',
          projectId: project.id, priority: TaskPriority.low);

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
      await taskService.addTask('Has date',
          projectId: project.id, dueDate: DateTime(2026, 6, 1));

      taskService.setSortBy(TaskSortBy.dueDate);
      taskService.setSortBy(TaskSortBy.dueDate); // ascending
      final results = taskService.getFilteredTasks(project.id);
      expect(results.first.title, 'Has date');
      expect(results.last.title, 'No date');
    });
  });

  // ── Filter Sort Mixin Extended Tests ──

  group('Filter Sort Mixin Extended Tests', () {
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

    test('setSearchQuery normalizes to lowercase', () {
      taskService.setSearchQuery('HELLO World');
      expect(taskService.searchQuery, 'hello world');
    });

    test('setFilterStatus sets and notifies', () {
      taskService.setFilterStatus(TaskStatus.done);
      expect(taskService.filterStatus, TaskStatus.done);
    });

    test('setFilterPriority sets and notifies', () {
      taskService.setFilterPriority(TaskPriority.high);
      expect(taskService.filterPriority, TaskPriority.high);
    });

    test('setFilterDueAfter sets and notifies', () {
      final date = DateTime(2026, 6, 1);
      taskService.setFilterDueAfter(date);
      expect(taskService.filterDueAfter, date);
    });

    test('clearFilterTags clears tags', () {
      taskService.toggleFilterTag('urgent');
      taskService.toggleFilterTag('backend');
      expect(taskService.filterTags.length, 2);
      taskService.clearFilterTags();
      expect(taskService.filterTags, isEmpty);
    });

    test('hasActiveFilters detects active filters', () {
      expect(taskService.hasActiveFilters, false);
      taskService.setSearchQuery('test');
      expect(taskService.hasActiveFilters, true);
      taskService.clearFilters();
      expect(taskService.hasActiveFilters, false);

      taskService.setFilterStatus(TaskStatus.todo);
      expect(taskService.hasActiveFilters, true);
      taskService.clearFilters();

      taskService.setFilterPriority(TaskPriority.high);
      expect(taskService.hasActiveFilters, true);
      taskService.clearFilters();

      taskService.toggleFilterTag('tag');
      expect(taskService.hasActiveFilters, true);
      taskService.clearFilters();

      taskService.setFilterDueBefore(DateTime.now());
      expect(taskService.hasActiveFilters, true);
      taskService.clearFilters();

      taskService.setFilterDueAfter(DateTime.now());
      expect(taskService.hasActiveFilters, true);
    });

    test('getFilteredTasks filters by due date range', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Past Due',
          projectId: project.id, dueDate: DateTime(2026, 1, 1));
      await taskService.addTask('Future Due',
          projectId: project.id, dueDate: DateTime(2026, 12, 1));
      await taskService.addTask('No Due', projectId: project.id);

      taskService.setFilterDueAfter(DateTime(2026, 6, 1));
      final filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 1);
      expect(filtered.first.title, 'Future Due');
    });

    test('getFilteredTasks sorts by priority', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      await taskService.addTask('Low Task',
          projectId: project!.id, priority: TaskPriority.low);
      await taskService.addTask('High Task',
          projectId: project.id, priority: TaskPriority.high);
      await taskService.addTask('Med Task',
          projectId: project.id, priority: TaskPriority.medium);

      taskService.setSortBy(TaskSortBy.priority);
      final sorted = taskService.getFilteredTasks(project.id);
      // Descending by default: high, medium, low
      expect(sorted.first.priority, TaskPriority.high);
      expect(sorted.last.priority, TaskPriority.low);
    });

    test('getFilteredTasks searches description and taskKey', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);

      await taskService.addTask('Generic Title',
          projectId: project!.id, description: 'unique-keyword');
      await taskService.addTask('Another Task', projectId: project.id);

      taskService.setSearchQuery('unique-keyword');
      final filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 1);
      expect(filtered.first.title, 'Generic Title');
    });
  });

  // ── TaskCrud Extended Tests ──

  group('TaskCrud Extended Tests', () {
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

    test('addSubtask adds subtask to task', () async {
      final task = await taskService.addTask('Parent');
      expect(task, isNotNull);

      final result = await taskService.addSubtask(task!.id, 'Child subtask');
      expect(result, true);

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.subtasks.length, 1);
      expect(updated.parsedSubtasks.first.title, 'Child subtask');
    });

    test('toggleSubtask toggles subtask completion', () async {
      final task = await taskService.addTask('Parent');
      await taskService.addSubtask(task!.id, 'Sub');

      await taskService.toggleSubtask(task.id, 0);
      var updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.parsedSubtasks.first.done, true);

      await taskService.toggleSubtask(task.id, 0);
      updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.parsedSubtasks.first.done, false);
    });

    test('removeSubtask removes subtask', () async {
      final task = await taskService.addTask('Parent');
      await taskService.addSubtask(task!.id, 'Sub 1');
      await taskService.addSubtask(task.id, 'Sub 2');

      final result = await taskService.removeSubtask(task.id, 0);
      expect(result, true);

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.subtasks.length, 1);
    });

    test('logTime adds tracked minutes', () async {
      final task = await taskService.addTask('Timed');
      expect(task, isNotNull);

      await taskService.logTime(task!.id, 30);
      await taskService.logTime(task.id, 15);

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.trackedMinutes, 45);
    });

    test('logTime rejects zero or negative minutes', () async {
      final task = await taskService.addTask('Timed');
      expect(await taskService.logTime(task!.id, 0), false);
      expect(await taskService.logTime(task.id, -5), false);
    });

    test('setEstimate sets estimated minutes', () async {
      final task = await taskService.addTask('Estimated');
      await taskService.setEstimate(task!.id, 120);

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.estimatedMinutes, 120);
    });

    test('setEstimate clears with null', () async {
      final task = await taskService.addTask('Estimated');
      await taskService.setEstimate(task!.id, 60);
      await taskService.setEstimate(task.id, null);

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.estimatedMinutes, isNull);
    });

    test('addAttachment adds file path', () async {
      final task = await taskService.addTask('Attached');
      await taskService.addAttachment(task!.id, '/path/to/file.pdf');

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.attachments, ['/path/to/file.pdf']);
    });

    test('removeAttachment removes at index', () async {
      final task = await taskService.addTask('Attached');
      await taskService.addAttachment(task!.id, '/file1.pdf');
      await taskService.addAttachment(task.id, '/file2.pdf');

      await taskService.removeAttachment(task.id, 0);
      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.attachments, ['/file2.pdf']);
    });

    test('removeAttachment rejects invalid index', () async {
      final task = await taskService.addTask('Attached');
      expect(await taskService.removeAttachment(task!.id, -1), false);
      expect(await taskService.removeAttachment(task.id, 0), false);
    });

    test('setRecurrence sets valid recurrence', () async {
      final task = await taskService.addTask('Recurring');
      expect(await taskService.setRecurrence(task!.id, 'daily'), true);
      expect(await taskService.setRecurrence(task.id, 'weekly'), true);
      expect(await taskService.setRecurrence(task.id, 'monthly'), true);
      expect(await taskService.setRecurrence(task.id, null), true);
    });

    test('setRecurrence rejects invalid recurrence', () async {
      final task = await taskService.addTask('Recurring');
      expect(await taskService.setRecurrence(task!.id, 'yearly'), false);
      expect(await taskService.setRecurrence(task.id, 'biweekly'), false);
    });

    test('moveTaskToProject moves task and generates key', () async {
      final project = await taskService.addProject('Dest', 'DST');
      final task = await taskService.addTask('Movable');
      expect(task, isNotNull);

      final result = await taskService.moveTaskToProject(task!.id, project!.id);
      expect(result, true);

      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.projectId, project.id);
      expect(updated.taskKey, 'DST-1');
    });

    test('moveTaskToProject clears key when moved to null project', () async {
      final project = await taskService.addProject('Src', 'SRC');
      final task = await taskService.addTask('Movable', projectId: project!.id);
      expect(task!.taskKey, 'SRC-1');

      await taskService.moveTaskToProject(task.id, null);
      final updated = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updated.projectId, isNull);
      expect(updated.taskKey, isNull);
    });

    test('canMoveTask blocks done for blocked tasks', () async {
      final t1 = await taskService.addTask('Blocker');
      final t2 = await taskService.addTask('Blocked');
      await taskService.addTaskDependency(t2!.id, t1!.id);

      final blocked = taskService.tasks.firstWhere((t) => t.id == t2.id);
      expect(taskService.canMoveTask(blocked, TaskStatus.done), false);
      expect(taskService.canMoveTask(blocked, TaskStatus.inProgress), true);
    });

    test('isTaskBlocked returns false for done tasks', () async {
      final t1 = await taskService.addTask('Blocker');
      final t2 = await taskService.addTask('Blocked');
      await taskService.addTaskDependency(t2!.id, t1!.id);

      // Mark blocked task as done - should not be considered blocked
      t2.status = TaskStatus.done;
      expect(taskService.isTaskBlocked(t2), false);
    });

    test('getDependentTasks returns tasks that depend on given task', () async {
      final t1 = await taskService.addTask('Base');
      final t2 = await taskService.addTask('Depends');
      await taskService.addTaskDependency(t2!.id, t1!.id);

      final dependents = taskService.getDependentTasks(t1.id);
      expect(dependents.length, 1);
      expect(dependents.first.id, t2.id);
    });
  });

  // ── Task Service Filtered Column Tests ──

  group('Task Service Filtered Column Tests', () {
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

    test('getTasksForColumnPaginated with active filters', () async {
      final project = await taskService.addProject('Filter Col', 'FC');
      taskService.selectProject(project!.id);

      await taskService.addTask('Match A', projectId: project.id);
      await taskService.addTask('Match B', projectId: project.id);
      await taskService.addTask('No Match',
          projectId: project.id, priority: TaskPriority.high);

      taskService.setFilterPriority(TaskPriority.medium);

      final todoCol = project.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final tasks = taskService.getTasksForColumnPaginated(
        todoCol.id,
        projectId: project.id,
        page: 0,
        pageSize: 10,
      );
      expect(tasks.length, 2);
    });

    test('getTaskCountForColumn with active filters', () async {
      final project = await taskService.addProject('Count', 'CNT');
      taskService.selectProject(project!.id);

      await taskService.addTask('A', projectId: project.id);
      await taskService.addTask('B',
          projectId: project.id, priority: TaskPriority.high);

      taskService.setFilterPriority(TaskPriority.medium);

      final todoCol = project.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(
          taskService.getTaskCountForColumn(todoCol.id, projectId: project.id),
          1);
    });

    test('getTasksForColumnPaginated returns empty for out-of-range page',
        () async {
      final project = await taskService.addProject('Empty', 'EM');
      taskService.selectProject(project!.id);
      await taskService.addTask('Task', projectId: project.id);

      final todoCol = project.activeColumns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final tasks = taskService.getTasksForColumnPaginated(
        todoCol.id,
        projectId: project.id,
        page: 100,
        pageSize: 10,
      );
      expect(tasks, isEmpty);
    });

    test('getTasksForColumn returns empty when no project selected', () {
      taskService.selectProject(null);
      final tasks = taskService.getTasksForColumn('todo');
      expect(tasks, isEmpty);
    });
  });

  // ── Sort Due Date Edge Cases ──

  group('Sort Due Date Edge Cases', () {
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

    test('sorts by due date with both dates present', () async {
      final project = await taskService.addProject('Sort', 'SRT');
      await taskService.addTask('Early',
          projectId: project!.id, dueDate: DateTime(2026, 1, 1));
      await taskService.addTask('Late',
          projectId: project.id, dueDate: DateTime(2026, 12, 1));

      taskService.setSortBy(TaskSortBy.dueDate);
      final sorted = taskService.getFilteredTasks(project.id);
      // Descending by default: late first
      expect(sorted.first.title, 'Late');
      expect(sorted.last.title, 'Early');
    });

    test('sorts by due date with one null and one present', () async {
      final project = await taskService.addProject('Sort', 'SRT');
      await taskService.addTask('Has Due',
          projectId: project!.id, dueDate: DateTime(2026, 6, 1));
      await taskService.addTask('No Due', projectId: project.id);

      taskService.setSortBy(TaskSortBy.dueDate);
      final sorted = taskService.getFilteredTasks(project.id);
      expect(sorted.length, 2);
      final titles = sorted.map((t) => t.title).toList();
      expect(titles, containsAll(['Has Due', 'No Due']));
    });

    test('sorts by due date with both null', () async {
      final project = await taskService.addProject('Sort', 'SRT');
      await taskService.addTask('A', projectId: project!.id);
      await taskService.addTask('B', projectId: project.id);

      taskService.setSortBy(TaskSortBy.dueDate);
      final sorted = taskService.getFilteredTasks(project.id);
      expect(sorted.length, 2);
    });

    test('sorts ascending when toggled', () async {
      final project = await taskService.addProject('Sort', 'SRT');
      await taskService.addTask('Early',
          projectId: project!.id, dueDate: DateTime(2026, 1, 1));
      await taskService.addTask('Late',
          projectId: project.id, dueDate: DateTime(2026, 12, 1));

      taskService.setSortBy(TaskSortBy.dueDate);
      taskService.setSortBy(TaskSortBy.dueDate); // toggle ascending
      expect(taskService.sortAscending, true);

      final sorted = taskService.getFilteredTasks(project.id);
      expect(sorted.first.title, 'Early');
    });

    test('sorts by createdAt', () async {
      final project = await taskService.addProject('Sort', 'SRT');
      await taskService.addTask('First', projectId: project!.id);
      await taskService.addTask('Second', projectId: project.id);

      taskService.setSortBy(TaskSortBy.createdAt);
      final sorted = taskService.getFilteredTasks(project.id);
      expect(sorted.length, 2);
    });
  });

  // ── Subtask & Time Tracking Tests ──

  group('Subtask & Time Tracking Tests', () {
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

    test('addSubtask adds to task', () async {
      final task = await taskService.addTask('Parent');
      expect(task, isNotNull);

      final result = await taskService.addSubtask(task!.id, 'Child');
      expect(result, isTrue);
      expect(task.parsedSubtasks.length, 1);
    });

    test('toggleSubtask toggles completion', () async {
      final task = await taskService.addTask('Parent');
      expect(task, isNotNull);
      await taskService.addSubtask(task!.id, 'Child');

      final result = await taskService.toggleSubtask(task.id, 0);
      expect(result, isTrue);
      expect(task.parsedSubtasks.first.done, isTrue);
    });

    test('removeSubtask removes from task', () async {
      final task = await taskService.addTask('Parent');
      expect(task, isNotNull);
      await taskService.addSubtask(task!.id, 'A');
      await taskService.addSubtask(task.id, 'B');

      final result = await taskService.removeSubtask(task.id, 0);
      expect(result, isTrue);
      expect(task.parsedSubtasks.length, 1);
    });

    test('logTime adds tracked minutes', () async {
      final task = await taskService.addTask('Tracked');
      expect(task, isNotNull);

      final result = await taskService.logTime(task!.id, 30);
      expect(result, isTrue);
      expect(task.trackedMinutes, 30);

      await taskService.logTime(task.id, 15);
      expect(task.trackedMinutes, 45);
    });

    test('logTime rejects zero or negative', () async {
      final task = await taskService.addTask('Tracked');
      expect(task, isNotNull);

      expect(await taskService.logTime(task!.id, 0), isFalse);
      expect(await taskService.logTime(task.id, -5), isFalse);
    });

    test('setEstimate sets minutes', () async {
      final task = await taskService.addTask('Estimated');
      expect(task, isNotNull);

      await taskService.setEstimate(task!.id, 120);
      expect(task.estimatedMinutes, 120);

      await taskService.setEstimate(task.id, null);
      expect(task.estimatedMinutes, isNull);
    });

    test('addAttachment adds path', () async {
      final task = await taskService.addTask('Attach');
      expect(task, isNotNull);

      final result = await taskService.addAttachment(task!.id, '/tmp/file.txt');
      expect(result, isTrue);
      expect(task.attachments, ['/tmp/file.txt']);
    });

    test('removeAttachment removes by index', () async {
      final task = await taskService.addTask('Attach');
      expect(task, isNotNull);
      await taskService.addAttachment(task!.id, '/tmp/a.txt');
      await taskService.addAttachment(task.id, '/tmp/b.txt');

      final result = await taskService.removeAttachment(task.id, 0);
      expect(result, isTrue);
      expect(task.attachments.length, 1);
      expect(task.attachments.first, '/tmp/b.txt');
    });

    test('removeAttachment rejects invalid index', () async {
      final task = await taskService.addTask('Attach');
      expect(task, isNotNull);

      expect(await taskService.removeAttachment(task!.id, -1), isFalse);
      expect(await taskService.removeAttachment(task.id, 0), isFalse);
    });

    test('setRecurrence sets valid values', () async {
      final task = await taskService.addTask('Recurring');
      expect(task, isNotNull);

      expect(await taskService.setRecurrence(task!.id, 'daily'), isTrue);
      expect(task.recurrence, 'daily');

      expect(await taskService.setRecurrence(task.id, 'weekly'), isTrue);
      expect(task.recurrence, 'weekly');

      expect(await taskService.setRecurrence(task.id, 'monthly'), isTrue);
      expect(task.recurrence, 'monthly');

      expect(await taskService.setRecurrence(task.id, null), isTrue);
      expect(task.recurrence, isNull);
    });

    test('setRecurrence rejects invalid value', () async {
      final task = await taskService.addTask('Recurring');
      expect(task, isNotNull);

      expect(await taskService.setRecurrence(task!.id, 'yearly'), isFalse);
    });
  });

  // ── Repository Tests ──

  group('Repository Tests', () {
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

    test('taskRepo.where filters tasks', () async {
      await taskService.addTask('High', priority: TaskPriority.high);
      await taskService.addTask('Low', priority: TaskPriority.low);

      final highTasks = taskService.taskRepo.where(
        (t) => t.priority == TaskPriority.high,
      );
      expect(highTasks.length, 1);
      expect(highTasks.first.title, 'High');
    });

    test('taskRepo.firstWhere finds matching task', () async {
      await taskService.addTask('FindMe');
      await taskService.addTask('NotMe');

      final found = taskService.taskRepo.firstWhere(
        (t) => t.title == 'FindMe',
      );
      expect(found, isNotNull);
      expect(found!.title, 'FindMe');
    });

    test('taskRepo.firstWhere returns null for no match', () {
      final found = taskService.taskRepo.firstWhere(
        (t) => t.title == 'NonExistent',
      );
      expect(found, isNull);
    });

    test('taskRepo.count reflects number of tasks', () async {
      final before = taskService.taskRepo.count;
      await taskService.addTask('Counted');
      expect(taskService.taskRepo.count, before + 1);
    });

    test('taskRepo.index is unmodifiable', () async {
      await taskService.addTask('Indexed');
      final index = taskService.taskRepo.index;
      expect(index, isNotEmpty);
      expect(() => (index as Map).clear(), throwsUnsupportedError);
    });

    test('projectRepo.active returns non-archived', () async {
      final p1 = await taskService.addProject('Active', 'ACT');
      final p2 = await taskService.addProject('Archived', 'ARC');
      await taskService.archiveProject(p2!.id);

      final active = taskService.projectRepo.active;
      expect(active.any((p) => p.id == p1!.id), true);
      expect(active.any((p) => p.id == p2.id), false);
    });

    test('projectRepo.archived returns archived only', () async {
      await taskService.addProject('Active', 'ACT');
      final p2 = await taskService.addProject('Archived', 'ARC');
      await taskService.archiveProject(p2!.id);

      final archived = taskService.projectRepo.archived;
      expect(archived.any((p) => p.id == p2.id), true);
    });
  });

  // ── Tag Mixin Extended Tests ──

  group('Tag Mixin Extended Tests', () {
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

    test('removeFilterTagOnDelete removes tag from filter', () {
      taskService.toggleFilterTag('urgent');
      expect(taskService.filterTags, contains('urgent'));

      taskService.removeFilterTagOnDelete('urgent');
      expect(taskService.filterTags, isNot(contains('urgent')));
    });

    test('removeFilterTagOnDelete does nothing for non-filtered tag', () {
      taskService.toggleFilterTag('keep');
      taskService.removeFilterTagOnDelete('other');
      expect(taskService.filterTags, contains('keep'));
    });
  });
}
