import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';

/// Manages tasks, rituals, and projects with local storage using Hive.
class TaskService extends ChangeNotifier {
  late Box<Task> _taskBox;
  late Box<Ritual> _ritualBox;
  late Box<Project> _projectBox;
  
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
  }

  void _loadData() {
    _tasks = _taskBox.values.toList();
    _rituals = _ritualBox.values.toList();
    _projects = _projectBox.values.toList();
    notifyListeners();
  }

  Future<void> _createDefaultProject() async {
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
  }

  Future<void> _checkRitualResets() async {
    for (final ritual in _rituals) {
      ritual.resetIfNeeded();
    }
  }
  
  // Project selection
  void selectProject(String? projectId) {
    _selectedProjectId = projectId;
    notifyListeners();
  }
  
  // Project CRUD operations
  Future<Project> addProject(
    String name,
    String key, {
    String? description,
    String color = '#4A90E2',
    String? iconName,
  }) async {
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
  }
  
  Future<void> updateProject(Project project) async {
    project.modifiedAt = DateTime.now();
    await _projectBox.put(project.id, project);
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
    }
    notifyListeners();
  }
  
  Future<void> deleteProject(String projectId) async {
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
  }
  
  Future<void> archiveProject(String projectId) async {
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
  }

  // Task operations
  Future<void> addTask(
    String title, {
    String? description,
    TaskPriority? priority,
    String? projectId,
  }) async {
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
  }

  Future<void> updateTask(Task task) async {
    task.modifiedAt = DateTime.now();
    await _taskBox.put(task.id, task);
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    await _taskBox.delete(taskId);
    _tasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }
  
  Future<void> moveTaskToProject(String taskId, String? newProjectId) async {
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
  }

  // Ritual operations (unchanged - rituals are independent)
  Future<void> addRitual(String title, {String? description}) async {
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
  }

  Future<void> updateRitual(Ritual ritual) async {
    await ritual.save();
    notifyListeners();
  }

  Future<void> toggleRitualCompletion(String ritualId) async {
    final ritual = _rituals.firstWhere((r) => r.id == ritualId);
    if (!ritual.isCompleted) {
      ritual.markCompleted();
    } else {
      ritual.isCompleted = false;
      await ritual.save();
    }
    notifyListeners();
  }

  Future<void> deleteRitual(String ritualId) async {
    await _ritualBox.delete(ritualId);
    _rituals.removeWhere((ritual) => ritual.id == ritualId);
    notifyListeners();
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
