import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';
import '../models/tag.dart';

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
      dependsOn: List<String>.from(data['depends_on'] ?? []),
      subtasks: List<String>.from(data['subtasks'] ?? []),
      estimatedMinutes: data['estimated_minutes'] as int?,
      trackedMinutes: (data['tracked_minutes'] as int?) ?? 0,
      recurrence: data['recurrence'] as String?,
      attachments: List<String>.from(data['attachments'] ?? []),
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
      'depends_on': dependsOn,
      'subtasks': subtasks,
      'estimated_minutes': estimatedMinutes,
      'tracked_minutes': trackedMinutes,
      'recurrence': recurrence,
      'attachments': attachments,
    };
  }
}

extension ProjectParsing on Project {
  static Project fromMap(Map<String, dynamic> data) {
    return Project(
      id: data['id'] as String,
      name: data['name'] as String,
      projectKey: data['key'] as String,
      description: data['description'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      color: data['color'] ?? '#4A90E2',
      iconName: data['icon_name'] as String?,
      taskCounter: data['task_counter'] ?? 0,
      isArchived: data['is_archived'] ?? false,
      modifiedAt: data['modified_at'] != null
          ? DateTime.parse(data['modified_at'] as String)
          : DateTime.parse(data['created_at'] as String),
      sharedWith: List<String>.from(data['shared_with'] ?? []),
      ownerId: data['owner_id'] as String?,
    );
  }

  Map<String, dynamic> toSyncMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'key': projectKey,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'color': color,
      'icon_name': iconName,
      'task_counter': taskCounter,
      'is_archived': isArchived,
      'modified_at': modifiedAt.toIso8601String(),
      'shared_with': sharedWith,
      'owner_id': ownerId,
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

extension TagParsing on Tag {
  static Tag fromMap(Map<String, dynamic> data) {
    return Tag(
      id: data['id'] as String,
      name: data['name'] as String,
      color: data['color'] as String,
      projectId: data['project_id'] as String,
    );
  }

  Map<String, dynamic> toSyncMap(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color': color,
      'project_id': projectId,
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

/// Represents a sync conflict between local and remote data.
class SyncConflict {
  final String entityType; // 'task', 'project', 'ritual'
  final String entityId;
  final String entityTitle;
  final DateTime localModifiedAt;
  final DateTime remoteModifiedAt;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;

  SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.entityTitle,
    required this.localModifiedAt,
    required this.remoteModifiedAt,
    required this.localData,
    required this.remoteData,
  });
}

/// Resolution choice for a sync conflict.
enum ConflictResolution { keepLocal, keepRemote }

/// Sync state enum for UI display.
enum SyncState { idle, syncing, success, error }

/// Handles synchronization with Supabase backend.
class SyncService extends ChangeNotifier {
  late final Box<Task> _taskBox;
  late final Box<Ritual> _ritualBox;
  late final Box<Project> _projectBox;
  late final Box<Tag> _tagBox;
  late final SupabaseClient _supabase;
  bool _isInitialized = false;
  final List<RealtimeChannel> _channels = [];
  Timer? _periodicSyncTimer;
  StreamSubscription<AuthState>? _authSubscription;

  // Sync status
  SyncState _syncState = SyncState.idle;
  String? _syncError;
  DateTime? _lastSyncedAt;
  bool _isSyncEnabled = false;

  // Conflict tracking
  final List<SyncConflict> _pendingConflicts = [];

  bool get isInitialized => _isInitialized;
  SyncState get syncState => _syncState;
  String? get syncError => _syncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isSyncEnabled => _isSyncEnabled;
  bool get isAuthenticated =>
      _isInitialized && _supabase.auth.currentUser != null;
  String? get currentUserEmail =>
      _isInitialized ? _supabase.auth.currentUser?.email : null;
  List<SyncConflict> get pendingConflicts =>
      List.unmodifiable(_pendingConflicts);
  bool get hasConflicts => _pendingConflicts.isNotEmpty;

  Future<bool> initialize() async {
    try {
      _supabase = Supabase.instance.client;
      _taskBox = await Hive.openBox<Task>('tasks');
      _ritualBox = await Hive.openBox<Ritual>('rituals');
      _projectBox = await Hive.openBox<Project>('projects');
      _tagBox = await Hive.openBox<Tag>('tags');

      // Load sync preferences
      final settingsBox = await Hive.openBox('settings');
      _isSyncEnabled = settingsBox.get('sync_enabled', defaultValue: false);
      final lastSynced = settingsBox.get('last_synced_at');
      if (lastSynced != null) {
        _lastSyncedAt = DateTime.tryParse(lastSynced);
      }

      // Listen to auth state changes
      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
        notifyListeners();
        if (data.event == AuthChangeEvent.signedIn && _isSyncEnabled) {
          syncAll();
          setupRealtimeSync();
          _startPeriodicSync();
        } else if (data.event == AuthChangeEvent.signedOut) {
          _cleanupChannels();
          _stopPeriodicSync();
        }
      });

      _isInitialized = true;

      // Auto-sync if enabled and authenticated
      if (_isSyncEnabled && isAuthenticated) {
        syncAll();
        setupRealtimeSync();
        _startPeriodicSync();
      }

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

  // Auth methods
  Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Sign in failed: $e';
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Sign up failed: $e';
    }
  }

