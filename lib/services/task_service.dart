import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';
import '../models/board.dart';
import '../models/tag.dart';
import '../common/constants.dart';
import '../repositories/task_repository.dart';
import '../repositories/project_repository.dart';
import '../repositories/ritual_repository.dart';
import '../repositories/tag_repository.dart';

/// Manages tasks, rituals, and projects with local storage using Hive.
class TaskService extends ChangeNotifier {
  final TaskRepository _taskRepo;
  final ProjectRepository _projectRepo;
  final RitualRepository _ritualRepo;
  final TagRepository _tagRepo;

  String? _selectedProjectId;
  bool _isLoading = true;
  String? _error;

  TaskService({
    TaskRepository? taskRepo,
    ProjectRepository? projectRepo,
    RitualRepository? ritualRepo,
    TagRepository? tagRepo,
  })  : _taskRepo = taskRepo ?? TaskRepository(),
        _projectRepo = projectRepo ?? ProjectRepository(),
        _ritualRepo = ritualRepo ?? RitualRepository(),
        _tagRepo = tagRepo ?? TagRepository();

  // Getters that delegate to repositories
  List<Task> get tasks => _taskRepo.all;
  List<Ritual> get rituals => _ritualRepo.all;
  List<Project> get projects => _projectRepo.all;
  List<Tag> get tags => _tagRepo.all;

  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get selectedProjectId => _selectedProjectId;

  Project? get selectedProject {
    if (_selectedProjectId == null) return null;
    return _projectRepo.get(_selectedProjectId!);
  }

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _taskRepo.init();
      await _ritualRepo.init();
      await _projectRepo.init();
      await _tagRepo.init();

      if (_projectRepo.count == 0) {
        await _createDefaultProject();
      }

      if (_selectedProjectId == null && _projectRepo.count > 0) {
        _selectedProjectId = _projectRepo.all.first.id;
      }

