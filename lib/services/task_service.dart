import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';
import '../models/board.dart';
import '../models/tag.dart';
import '../common/constants.dart';
import '../common/performance_monitor.dart';
import '../repositories/task_repository.dart';
import '../repositories/project_repository.dart';
import '../repositories/ritual_repository.dart';
import '../repositories/tag_repository.dart';
import 'mixins/project_mixin.dart';
import 'mixins/task_crud_mixin.dart';
import 'mixins/filter_sort_mixin.dart';
import 'mixins/column_mixin.dart';
import 'mixins/ritual_mixin.dart';
import 'mixins/tag_mixin.dart';

// Re-export for consumers that import TaskSortBy from task_service.dart
export 'mixins/filter_sort_mixin.dart' show TaskSortBy;

/// Manages tasks, rituals, and projects with local storage using Hive.
class TaskService extends ChangeNotifier
    with
        ProjectMixin,
        TaskCrudMixin,
        FilterSortMixin,
        ColumnMixin,
        RitualMixin,
        TagMixin {
  final TaskRepository _taskRepo;
  final ProjectRepository _projectRepo;
  final RitualRepository _ritualRepo;
  final TagRepository _tagRepo;

  bool _isLoading = true;
  String? _error;
  Timer? _notifyTimer;

  /// Debounced notifyListeners — coalesces multiple calls within the same
  /// microtask frame into a single notification.
  @override
  void notifyListeners() {
    _notifyTimer ??= Timer(Duration.zero, () {
      _notifyTimer = null;
      super.notifyListeners();
    });
  }

  /// Immediate notification for init/loading state transitions where the UI
  /// must update synchronously.
  void notifyListenersImmediate() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    super.notifyListeners();
  }

  TaskService({
    TaskRepository? taskRepo,
    ProjectRepository? projectRepo,
    RitualRepository? ritualRepo,
    TagRepository? tagRepo,
  })  : _taskRepo = taskRepo ?? TaskRepository(),
        _projectRepo = projectRepo ?? ProjectRepository(),
        _ritualRepo = ritualRepo ?? RitualRepository(),
        _tagRepo = tagRepo ?? TagRepository();

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    super.dispose();
  }

  // Expose repositories to mixins
  @override
  TaskRepository get taskRepo => _taskRepo;
  @override
  ProjectRepository get projectRepo => _projectRepo;
  @override
  RitualRepository get ritualRepo => _ritualRepo;
  @override
  TagRepository get tagRepo => _tagRepo;

  // Getters that delegate to repositories
  List<Task> get tasks => _taskRepo.all;
  List<Ritual> get rituals => _ritualRepo.all;
  List<Project> get projects => _projectRepo.all;
  List<Tag> get tags => _tagRepo.all;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListenersImmediate();

    try {
      await PerformanceMonitor.measureAsync('TaskService.init', () async {
        await _taskRepo.init();
        await _ritualRepo.init();
        await _projectRepo.init();
        await _tagRepo.init();

        if (_projectRepo.count == 0) {
          await _createDefaultProject();
        }

        if (selectedProjectId == null && _projectRepo.count > 0) {
          selectProject(_projectRepo.all.first.id);
        }

        await checkRitualResets();
        await processRecurringTasks();
      });
      _isLoading = false;
      PerformanceMonitor.report();
      notifyListenersImmediate();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize task service',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      _error = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListenersImmediate();
      rethrow;
    }
  }

  Future<void> _createDefaultProject() async {
    try {
      await addProject('My Project', 'MP',
          description: 'Default project for tasks');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to create default project',
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

  /// Hook for TagMixin to remove from filter tags on tag deletion.
  @override
  void removeFilterTagOnDelete(String tagName) {
    if (filterTags.contains(tagName)) {
      toggleFilterTag(tagName);
    }
  }

  // ── Board Management ──

  void selectBoard(String boardId) {
    final project = selectedProject;
    if (project == null) return;
    if (!project.boards.any((b) => b.id == boardId)) return;
    project.activeBoardId = boardId;
    project.modifiedAt = DateTime.now();
    projectRepo.put(project);
    notifyListeners();
  }

  Future<bool> addBoard(String projectId, Board board) async {
    try {
      final project = projectRepo.get(projectId);
      if (project == null) return false;
      project.boards = [...project.boards, board];
      project.activeBoardId = board.id;
      project.modifiedAt = DateTime.now();
      await projectRepo.put(project);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to add board',
          name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> updateBoard(String projectId, Board board) async {
    try {
      final project = projectRepo.get(projectId);
      if (project == null) return false;
      project.boards =
          project.boards.map((b) => b.id == board.id ? board : b).toList();
      project.modifiedAt = DateTime.now();
      await projectRepo.put(project);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to update board',
          name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> deleteBoard(String projectId, String boardId) async {
    try {
      final project = projectRepo.get(projectId);
      if (project == null) return false;
      if (project.boards.length <= 1) return false; // Must keep at least one

      project.boards = project.boards.where((b) => b.id != boardId).toList();
      if (project.activeBoardId == boardId) {
        project.activeBoardId = project.boards.first.id;
      }
      project.modifiedAt = DateTime.now();
      await projectRepo.put(project);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to delete board',
          name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // ── Task Queries ──

  List<Task> getTasksForProject(String? projectId) {
    return _taskRepo.getByProject(projectId);
  }

  List<Task> getTasksForSelectedProject() {
    return getTasksForProject(selectedProjectId);
  }

  List<Task> getTasksForColumn(String columnId, {String? projectId}) {
    final project =
        projectId != null ? _projectRepo.get(projectId) : selectedProject;
    if (project == null) return [];

    final column = project.activeColumns.firstWhere(
      (c) => c.id == columnId,
      orElse: () => project.activeColumns.first,
    );

    return _taskRepo
        .getByProject(projectId ?? selectedProjectId)
        .where((task) => task.status == column.status)
        .toList();
  }

  List<Task> _getTasksForColumnFiltered(String columnId, String projectId) {
    final filtered = getFilteredTasks(projectId);
    final columnStatus = getColumnStatus(columnId);
    return filtered.where((task) => task.status == columnStatus).toList();
  }

  List<Task> getTasksForColumnPaginated(
    String columnId, {
    String? projectId,
    int page = 0,
    int pageSize = AppConstants.defaultPageSize,
  }) {
    return PerformanceMonitor.measure('TaskService.getTasksForColumnPaginated',
        () {
      final allTasks = hasActiveFilters && projectId != null
          ? _getTasksForColumnFiltered(columnId, projectId)
          : getTasksForColumn(columnId, projectId: projectId);
      final startIndex = page * pageSize;
      if (startIndex >= allTasks.length) return <Task>[];
      final endIndex = (startIndex + pageSize).clamp(0, allTasks.length);
      return allTasks.sublist(startIndex, endIndex);
    });
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
}
