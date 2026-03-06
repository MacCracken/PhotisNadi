import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';
import '../models/board.dart';
import '../models/tag.dart';
import '../common/constants.dart';

/// Manages tasks, rituals, and projects with local storage using Hive.
class TaskService extends ChangeNotifier {
  late final Box<Task> _taskBox;
  late final Box<Ritual> _ritualBox;
  late final Box<Project> _projectBox;
  late final Box<Tag> _tagBox;

  List<Task> _tasks = [];
  List<Ritual> _rituals = [];
  List<Project> _projects = [];
  List<Tag> _tags = [];

  String? _selectedProjectId;

  bool _isLoading = true;
  String? _error;

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Ritual> get rituals => List.unmodifiable(_rituals);
  List<Project> get projects => List.unmodifiable(_projects);
  List<Tag> get tags => List.unmodifiable(_tags);

  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get selectedProjectId => _selectedProjectId;

  Project? get selectedProject {
    if (_selectedProjectId == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == _selectedProjectId);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _taskBox = await Hive.openBox<Task>('tasks');
      _ritualBox = await Hive.openBox<Ritual>('rituals');
      _projectBox = await Hive.openBox<Project>('projects');
      _tagBox = await Hive.openBox<Tag>('tags');

      _loadData();

      if (_projects.isEmpty) {
        await _createDefaultProject();
      }

      if (_selectedProjectId == null && _projects.isNotEmpty) {
        _selectedProjectId = _projects.first.id;
      }

      await _checkRitualResets();
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

  void _loadData() {
    try {
      _tasks = _taskBox.values.toList();
      _rituals = _ritualBox.values.toList();
      _projects = _projectBox.values.toList();
      _tags = _tagBox.values.toList();
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load data from Hive',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      _tasks = [];
      _rituals = [];
      _projects = [];
      _tags = [];
      notifyListeners();
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

      await _projectBox.put(project.id, project);
      _projects.add(project);
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
      for (final ritual in _rituals) {
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

  // Project selection
  void selectProject(String? projectId) {
    _selectedProjectId = projectId;
    notifyListeners();
  }

  // Project CRUD operations
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

      await _projectBox.put(project.id, project);
      _projects.add(project);
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
      await _projectBox.put(project.id, project);
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = project;
      }
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
      // Delete all tasks in this project
      final projectTasks =
          _tasks.where((t) => t.projectId == projectId).toList();
      for (final task in projectTasks) {
        await _taskBox.delete(task.id);
      }
      _tasks.removeWhere((t) => t.projectId == projectId);

      // Delete the project
      await _projectBox.delete(projectId);
      _projects.removeWhere((p) => p.id == projectId);

      // If deleted project was selected, select another
      if (_selectedProjectId == projectId) {
        _selectedProjectId = _projects.isNotEmpty ? _projects.first.id : null;
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
      final project = _projects.firstWhere((p) => p.id == projectId);
      project.isArchived = true;
      await project.save();

      // If archived project was selected, select another active one
      if (_selectedProjectId == projectId) {
        final activeProjects = _projects.where((p) => !p.isArchived).toList();
        _selectedProjectId =
            activeProjects.isNotEmpty ? activeProjects.first.id : null;
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

  // Task operations
  Future<Task?> addTask(
    String title, {
    String? description,
    TaskPriority? priority,
    String? projectId,
    List<String>? tags,
  }) async {
    try {
      const uuid = Uuid();

      // Use selected project if no projectId provided
      final targetProjectId = projectId ?? _selectedProjectId;
      String? taskKey;

      // Generate task key if project exists
      if (targetProjectId != null) {
        try {
          final project = _projects.firstWhere((p) => p.id == targetProjectId);
          taskKey = project.generateNextTaskKey();
          await project.save();
        } catch (_) {
          // Project not found, proceed without key
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
      );

      await _taskBox.put(task.id, task);
      _tasks.add(task);
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
      await _taskBox.put(task.id, task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
      }
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
      await _taskBox.delete(taskId);
      _tasks.removeWhere((task) => task.id == taskId);
      _removeDependencyReferences(taskId);
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

  void _removeDependencyReferences(String taskId) {
    for (final task in _tasks) {
      if (task.dependsOn.contains(taskId)) {
        task.dependsOn = task.dependsOn.where((id) => id != taskId).toList();
      }
    }
  }

  bool addTaskDependency(String taskId, String dependsOnTaskId) {
    try {
      final task = _tasks.firstWhere((t) => t.id == taskId);
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
      final task = _tasks.firstWhere((t) => t.id == taskId);
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

      try {
        final task = _tasks.firstWhere((t) => t.id == current);
        toVisit.addAll(task.dependsOn);
      } catch (_) {}
    }
    return false;
  }

  List<Task> getTaskDependencies(String taskId) {
    try {
      final task = _tasks.firstWhere((t) => t.id == taskId);
      return _tasks.where((t) => task.dependsOn.contains(t.id)).toList();
    } catch (_) {
      return [];
    }
  }

  List<Task> getDependentTasks(String taskId) {
    return _tasks.where((t) => t.dependsOn.contains(taskId)).toList();
  }

  bool isTaskBlocked(Task task) {
    if (task.status == TaskStatus.done) return false;
    for (final depId in task.dependsOn) {
      try {
        final depTask = _tasks.firstWhere((t) => t.id == depId);
        if (depTask.status != TaskStatus.done) return true;
      } catch (_) {}
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
      final task = _tasks.firstWhere((t) => t.id == taskId);
      task.projectId = newProjectId;

      // Generate new task key for new project
      if (newProjectId != null) {
        try {
          final project = _projects.firstWhere((p) => p.id == newProjectId);
          task.taskKey = project.generateNextTaskKey();
          await project.save();
        } catch (_) {
          task.taskKey = null;
        }
      } else {
        task.taskKey = null;
      }

      await task.save();
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

  // Ritual operations
  Future<Ritual?> addRitual(String title, {String? description}) async {
    try {
      const uuid = Uuid();
      final ritual = Ritual(
        id: uuid.v4(),
        title: title,
        description: description,
        createdAt: DateTime.now(),
      );

      await _ritualBox.put(ritual.id, ritual);
      _rituals.add(ritual);
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
      final ritual = _rituals.firstWhere((r) => r.id == ritualId);
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
      await _ritualBox.delete(ritualId);
      _rituals.removeWhere((ritual) => ritual.id == ritualId);
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

  // Task filtering methods
  List<Task> getTasksForProject(String? projectId) {
    if (projectId == null) {
      return _tasks.where((task) => task.projectId == null).toList();
    }
    return _tasks.where((task) => task.projectId == projectId).toList();
  }

  List<Task> getTasksForSelectedProject() {
    return getTasksForProject(_selectedProjectId);
  }

  List<Task> getTasksForColumn(String columnId, {String? projectId}) {
    final project = projectId != null
        ? _projects.firstWhere((p) => p.id == projectId,
            orElse: () => _projects.first)
        : selectedProject;

    if (project == null) return [];

    final column = project.columns.firstWhere(
      (c) => c.id == columnId,
      orElse: () => project.columns.first,
    );

    final projectTasks = projectId != null
        ? getTasksForProject(projectId)
        : getTasksForSelectedProject();

    return projectTasks.where((task) => task.status == column.status).toList();
  }

  List<Task> _getTasksForColumnFiltered(String columnId, String projectId) {
    final filtered = getFilteredTasks(projectId);
    final columnStatus = getColumnStatus(columnId);
    return filtered.where((task) => task.status == columnStatus).toList();
  }

  TaskStatus getColumnStatus(String columnId) {
    for (final project in _projects) {
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

  // Get active (non-archived) projects
  List<Project> get activeProjects {
    return _projects.where((p) => !p.isArchived).toList();
  }

  // Get archived projects
  List<Project> get archivedProjects {
    return _projects.where((p) => p.isArchived).toList();
  }

  // Column management
  Future<bool> addColumn(String projectId, BoardColumn column) async {
    try {
      final projectIndex = _projects.indexWhere((p) => p.id == projectId);
      if (projectIndex == -1) return false;

      final project = _projects[projectIndex];
      final updatedColumns = List<BoardColumn>.from(project.columns)
        ..add(column.copyWith(order: project.columns.length));

      _projects[projectIndex] = project.copyWith(columns: updatedColumns);
      await _projectBox.put(project.id, _projects[projectIndex]);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to add column',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> updateColumn(String projectId, BoardColumn column) async {
    try {
      final projectIndex = _projects.indexWhere((p) => p.id == projectId);
      if (projectIndex == -1) return false;

      final project = _projects[projectIndex];
      final updatedColumns = project.columns.map((c) {
        return c.id == column.id ? column : c;
      }).toList();

      _projects[projectIndex] = project.copyWith(columns: updatedColumns);
      await _projectBox.put(project.id, _projects[projectIndex]);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update column',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteColumn(String projectId, String columnId) async {
    try {
      final projectIndex = _projects.indexWhere((p) => p.id == projectId);
      if (projectIndex == -1) return false;

      final project = _projects[projectIndex];
      final updatedColumns =
          project.columns.where((c) => c.id != columnId).toList();

      for (var i = 0; i < updatedColumns.length; i++) {
        updatedColumns[i] = updatedColumns[i].copyWith(order: i);
      }

      _projects[projectIndex] = project.copyWith(columns: updatedColumns);
      await _projectBox.put(project.id, _projects[projectIndex]);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete column',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> reorderColumns(String projectId, List<String> columnIds) async {
    try {
      final projectIndex = _projects.indexWhere((p) => p.id == projectId);
      if (projectIndex == -1) return false;

      final project = _projects[projectIndex];
      final columnMap = {for (var c in project.columns) c.id: c};

      final updatedColumns = <BoardColumn>[];
      for (var i = 0; i < columnIds.length; i++) {
        final column = columnMap[columnIds[i]];
        if (column != null) {
          updatedColumns.add(column.copyWith(order: i));
        }
      }

      _projects[projectIndex] = project.copyWith(columns: updatedColumns);
      await _projectBox.put(project.id, _projects[projectIndex]);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to reorder columns',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

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
    var filtered = _tasks.where((task) => task.projectId == projectId).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(_searchQuery) ||
            (task.description?.toLowerCase().contains(_searchQuery) ?? false) ||
            (task.taskKey?.toLowerCase().contains(_searchQuery) ?? false) ||
            task.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    if (_filterStatus != null) {
      filtered =
          filtered.where((task) => task.status == _filterStatus).toList();
    }

    if (_filterPriority != null) {
      filtered =
          filtered.where((task) => task.priority == _filterPriority).toList();
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
          break;
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
          break;
        case TaskSortBy.priority:
          comparison = a.priority.index.compareTo(b.priority.index);
          break;
        case TaskSortBy.title:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  List<String> getAllTagsForProject(String projectId) {
    final tags = <String>{};
    for (final task in _tasks.where((t) => t.projectId == projectId)) {
      tags.addAll(task.tags);
    }
    return tags.toList()..sort();
  }

  // Tag operations
  List<Tag> getTagsForProject(String projectId) {
    return _tags.where((t) => t.projectId == projectId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Tag? getTagByName(String name, String projectId) {
    try {
      return _tags.firstWhere(
        (t) => t.name == name && t.projectId == projectId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Tag?> addTag(
    String name,
    String color,
    String projectId,
  ) async {
    try {
      final existing = getTagByName(name, projectId);
      if (existing != null) return null;

      const uuid = Uuid();
      final tag = Tag(
        id: uuid.v4(),
        name: name.trim(),
        color: color,
        projectId: projectId,
      );

      await _tagBox.put(tag.id, tag);
      _tags.add(tag);
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
      await _tagBox.put(tag.id, tag);
      final index = _tags.indexWhere((t) => t.id == tag.id);
      if (index != -1) {
        final oldName = _tags[index].name;
        _tags[index] = tag;

        // Rename tag in all tasks if name changed
        if (oldName != tag.name) {
          for (final task in _tasks.where(
            (t) => t.projectId == tag.projectId && t.tags.contains(oldName),
          )) {
            task.tags = task.tags
                .map((t) => t == oldName ? tag.name : t)
                .toList();
            await _taskBox.put(task.id, task);
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
      final tag = _tags.firstWhere((t) => t.id == tagId);
      final tagName = tag.name;
      final projectId = tag.projectId;

      // Remove tag from all tasks
      for (final task in _tasks.where(
        (t) => t.projectId == projectId && t.tags.contains(tagName),
      )) {
        task.tags = task.tags.where((t) => t != tagName).toList();
        await _taskBox.put(task.id, task);
      }

      await _tagBox.delete(tagId);
      _tags.removeWhere((t) => t.id == tagId);
      _filterTags.remove(tagName);
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
