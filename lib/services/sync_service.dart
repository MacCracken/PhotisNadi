import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';

// Extension methods for model parsing
extension TaskParsing on Task {
  static Task fromMap(Map<String, dynamic> data) {
    return Task(
      id: data['id'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      status: TaskStatus.values.firstWhere(
        (e) => e.toString() == 'TaskStatus.${data['status']}',
        orElse: () => TaskStatus.todo,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString() == 'TaskPriority.${data['priority']}',
        orElse: () => TaskPriority.medium,
      ),
      createdAt: DateTime.parse(data['created_at'] as String),
      dueDate: data['due_date'] != null
          ? DateTime.parse(data['due_date'] as String)
          : null,
      projectId: data['project_id'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      taskKey: data['task_key'] as String?,
      modifiedAt: data['modified_at'] != null
          ? DateTime.parse(data['modified_at'] as String)
          : DateTime.parse(data['created_at'] as String),
    );
  }

  Map<String, dynamic> toSyncMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'project_id': projectId,
      'tags': tags,
      'task_key': taskKey,
      'modified_at': modifiedAt.toIso8601String(),
    };
  }
}

extension ProjectParsing on Project {
  static Project fromMap(Map<String, dynamic> data) {
    return Project(
      id: data['id'] as String,
      name: data['name'] as String,
      key: data['key'] as String,
      description: data['description'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      color: data['color'] ?? '#4A90E2',
      iconName: data['icon_name'] as String?,
      taskCounter: data['task_counter'] ?? 0,
      isArchived: data['is_archived'] ?? false,
      modifiedAt: data['modified_at'] != null
          ? DateTime.parse(data['modified_at'] as String)
          : DateTime.parse(data['created_at'] as String),
    );
  }

  Map<String, dynamic> toSyncMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'key': key,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'color': color,
      'icon_name': iconName,
      'task_counter': taskCounter,
      'is_archived': isArchived,
      'modified_at': modifiedAt.toIso8601String(),
    };
  }
}

extension RitualParsing on Ritual {
  static Ritual fromMap(Map<String, dynamic> data) {
    return Ritual(
      id: data['id'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      isCompleted: data['is_completed'] as bool,
      createdAt: DateTime.parse(data['created_at'] as String),
      lastCompleted: data['last_completed'] != null
          ? DateTime.parse(data['last_completed'] as String)
          : null,
      resetTime: data['reset_time'] != null
          ? DateTime.parse(data['reset_time'] as String)
          : null,
      streakCount: data['streak_count'] as int,
      frequency: RitualFrequency.values.firstWhere(
        (e) => e.toString() == 'RitualFrequency.${data['frequency']}',
        orElse: () => RitualFrequency.daily,
      ),
    );
  }

  Map<String, dynamic> toSyncMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'last_completed': lastCompleted?.toIso8601String(),
      'reset_time': resetTime?.toIso8601String(),
      'streak_count': streakCount,
      'frequency': frequency.toString().split('.').last,
    };
  }
}

/// Configuration for retry logic
class RetryConfig {
  static const int maxRetries = 3;
  static const Duration initialDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(seconds: 10);
  static const double backoffMultiplier = 2.0;
}

/// Configuration for network operations
class NetworkConfig {
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);
}

/// Custom exception for sync operations
class SyncException implements Exception {
  final String message;
  final dynamic cause;

  SyncException(this.message, {this.cause});

  @override
  String toString() => 'SyncException: $message';
}

/// Handles synchronization with Supabase backend.
class SyncService extends ChangeNotifier {
  late final Box<Task> _taskBox;
  late final Box<Ritual> _ritualBox;
  late final Box<Project> _projectBox;
  late final SupabaseClient _supabase;
  bool _isInitialized = false;
  final List<RealtimeChannel> _channels = [];

  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    try {
      _supabase = Supabase.instance.client;
      _taskBox = await Hive.openBox<Task>('tasks');
      _ritualBox = await Hive.openBox<Ritual>('rituals');
      _projectBox = await Hive.openBox<Project>('projects');
      _isInitialized = true;
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize sync service',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Helper method to execute an operation with retry logic and timeout
  Future<T?> _executeWithRetry<T>({
    required Future<T> Function() operation,
    required String operationName,
    int maxRetries = RetryConfig.maxRetries,
    Duration timeout = NetworkConfig.requestTimeout,
  }) async {
    var attempt = 0;
    var delay = RetryConfig.initialDelay;

    while (attempt < maxRetries) {
      try {
        attempt++;
        developer.log(
          'Attempting $operationName (attempt $attempt/$maxRetries)',
          name: 'SyncService',
        );

        final result = await operation().timeout(timeout);
        return result;
      } on TimeoutException catch (e) {
        developer.log(
          '$operationName timed out on attempt $attempt',
          name: 'SyncService',
          error: e,
        );
        if (attempt >= maxRetries) {
          throw SyncException(
            'Operation timed out after $maxRetries attempts: $operationName',
            cause: e,
          );
        }
      } catch (e) {
        developer.log(
          '$operationName failed on attempt $attempt: $e',
          name: 'SyncService',
          error: e,
        );
        if (attempt >= maxRetries) {
          throw SyncException(
            'Operation failed after $maxRetries attempts: $operationName',
            cause: e,
          );
        }
      }

      // Exponential backoff with jitter
      await Future.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * RetryConfig.backoffMultiplier +
                (100 * attempt) // Add jitter
            )
            .clamp(0, RetryConfig.maxDelay.inMilliseconds)
            .toInt(),
      );
    }

