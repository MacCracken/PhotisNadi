import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';

/// Manages tasks, rituals, and projects with local storage using Hive.
class TaskService extends ChangeNotifier {
  late final Box<Task> _taskBox;
  late final Box<Ritual> _ritualBox;
  late final Box<Project> _projectBox;
  
  List<Task> _tasks = [];
  List<Ritual> _rituals = [];
  List<Project> _projects = [];
  
  String? _selectedProjectId;

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Ritual> get rituals => List.unmodifiable(_rituals);
  List<Project> get projects => List.unmodifiable(_projects);
  
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
    try {
      _taskBox = await Hive.openBox<Task>('tasks');
      _ritualBox = await Hive.openBox<Ritual>('rituals');
      _projectBox = await Hive.openBox<Project>('projects');

      _loadData();
      
      // Initialize default project if none exists
      if (_projects.isEmpty) {
        await _createDefaultProject();
      }
      
      // Select first project by default
      if (_selectedProjectId == null && _projects.isNotEmpty) {
        _selectedProjectId = _projects.first.id;
      }
      
      // Check for ritual resets
      await _checkRitualResets();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize task service',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void _loadData() {
    try {
      _tasks = _taskBox.values.toList();
      _rituals = _ritualBox.values.toList();
      _projects = _projectBox.values.toList();
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
      notifyListeners();
    }
  }

  Future<void> _createDefaultProject() async {
    try {
      const uuid = Uuid();
      
      final project = Project(
        id: uuid.v4(),
        name: 'My Project',
        key: 'MP',
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
        key: key.toUpperCase(),
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
      final projectTasks = _tasks.where((t) => t.projectId == projectId).toList();
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
        _selectedProjectId = activeProjects.isNotEmpty 
            ? activeProjects.first.id 
            : null;
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
          taskKey = project.nextTaskKey;
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
  
  Future<bool> moveTaskToProject(String taskId, String? newProjectId) async {
    try {
      final task = _tasks.firstWhere((t) => t.id == taskId);
      task.projectId = newProjectId;
      
      // Generate new task key for new project
      if (newProjectId != null) {
        try {
          final project = _projects.firstWhere((p) => p.id == newProjectId);
          task.taskKey = project.nextTaskKey;
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
    final projectTasks = projectId != null 
        ? getTasksForProject(projectId)
        : getTasksForSelectedProject();
    
    return projectTasks.where((task) {
      switch (columnId) {
        case 'todo':
          return task.status == TaskStatus.todo;
        case 'in_progress':
          return task.status == TaskStatus.inProgress;
        case 'done':
          return task.status == TaskStatus.done;
        default:
          return false;
      }
    }).toList();
  }
  
  // Get active (non-archived) projects
  List<Project> get activeProjects {
    return _projects.where((p) => !p.isArchived).toList();
  }
  
  // Get archived projects
  List<Project> get archivedProjects {
    return _projects.where((p) => p.isArchived).toList();
  }
}