  Future<void> signOut() async {
    _cleanupChannels();
    _stopPeriodicSync();
    await _supabase.auth.signOut();
    _syncState = SyncState.idle;
    _pendingConflicts.clear();
    notifyListeners();
  }

  // Sync enable/disable
  Future<void> setSyncEnabled({required bool enabled}) async {
    _isSyncEnabled = enabled;
    final settingsBox = Hive.box('settings');
    await settingsBox.put('sync_enabled', enabled);

    if (enabled && isAuthenticated) {
      syncAll();
      setupRealtimeSync();
      _startPeriodicSync();
    } else {
      _cleanupChannels();
      _stopPeriodicSync();
    }
    notifyListeners();
  }

  void _startPeriodicSync() {
    _stopPeriodicSync();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncAll(),
    );
  }

  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  Future<void> _updateLastSyncedAt() async {
    _lastSyncedAt = DateTime.now();
    final settingsBox = Hive.box('settings');
    await settingsBox.put(
      'last_synced_at',
      _lastSyncedAt!.toIso8601String(),
    );
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
        final diff = remoteTask.modifiedAt.difference(task.modifiedAt).abs();

        // If both modified within 5 seconds, flag as conflict
        if (diff.inSeconds < 5 && remoteTask.modifiedAt != task.modifiedAt) {
          _pendingConflicts.add(SyncConflict(
            entityType: 'task',
            entityId: task.id,
            entityTitle: task.title,
            localModifiedAt: task.modifiedAt,
            remoteModifiedAt: remoteTask.modifiedAt,
            localData: task.toSyncMap(userId),
            remoteData: remoteTask.toSyncMap(userId),
          ));
        } else if (remoteTask.modifiedAt.isAfter(task.modifiedAt)) {
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
        final diff =
            remoteProject.modifiedAt.difference(project.modifiedAt).abs();

        if (diff.inSeconds < 5 &&
            remoteProject.modifiedAt != project.modifiedAt) {
          _pendingConflicts.add(SyncConflict(
            entityType: 'project',
            entityId: project.id,
            entityTitle: project.name,
            localModifiedAt: project.modifiedAt,
            remoteModifiedAt: remoteProject.modifiedAt,
            localData: project.toSyncMap(userId),
            remoteData: remoteProject.toSyncMap(userId),
          ));
        } else if (remoteProject.modifiedAt.isAfter(project.modifiedAt)) {
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

    // Upload local-only rituals
    for (final ritual in localRituals) {
      if (!remoteMap.containsKey(ritual.id)) {
        await _uploadRitual(ritual, userId);
      }
    }

    // Download remote-only rituals
    for (final ritual in remoteRituals) {
      if (!localMap.containsKey(ritual.id)) {
        await _ritualBox.put(ritual.id, ritual);
      }
    }

    // Resolve conflicts using createdAt comparison (rituals lack modifiedAt)
    for (final ritual in localRituals) {
      if (remoteMap.containsKey(ritual.id)) {
        final remoteRitual = remoteMap[ritual.id]!;
        // For rituals, use lastCompleted or createdAt as proxy for modification
        final localTime = ritual.lastCompleted ?? ritual.createdAt;
        final remoteTime = remoteRitual.lastCompleted ?? remoteRitual.createdAt;

        if (remoteTime.isAfter(localTime)) {
          await _ritualBox.put(ritual.id, remoteRitual);
        } else if (localTime.isAfter(remoteTime)) {
          await _uploadRitual(ritual, userId);
        }
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
    if (!_isInitialized || !isAuthenticated) return false;
    if (_syncState == SyncState.syncing) return false;

    _syncState = SyncState.syncing;
    _syncError = null;
    notifyListeners();

    try {
      final projectsResult = await syncProjects();
      final tasksResult = await syncTasks();
      final ritualsResult = await syncRituals();
      final tagsResult = await syncTags();

      final success =
          projectsResult && tasksResult && ritualsResult && tagsResult;

      _syncState = success ? SyncState.success : SyncState.error;
      if (success) {
        await _updateLastSyncedAt();
      } else {
        _syncError = 'Some items failed to sync';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _syncState = SyncState.error;
      _syncError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Tag synchronization
  Future<bool> syncTags() async {
    if (!_isInitialized) return false;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final localTags = _tagBox.values.toList();

      final remoteTags = await _executeWithRetry<List<Tag>>(
        operation: () async {
          final response =
              await _supabase.from('tags').select().eq('user_id', userId);

          final tags = <Tag>[];
          for (final data in response) {
            try {
              tags.add(TagParsing.fromMap(data));
            } catch (e, stackTrace) {
              developer.log(
                'Failed to parse tag from remote data',
                name: 'SyncService',
                error: e,
                stackTrace: stackTrace,
              );
            }
          }
          return tags;
        },
        operationName: 'Fetch remote tags',
      );

      if (remoteTags != null) {
        await _mergeTags(localTags, remoteTags, userId);
        return true;
      }

      return false;
    } on SyncException catch (e) {
      developer.log(
        'Failed to sync tags: ${e.message}',
        name: 'SyncService',
        error: e.cause,
      );
      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error syncing tags',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _mergeTags(
    List<Tag> localTags,
    List<Tag> remoteTags,
    String userId,
  ) async {
    final localMap = {for (var t in localTags) t.id: t};
    final remoteMap = {for (var t in remoteTags) t.id: t};

    for (final tag in localTags) {
      if (!remoteMap.containsKey(tag.id)) {
        await _uploadTag(tag, userId);
      }
    }

    for (final tag in remoteTags) {
      if (!localMap.containsKey(tag.id)) {
        await _tagBox.put(tag.id, tag);
      }
    }
  }

  Future<bool> _uploadTag(Tag tag, String userId) async {
    try {
      final data = tag.toSyncMap(userId);
      await _executeWithRetry<void>(
        operation: () async {
          await _supabase.from('tags').upsert(data);
        },
        operationName: 'Upload tag ${tag.id}',
      );
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to upload tag: ${tag.id}',
        name: 'SyncService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Conflict resolution
  Future<void> resolveConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (resolution == ConflictResolution.keepLocal) {
      // Upload local version to remote
      switch (conflict.entityType) {
        case 'task':
          final task = _taskBox.get(conflict.entityId);
          if (task != null) await _uploadTask(task, userId);
        case 'project':
          final project = _projectBox.get(conflict.entityId);
          if (project != null) await _uploadProject(project, userId);
        case 'ritual':
          final ritual = _ritualBox.get(conflict.entityId);
          if (ritual != null) await _uploadRitual(ritual, userId);
      }
    } else {
      // Apply remote version locally
      switch (conflict.entityType) {
        case 'task':
          final task = TaskParsing.fromMap(conflict.remoteData);
          await _taskBox.put(task.id, task);
        case 'project':
          final project = ProjectParsing.fromMap(conflict.remoteData);
          await _projectBox.put(project.id, project);
        case 'ritual':
          final ritual = RitualParsing.fromMap(conflict.remoteData);
          await _ritualBox.put(ritual.id, ritual);
      }
    }

    _pendingConflicts.remove(conflict);
    notifyListeners();
  }

  Future<void> resolveAllConflicts(ConflictResolution resolution) async {
    final conflicts = List<SyncConflict>.from(_pendingConflicts);
    for (final conflict in conflicts) {
      await resolveConflict(conflict, resolution);
    }
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

    final tagsChannel = _supabase.channel('photisnadi_tags_sync')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tags',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          syncTags();
        },
      ).subscribe();
    _channels.add(tagsChannel);
  }

  void _cleanupChannels() {
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cleanupChannels();
    _stopPeriodicSync();
    super.dispose();
  }
}
