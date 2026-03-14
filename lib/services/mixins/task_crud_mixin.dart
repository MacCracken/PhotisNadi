import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/task.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/project_repository.dart';

mixin TaskCrudMixin on ChangeNotifier {
  TaskRepository get taskRepo;
  ProjectRepository get projectRepo;
  String? get selectedProjectId;

  // ── Task CRUD ──

  Future<Task?> addTask(
    String title, {
    String? description,
    TaskPriority? priority,
    String? projectId,
    List<String>? tags,
    DateTime? dueDate,
  }) async {
    try {
      const uuid = Uuid();
      final targetProjectId = projectId ?? selectedProjectId;
      String? taskKey;

      if (targetProjectId != null) {
        final project = projectRepo.get(targetProjectId);
        if (project != null) {
          taskKey = project.generateNextTaskKey();
          await project.save();
        }
      }

      final task = Task(
        id: uuid.v4(),
        title: title,
        description: description,
        priority: priority ?? TaskPriority.medium,
        createdAt: DateTime.now(),
        projectId: targetProjectId,
        taskKey: taskKey,
        tags: tags ?? [],
        dueDate: dueDate,
      );

      await taskRepo.put(task);
      notifyListeners();
      return task;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to add task: $title',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> updateTask(Task task) async {
    try {
      task.modifiedAt = DateTime.now();
      await taskRepo.put(task);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update task: ${task.id}',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      await taskRepo.delete(taskId);
      await taskRepo.removeDependencyReferences(taskId);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete task: $taskId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> restoreTask(Task task) async {
    try {
      await taskRepo.put(task);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to restore task: ${task.id}',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ── Task Dependencies ──

  Future<bool> addTaskDependency(String taskId, String dependsOnTaskId) async {
    try {
      final task = taskRepo.get(taskId);
      if (task == null) return false;
      if (taskId == dependsOnTaskId) return false;
      if (task.dependsOn.contains(dependsOnTaskId)) return false;
      if (_wouldCreateCircularDependency(taskId, dependsOnTaskId)) return false;

      task.dependsOn = [...task.dependsOn, dependsOnTaskId];
      task.modifiedAt = DateTime.now();
      await task.save();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to add dependency: $taskId -> $dependsOnTaskId',
          name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> removeTaskDependency(
      String taskId, String dependsOnTaskId) async {
    try {
      final task = taskRepo.get(taskId);
      if (task == null) return false;
      task.dependsOn =
          task.dependsOn.where((id) => id != dependsOnTaskId).toList();
      task.modifiedAt = DateTime.now();
      await task.save();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
          'Failed to remove dependency: $taskId -> $dependsOnTaskId',
          name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  bool _wouldCreateCircularDependency(String taskId, String newDepId) {
    final visited = <String>{};
    final toVisit = [newDepId];

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      if (current == taskId) return true;
      if (visited.contains(current)) continue;
      visited.add(current);

      final task = taskRepo.get(current);
      if (task != null) {
        toVisit.addAll(task.dependsOn);
      }
    }
    return false;
  }

  List<Task> getTaskDependencies(String taskId) {
    final task = taskRepo.get(taskId);
    if (task == null) return [];
    return task.dependsOn
        .map((id) => taskRepo.get(id))
        .whereType<Task>()
        .toList();
  }

  List<Task> getDependentTasks(String taskId) {
    return taskRepo.where((t) => t.dependsOn.contains(taskId));
  }

  bool isTaskBlocked(Task task) {
    if (task.status == TaskStatus.done) return false;
    for (final depId in task.dependsOn) {
      final depTask = taskRepo.get(depId);
      if (depTask != null && depTask.status != TaskStatus.done) return true;
    }
    return false;
  }

  bool canMoveTask(Task task, TaskStatus newStatus) {
    if (newStatus == TaskStatus.done && isTaskBlocked(task)) {
      return false;
    }
    return true;
  }

  Future<bool> moveTaskToProject(String taskId, String? newProjectId) async {
    try {
      final task = taskRepo.get(taskId);
      if (task == null) return false;
      task.projectId = newProjectId;

      if (newProjectId != null) {
        final project = projectRepo.get(newProjectId);
        if (project != null) {
          task.taskKey = project.generateNextTaskKey();
          await project.save();
        } else {
          task.taskKey = null;
        }
      } else {
        task.taskKey = null;
      }

      await taskRepo.put(task);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to move task: $taskId to project: $newProjectId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ── Subtask operations ──

  Future<bool> addSubtask(String taskId, String title) async {
    final task = taskRepo.get(taskId);
    if (task == null) return false;
    task.addSubtask(title);
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> toggleSubtask(String taskId, int index) async {
    final task = taskRepo.get(taskId);
    if (task == null) return false;
    task.toggleSubtask(index);
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> removeSubtask(String taskId, int index) async {
    final task = taskRepo.get(taskId);
    if (task == null) return false;
    task.removeSubtask(index);
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  // ── Time tracking ──

  Future<bool> logTime(String taskId, int minutes) async {
    final task = taskRepo.get(taskId);
    if (task == null || minutes <= 0) return false;
    task.trackedMinutes += minutes;
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> setEstimate(String taskId, int? minutes) async {
    final task = taskRepo.get(taskId);
    if (task == null) return false;
    task.estimatedMinutes = minutes;
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  // ── Attachments ──

  Future<bool> addAttachment(String taskId, String filePath) async {
    final task = taskRepo.get(taskId);
    if (task == null) return false;
    task.attachments = [...task.attachments, filePath];
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> removeAttachment(String taskId, int index) async {
    final task = taskRepo.get(taskId);
    if (task == null || index < 0 || index >= task.attachments.length) {
      return false;
    }
    task.attachments = List.of(task.attachments)..removeAt(index);
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  // ── Recurrence ──

  Future<bool> setRecurrence(String taskId, String? recurrence) async {
    final task = taskRepo.get(taskId);
    if (task == null) return false;
    if (recurrence != null &&
        !['daily', 'weekly', 'monthly'].contains(recurrence)) {
      return false;
    }
    task.recurrence = recurrence;
    task.modifiedAt = DateTime.now();
    await taskRepo.put(task);
    notifyListeners();
    return true;
  }

  /// Check recurring tasks and create new instances if the completed one is due.
  Future<void> processRecurringTasks() async {
    final now = DateTime.now();
    final recurringDone = taskRepo.all
        .where((t) => t.recurrence != null && t.status == TaskStatus.done)
        .toList();

    for (final task in recurringDone) {
      DateTime? nextDue;
      if (task.dueDate != null) {
        switch (task.recurrence) {
          case 'daily':
            nextDue = task.dueDate!.add(const Duration(days: 1));
          case 'weekly':
            nextDue = task.dueDate!.add(const Duration(days: 7));
          case 'monthly':
            // Clamp day to the last day of the next month to avoid overflow
            // (e.g., Jan 31 -> Feb 28, not Mar 3)
            final nextMonth = task.dueDate!.month + 1;
            final nextYear =
                task.dueDate!.year + (nextMonth > 12 ? 1 : 0);
            final month = nextMonth > 12 ? nextMonth - 12 : nextMonth;
            final lastDay = DateTime(nextYear, month + 1, 0).day;
            final day =
                task.dueDate!.day > lastDay ? lastDay : task.dueDate!.day;
            nextDue = DateTime(nextYear, month, day);
        }
      }

      // Only create next occurrence if it's due
      if (nextDue != null &&
          !nextDue.isAfter(now.add(const Duration(days: 1)))) {
        const uuid = Uuid();
        final newTask = Task(
          id: uuid.v4(),
          title: task.title,
          description: task.description,
          priority: task.priority,
          createdAt: now,
          dueDate: nextDue,
          projectId: task.projectId,
          tags: List.of(task.tags),
          recurrence: task.recurrence,
          estimatedMinutes: task.estimatedMinutes,
          subtasks: task.subtasks.map((s) {
            // Reset all subtasks to incomplete
            final title = s.length > 2 ? s.substring(2) : '';
            return '0:$title';
          }).toList(),
        );

        // Assign task key if in a project
        if (task.projectId != null) {
          final project = projectRepo.get(task.projectId!);
          if (project != null) {
            newTask.taskKey = project.generateNextTaskKey();
            await project.save();
          }
        }

        await taskRepo.put(newTask);

        // Clear recurrence from the completed task so it doesn't trigger again
        task.recurrence = null;
        await taskRepo.put(task);
      }
    }
    notifyListeners();
  }
}
