import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/project.dart';
import '../../repositories/project_repository.dart';
import '../../repositories/task_repository.dart';

mixin ProjectMixin on ChangeNotifier {
  ProjectRepository get projectRepo;
  TaskRepository get taskRepo;

  String? _selectedProjectId;

  String? get selectedProjectId => _selectedProjectId;

  Project? get selectedProject {
    if (_selectedProjectId == null) return null;
    return projectRepo.get(_selectedProjectId!);
  }

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

      await projectRepo.put(project);
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
      await projectRepo.put(project);
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
      await taskRepo.deleteWhere((t) => t.projectId == projectId);
      await projectRepo.delete(projectId);

      if (_selectedProjectId == projectId) {
        final remaining = projectRepo.all;
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
      final project = projectRepo.get(projectId);
      if (project == null) return false;
      project.isArchived = true;
      await project.save();

      if (_selectedProjectId == projectId) {
        final active = projectRepo.active;
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
    final project = projectRepo.get(projectId);
    if (project == null) return false;
    if (project.sharedWith.contains(userId)) return true;
    project.sharedWith = [...project.sharedWith, userId];
    project.modifiedAt = DateTime.now();
    await projectRepo.put(project);
    notifyListeners();
    return true;
  }

  Future<bool> unshareProject(String projectId, String userId) async {
    final project = projectRepo.get(projectId);
    if (project == null) return false;
    project.sharedWith = project.sharedWith.where((id) => id != userId).toList();
    project.modifiedAt = DateTime.now();
    await projectRepo.put(project);
    notifyListeners();
    return true;
  }

  List<String> getProjectSharedUsers(String projectId) {
    final project = projectRepo.get(projectId);
    return project?.sharedWith ?? [];
  }

  // ── Project Queries ──

  List<Project> get activeProjects => projectRepo.active;
  List<Project> get archivedProjects => projectRepo.archived;
}