    return null;
  }

  // Task synchronization
  Future<bool> syncTasks() async {
    if (!_isInitialized) return false;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        developer.log(
          'Cannot sync tasks: No authenticated user',
          name: 'SyncService',
        );
        return false;
      }

      final localTasks = _taskBox.values.toList();

      final remoteTasks = await _executeWithRetry<List<Task>>(
        operation: () async {
          final response =
              await _supabase.from('tasks').select().eq('user_id', userId);

          final tasks = <Task>[];
          for (final taskData in response) {
            try {
              tasks.add(TaskParsing.fromMap(taskData));
            } catch (e, stackTrace) {
              developer.log(
                'Failed to parse task from remote data',
                name: 'SyncService',
                error: e,
                stackTrace: stackTrace,
              );
            }
          }
          return tasks;
        },
        operationName: 'Fetch remote tasks',
      );

      if (remoteTasks != null) {
        await _mergeTasks(localTasks, remoteTasks, userId);
        return true;
      }

      return false;
    } on SyncException catch (e) {
      developer.log(
        'Failed to sync tasks: ${e.message}',
        name: 'SyncService',
        error: e.cause,
      );
      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error syncing tasks',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _mergeTasks(
    List<Task> localTasks,
    List<Task> remoteTasks,
    String userId,
  ) async {
    final localMap = {for (var task in localTasks) task.id: task};
    final remoteMap = {for (var task in remoteTasks) task.id: task};

    // Upload local-only tasks
    for (final task in localTasks) {
      if (!remoteMap.containsKey(task.id)) {
        await _uploadTask(task, userId);
      }
    }

    // Download remote-only tasks
    for (final task in remoteTasks) {
      if (!localMap.containsKey(task.id)) {
        await _taskBox.put(task.id, task);
      }
    }

    // Resolve conflicts using modifiedAt (last-write-wins)
    for (final task in localTasks) {
      if (remoteMap.containsKey(task.id)) {
        final remoteTask = remoteMap[task.id]!;
        if (remoteTask.modifiedAt.isAfter(task.modifiedAt)) {
          await _taskBox.put(task.id, remoteTask);
        } else if (task.modifiedAt.isAfter(remoteTask.modifiedAt)) {
          await _uploadTask(task, userId);
        }
      }
    }
  }

  Future<bool> _uploadTask(Task task, String userId) async {
    try {
      final taskData = task.toSyncMap(userId);
      await _executeWithRetry<void>(
        operation: () async {
          await _supabase.from('tasks').upsert(taskData);
        },
        operationName: 'Upload task ${task.id}',
      );
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to upload task: ${task.id}',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Project synchronization
  Future<bool> syncProjects() async {
    if (!_isInitialized) return false;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        developer.log(
          'Cannot sync projects: No authenticated user',
          name: 'SyncService',
        );
        return false;
      }

      final localProjects = _projectBox.values.toList();

      final remoteProjects = await _executeWithRetry<List<Project>>(
        operation: () async {
          final response =
              await _supabase.from('projects').select().eq('user_id', userId);

          final projects = <Project>[];
          for (final data in response) {
            try {
              projects.add(ProjectParsing.fromMap(data));
            } catch (e, stackTrace) {
              developer.log(
                'Failed to parse project from remote data',
                name: 'SyncService',
                error: e,
                stackTrace: stackTrace,
              );
            }
          }
          return projects;
        },
        operationName: 'Fetch remote projects',
      );

      if (remoteProjects != null) {
        await _mergeProjects(localProjects, remoteProjects, userId);
        return true;
      }

      return false;
    } on SyncException catch (e) {
      developer.log(
        'Failed to sync projects: ${e.message}',
        name: 'SyncService',
        error: e.cause,
      );
      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error syncing projects',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _mergeProjects(
    List<Project> localProjects,
    List<Project> remoteProjects,
    String userId,
  ) async {
    final localMap = {for (var p in localProjects) p.id: p};
    final remoteMap = {for (var p in remoteProjects) p.id: p};

    // Upload local-only projects
    for (final project in localProjects) {
      if (!remoteMap.containsKey(project.id)) {
        await _uploadProject(project, userId);
      }
    }

    // Download remote-only projects
    for (final project in remoteProjects) {
      if (!localMap.containsKey(project.id)) {
        await _projectBox.put(project.id, project);
      }
    }

    // Resolve conflicts using modifiedAt (last-write-wins)
    for (final project in localProjects) {
      if (remoteMap.containsKey(project.id)) {
        final remoteProject = remoteMap[project.id]!;
        if (remoteProject.modifiedAt.isAfter(project.modifiedAt)) {
          await _projectBox.put(project.id, remoteProject);
        } else if (project.modifiedAt.isAfter(remoteProject.modifiedAt)) {
          await _uploadProject(project, userId);
        }
      }
    }
  }

  Future<bool> _uploadProject(Project project, String userId) async {
    try {
      final data = project.toSyncMap(userId);
      await _executeWithRetry<void>(
        operation: () async {
          await _supabase.from('projects').upsert(data);
        },
        operationName: 'Upload project ${project.id}',
      );
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to upload project: ${project.id}',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Ritual synchronization
  Future<bool> syncRituals() async {
    if (!_isInitialized) return false;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        developer.log(
          'Cannot sync rituals: No authenticated user',
          name: 'SyncService',
        );
        return false;
      }

      final localRituals = _ritualBox.values.toList();

      final remoteRituals = await _executeWithRetry<List<Ritual>>(
        operation: () async {
          final response =
              await _supabase.from('rituals').select().eq('user_id', userId);

          final rituals = <Ritual>[];
          for (final ritualData in response) {
            try {
              rituals.add(RitualParsing.fromMap(ritualData));
            } catch (e, stackTrace) {
              developer.log(
                'Failed to parse ritual from remote data',
                name: 'SyncService',
                error: e,
                stackTrace: stackTrace,
              );
            }
          }
          return rituals;
        },
        operationName: 'Fetch remote rituals',
      );

      if (remoteRituals != null) {
        await _mergeRituals(localRituals, remoteRituals, userId);
        return true;
      }

      return false;
    } on SyncException catch (e) {
      developer.log(
        'Failed to sync rituals: ${e.message}',
        name: 'SyncService',
        error: e.cause,
      );
      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error syncing rituals',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _mergeRituals(
    List<Ritual> localRituals,
    List<Ritual> remoteRituals,
    String userId,
  ) async {
    final localMap = {for (var r in localRituals) r.id: r};
    final remoteMap = {for (var r in remoteRituals) r.id: r};

    for (final ritual in localRituals) {
      if (!remoteMap.containsKey(ritual.id)) {
        await _uploadRitual(ritual, userId);
      }
    }

    for (final ritual in remoteRituals) {
      if (!localMap.containsKey(ritual.id)) {
        await _ritualBox.put(ritual.id, ritual);
      }
    }
  }

  Future<bool> _uploadRitual(Ritual ritual, String userId) async {
    try {
      final ritualData = ritual.toSyncMap(userId);
      await _executeWithRetry<void>(
        operation: () async {
          await _supabase.from('rituals').upsert(ritualData);
        },
        operationName: 'Upload ritual ${ritual.id}',
      );
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to upload ritual: ${ritual.id}',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Full synchronization
  Future<bool> syncAll() async {
    if (!_isInitialized) return false;

    final projectsResult = await syncProjects();
    final tasksResult = await syncTasks();
    final ritualsResult = await syncRituals();

    return projectsResult && tasksResult && ritualsResult;
  }

  // Background sync
  void setupPeriodicSync() {
    // This would set up a timer or use work manager for periodic sync
    // Implementation depends on platform requirements
  }

  // Real-time subscriptions
  void setupRealtimeSync() {
    if (!_isInitialized) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Clean up existing channels first
    _cleanupChannels();

    final tasksChannel = _supabase.channel('photisnadi_sync')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tasks',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          syncTasks();
        },
      ).subscribe();
    _channels.add(tasksChannel);

    final projectsChannel = _supabase.channel('photisnadi_projects_sync')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'projects',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          syncProjects();
        },
      ).subscribe();
    _channels.add(projectsChannel);

    final ritualsChannel = _supabase.channel('photisnadi_rituals_sync')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'rituals',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          syncRituals();
        },
      ).subscribe();
    _channels.add(ritualsChannel);
  }

  void _cleanupChannels() {
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
  }

  @override
  void dispose() {
    _cleanupChannels();
    super.dispose();
  }
}