      await _checkRitualResets();
      await processRecurringTasks();
      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize task service',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      _error = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _createDefaultProject() async {
    try {
      const uuid = Uuid();
      final project = Project(
        id: uuid.v4(),
        name: 'My Project',
        projectKey: 'MP',
        description: 'Default project for tasks',
        createdAt: DateTime.now(),
        color: '#4A90E2',
      );

      await _projectRepo.put(project);
      _selectedProjectId = project.id;
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to create default project',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _checkRitualResets() async {
    try {
      for (final ritual in _ritualRepo.all) {
        ritual.resetIfNeeded();
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to check ritual resets',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Project Selection ──

  void selectProject(String? projectId) {
    _selectedProjectId = projectId;
    notifyListeners();
  }

  // ── Project CRUD ──

  Future<Project?> addProject(
    String name,
    String key, {
    String? description,
    String color = '#4A90E2',
    String? iconName,
  }) async {
    try {
      const uuid = Uuid();
      final project = Project(
        id: uuid.v4(),
        name: name,
        projectKey: key.toUpperCase(),
        description: description,
        createdAt: DateTime.now(),
        color: color,
        iconName: iconName,
      );

      await _projectRepo.put(project);
      notifyListeners();
      return project;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to add project: $name',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> updateProject(Project project) async {
    try {
      project.modifiedAt = DateTime.now();
      await _projectRepo.put(project);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update project: ${project.id}',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      await _taskRepo.deleteWhere((t) => t.projectId == projectId);
      await _projectRepo.delete(projectId);

      if (_selectedProjectId == projectId) {
        final remaining = _projectRepo.all;
        _selectedProjectId = remaining.isNotEmpty ? remaining.first.id : null;
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete project: $projectId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> archiveProject(String projectId) async {
    try {
      final project = _projectRepo.get(projectId);
      if (project == null) return false;
      project.isArchived = true;
      await project.save();

      if (_selectedProjectId == projectId) {
        final active = _projectRepo.active;
        _selectedProjectId = active.isNotEmpty ? active.first.id : null;
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to archive project: $projectId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ── Project Sharing ──

  Future<bool> shareProject(String projectId, String userId) async {
    final project = _projectRepo.get(projectId);
    if (project == null) return false;
    if (project.sharedWith.contains(userId)) return true;
    project.sharedWith = [...project.sharedWith, userId];
    project.modifiedAt = DateTime.now();
    await _projectRepo.put(project);
    notifyListeners();
    return true;
  }

  Future<bool> unshareProject(String projectId, String userId) async {
    final project = _projectRepo.get(projectId);
    if (project == null) return false;
    project.sharedWith = project.sharedWith.where((id) => id != userId).toList();
    project.modifiedAt = DateTime.now();
    await _projectRepo.put(project);
    notifyListeners();
    return true;
  }

  List<String> getProjectSharedUsers(String projectId) {
    final project = _projectRepo.get(projectId);
    return project?.sharedWith ?? [];
  }

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
      final targetProjectId = projectId ?? _selectedProjectId;
      String? taskKey;

      if (targetProjectId != null) {
        final project = _projectRepo.get(targetProjectId);
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

      await _taskRepo.put(task);
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
      await _taskRepo.put(task);
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
      await _taskRepo.delete(taskId);
      _taskRepo.removeDependencyReferences(taskId);
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

  // ── Task Dependencies ──

  bool addTaskDependency(String taskId, String dependsOnTaskId) {
    try {
      final task = _taskRepo.get(taskId);
      if (task == null) return false;
      if (taskId == dependsOnTaskId) return false;
      if (task.dependsOn.contains(dependsOnTaskId)) return false;
      if (_wouldCreateCircularDependency(taskId, dependsOnTaskId)) return false;

      task.dependsOn = [...task.dependsOn, dependsOnTaskId];
      task.modifiedAt = DateTime.now();
      task.save();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool removeTaskDependency(String taskId, String dependsOnTaskId) {
    try {
      final task = _taskRepo.get(taskId);
      if (task == null) return false;
      task.dependsOn =
          task.dependsOn.where((id) => id != dependsOnTaskId).toList();
      task.modifiedAt = DateTime.now();
      task.save();
      notifyListeners();
      return true;
    } catch (e) {
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

      final task = _taskRepo.get(current);
      if (task != null) {
        toVisit.addAll(task.dependsOn);
      }
    }
    return false;
  }

  List<Task> getTaskDependencies(String taskId) {
    final task = _taskRepo.get(taskId);
    if (task == null) return [];
    return task.dependsOn
        .map((id) => _taskRepo.get(id))
        .whereType<Task>()
        .toList();
  }

  List<Task> getDependentTasks(String taskId) {
    return _taskRepo.where((t) => t.dependsOn.contains(taskId));
  }

  bool isTaskBlocked(Task task) {
    if (task.status == TaskStatus.done) return false;
    for (final depId in task.dependsOn) {
      final depTask = _taskRepo.get(depId);
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
      final task = _taskRepo.get(taskId);
      if (task == null) return false;
      task.projectId = newProjectId;

      if (newProjectId != null) {
        final project = _projectRepo.get(newProjectId);
        if (project != null) {
          task.taskKey = project.generateNextTaskKey();
          await project.save();
        } else {
          task.taskKey = null;
        }
      } else {
        task.taskKey = null;
      }

      await _taskRepo.put(task);
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
    final task = _taskRepo.get(taskId);
    if (task == null) return false;
    task.addSubtask(title);
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> toggleSubtask(String taskId, int index) async {
    final task = _taskRepo.get(taskId);
    if (task == null) return false;
    task.toggleSubtask(index);
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> removeSubtask(String taskId, int index) async {
    final task = _taskRepo.get(taskId);
    if (task == null) return false;
    task.removeSubtask(index);
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  // ── Time tracking ──

  Future<bool> logTime(String taskId, int minutes) async {
    final task = _taskRepo.get(taskId);
    if (task == null || minutes <= 0) return false;
    task.trackedMinutes += minutes;
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> setEstimate(String taskId, int? minutes) async {
    final task = _taskRepo.get(taskId);
    if (task == null) return false;
    task.estimatedMinutes = minutes;
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  // ── Attachments ──

  Future<bool> addAttachment(String taskId, String filePath) async {
    final task = _taskRepo.get(taskId);
    if (task == null) return false;
    task.attachments = [...task.attachments, filePath];
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  Future<bool> removeAttachment(String taskId, int index) async {
    final task = _taskRepo.get(taskId);
    if (task == null || index < 0 || index >= task.attachments.length) {
      return false;
    }
    task.attachments = List.of(task.attachments)..removeAt(index);
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  // ── Recurrence ──

  Future<bool> setRecurrence(String taskId, String? recurrence) async {
    final task = _taskRepo.get(taskId);
    if (task == null) return false;
    if (recurrence != null &&
        !['daily', 'weekly', 'monthly'].contains(recurrence)) {
      return false;
    }
    task.recurrence = recurrence;
    task.modifiedAt = DateTime.now();
    await _taskRepo.put(task);
    notifyListeners();
    return true;
  }

  /// Check recurring tasks and create new instances if the completed one is due.
  Future<void> processRecurringTasks() async {
    final now = DateTime.now();
    final recurringDone = _taskRepo.all
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
            nextDue = DateTime(
              task.dueDate!.year,
              task.dueDate!.month + 1,
              task.dueDate!.day,
            );
        }
      }

      // Only create next occurrence if it's due
      if (nextDue != null && !nextDue.isAfter(now.add(const Duration(days: 1)))) {
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
          final project = _projectRepo.get(task.projectId!);
          if (project != null) {
            newTask.taskKey = project.generateNextTaskKey();
            await project.save();
          }
        }

        await _taskRepo.put(newTask);

        // Clear recurrence from the completed task so it doesn't trigger again
        task.recurrence = null;
        await _taskRepo.put(task);
      }
    }
    notifyListeners();
  }

  // ── Ritual CRUD ──

  Future<Ritual?> addRitual(String title, {String? description}) async {
    try {
      const uuid = Uuid();
      final ritual = Ritual(
        id: uuid.v4(),
        title: title,
        description: description,
        createdAt: DateTime.now(),
      );

      await _ritualRepo.put(ritual);
      notifyListeners();
      return ritual;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to add ritual: $title',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> updateRitual(Ritual ritual) async {
    try {
      await ritual.save();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update ritual: ${ritual.id}',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> toggleRitualCompletion(String ritualId) async {
    try {
      final ritual = _ritualRepo.get(ritualId);
      if (ritual == null) return false;
      if (!ritual.isCompleted) {
        ritual.markCompleted();
      } else {
        ritual.isCompleted = false;
        await ritual.save();
      }
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to toggle ritual completion: $ritualId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteRitual(String ritualId) async {
    try {
      await _ritualRepo.delete(ritualId);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete ritual: $ritualId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ── Task Queries ──

  List<Task> getTasksForProject(String? projectId) {
    return _taskRepo.getByProject(projectId);
  }

  List<Task> getTasksForSelectedProject() {
    return getTasksForProject(_selectedProjectId);
  }

  List<Task> getTasksForColumn(String columnId, {String? projectId}) {
    final project = projectId != null
        ? _projectRepo.get(projectId)
        : selectedProject;
    if (project == null) return [];

    final column = project.columns.firstWhere(
      (c) => c.id == columnId,
      orElse: () => project.columns.first,
    );

    return _taskRepo.getByProject(projectId ?? _selectedProjectId)
        .where((task) => task.status == column.status)
        .toList();
  }

  List<Task> _getTasksForColumnFiltered(String columnId, String projectId) {
    final filtered = getFilteredTasks(projectId);
    final columnStatus = getColumnStatus(columnId);
    return filtered.where((task) => task.status == columnStatus).toList();
  }

  TaskStatus getColumnStatus(String columnId) {
    for (final project in _projectRepo.all) {
      for (final column in project.columns) {
        if (column.id == columnId) {
          return column.status;
        }
      }
    }
    return TaskStatus.todo;
  }

  List<Task> getTasksForColumnPaginated(
    String columnId, {
    String? projectId,
    int page = 0,
    int pageSize = AppConstants.defaultPageSize,
  }) {
    final allTasks = hasActiveFilters && projectId != null
        ? _getTasksForColumnFiltered(columnId, projectId)
        : getTasksForColumn(columnId, projectId: projectId);
    final startIndex = page * pageSize;
    if (startIndex >= allTasks.length) return [];
    final endIndex = (startIndex + pageSize).clamp(0, allTasks.length);
    return allTasks.sublist(startIndex, endIndex);
  }

  int getTaskCountForColumn(String columnId, {String? projectId}) {
    if (hasActiveFilters && projectId != null) {
      return _getTasksForColumnFiltered(columnId, projectId).length;
    }
    return getTasksForColumn(columnId, projectId: projectId).length;
  }

  bool hasMoreTasksForColumn(
    String columnId, {
    String? projectId,
    int page = 0,
    int pageSize = AppConstants.defaultPageSize,
  }) {
    final totalTasks = getTaskCountForColumn(columnId, projectId: projectId);
    final loadedCount = (page + 1) * pageSize;
    return loadedCount < totalTasks;
  }

  // ── Project Queries ──

  List<Project> get activeProjects => _projectRepo.active;
  List<Project> get archivedProjects => _projectRepo.archived;

  // ── Column Management ──

  Future<bool> addColumn(String projectId, BoardColumn column) async {
    try {
      final project = _projectRepo.get(projectId);
      if (project == null) return false;

      final updatedColumns = List<BoardColumn>.from(project.columns)
        ..add(column.copyWith(order: project.columns.length));

      final updated = project.copyWith(columns: updatedColumns);
      await _projectRepo.put(updated);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to add column', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> updateColumn(String projectId, BoardColumn column) async {
    try {
      final project = _projectRepo.get(projectId);
      if (project == null) return false;

      final updatedColumns = project.columns.map((c) {
        return c.id == column.id ? column : c;
      }).toList();

      final updated = project.copyWith(columns: updatedColumns);
      await _projectRepo.put(updated);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to update column', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> deleteColumn(String projectId, String columnId) async {
    try {
      final project = _projectRepo.get(projectId);
      if (project == null) return false;

      final updatedColumns =
          project.columns.where((c) => c.id != columnId).toList();
      for (var i = 0; i < updatedColumns.length; i++) {
        updatedColumns[i] = updatedColumns[i].copyWith(order: i);
      }

      final updated = project.copyWith(columns: updatedColumns);
      await _projectRepo.put(updated);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to delete column', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> reorderColumns(String projectId, List<String> columnIds) async {
    try {
      final project = _projectRepo.get(projectId);
      if (project == null) return false;

      final columnMap = {for (var c in project.columns) c.id: c};
      final updatedColumns = <BoardColumn>[];
      for (var i = 0; i < columnIds.length; i++) {
        final column = columnMap[columnIds[i]];
        if (column != null) {
          updatedColumns.add(column.copyWith(order: i));
        }
      }

      final updated = project.copyWith(columns: updatedColumns);
      await _projectRepo.put(updated);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to reorder columns', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // ── Filtering & Sorting ──

  String _searchQuery = '';
  TaskStatus? _filterStatus;
  TaskPriority? _filterPriority;
  Set<String> _filterTags = {};
  DateTime? _filterDueBefore;
  DateTime? _filterDueAfter;
  TaskSortBy _sortBy = TaskSortBy.createdAt;
  bool _sortAscending = false;

  String get searchQuery => _searchQuery;
  TaskStatus? get filterStatus => _filterStatus;
  TaskPriority? get filterPriority => _filterPriority;
  Set<String> get filterTags => Set.unmodifiable(_filterTags);
  DateTime? get filterDueBefore => _filterDueBefore;
  DateTime? get filterDueAfter => _filterDueAfter;
  TaskSortBy get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _filterStatus != null ||
      _filterPriority != null ||
      _filterTags.isNotEmpty ||
      _filterDueBefore != null ||
      _filterDueAfter != null;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  void setFilterStatus(TaskStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setFilterPriority(TaskPriority? priority) {
    _filterPriority = priority;
    notifyListeners();
  }

  void toggleFilterTag(String tag) {
    if (_filterTags.contains(tag)) {
      _filterTags.remove(tag);
    } else {
      _filterTags.add(tag);
    }
    notifyListeners();
  }

  void clearFilterTags() {
    _filterTags.clear();
    notifyListeners();
  }

  void setFilterDueBefore(DateTime? date) {
    _filterDueBefore = date;
    notifyListeners();
  }

  void setFilterDueAfter(DateTime? date) {
    _filterDueAfter = date;
    notifyListeners();
  }

  void setSortBy(TaskSortBy sortBy) {
    if (_sortBy == sortBy) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      _sortAscending = false;
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterStatus = null;
    _filterPriority = null;
    _filterTags = {};
    _filterDueBefore = null;
    _filterDueAfter = null;
    notifyListeners();
  }

  List<Task> getFilteredTasks(String projectId) {
    var filtered = _taskRepo.getByProject(projectId);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(_searchQuery) ||
            (task.description?.toLowerCase().contains(_searchQuery) ?? false) ||
            (task.taskKey?.toLowerCase().contains(_searchQuery) ?? false) ||
            task.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    if (_filterStatus != null) {
      filtered = filtered.where((task) => task.status == _filterStatus).toList();
    }

    if (_filterPriority != null) {
      filtered = filtered.where((task) => task.priority == _filterPriority).toList();
    }

    if (_filterTags.isNotEmpty) {
      filtered = filtered
          .where((task) => _filterTags.every((tag) => task.tags.contains(tag)))
          .toList();
    }

    if (_filterDueBefore != null) {
      filtered = filtered
          .where((task) =>
              task.dueDate != null && task.dueDate!.isBefore(_filterDueBefore!))
          .toList();
    }

    if (_filterDueAfter != null) {
      filtered = filtered
          .where((task) =>
              task.dueDate != null && task.dueDate!.isAfter(_filterDueAfter!))
          .toList();
    }

    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case TaskSortBy.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
        case TaskSortBy.dueDate:
          if (a.dueDate == null && b.dueDate == null) {
            comparison = 0;
          } else if (a.dueDate == null) {
            comparison = 1;
          } else if (b.dueDate == null) {
            comparison = -1;
          } else {
            comparison = a.dueDate!.compareTo(b.dueDate!);
          }
        case TaskSortBy.priority:
          comparison = a.priority.index.compareTo(b.priority.index);
        case TaskSortBy.title:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  List<String> getAllTagsForProject(String projectId) {
    final tags = <String>{};
    for (final task in _taskRepo.getByProject(projectId)) {
      tags.addAll(task.tags);
    }
    return tags.toList()..sort();
  }

  // ── Tag CRUD ──

  List<Tag> getTagsForProject(String projectId) {
    return _tagRepo.getByProject(projectId);
  }

  Tag? getTagByName(String name, String projectId) {
    return _tagRepo.getByName(name, projectId);
  }

  Future<Tag?> addTag(String name, String color, String projectId) async {
    try {
      final existing = _tagRepo.getByName(name, projectId);
      if (existing != null) return null;

      const uuid = Uuid();
      final tag = Tag(
        id: uuid.v4(),
        name: name.trim(),
        color: color,
        projectId: projectId,
      );

      await _tagRepo.put(tag);
      notifyListeners();
      return tag;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to add tag: $name',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> updateTag(Tag tag) async {
    try {
      final existing = _tagRepo.get(tag.id);
      final oldName = existing?.name;

      await _tagRepo.put(tag);

      if (oldName != null && oldName != tag.name) {
        for (final task in _taskRepo.getByProject(tag.projectId)) {
          if (task.tags.contains(oldName)) {
            task.tags = task.tags.map((t) => t == oldName ? tag.name : t).toList();
            await _taskRepo.put(task);
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update tag: ${tag.id}',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteTag(String tagId) async {
    try {
      final tag = _tagRepo.get(tagId);
      if (tag == null) return false;

      for (final task in _taskRepo.getByProject(tag.projectId)) {
        if (task.tags.contains(tag.name)) {
          task.tags = task.tags.where((t) => t != tag.name).toList();
          await _taskRepo.put(task);
        }
      }

      _filterTags.remove(tag.name);
      await _tagRepo.delete(tagId);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete tag: $tagId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

enum TaskSortBy {
  createdAt,
  dueDate,
  priority,
  title,
}
