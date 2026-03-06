import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../models/ritual.dart';
import '../models/project.dart';

/// Service for integrating with SecureYeoman API.
///
/// Provides:
/// - Task sync to SecureYeoman's brain/knowledge system
/// - Ritual analytics export
/// - Connection management
class YeomanService extends ChangeNotifier {
  http.Client _httpClient;
  Timer? _syncTimer;
  bool _isInitialized = false;
  bool _isEnabled = false;
  bool _disposed = false;
  String? _baseUrl;
  String? _apiKey;
  String? _accessToken;
  DateTime? _lastSyncedAt;
  YeomanSyncState _syncState = YeomanSyncState.idle;
  String? _syncError;

  YeomanService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  bool get isConnected => _apiKey != null || _accessToken != null;
  String? get baseUrl => _baseUrl;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  YeomanSyncState get syncState => _syncState;
  String? get syncError => _syncError;

  /// Initialize from persisted settings.
  Future<void> initialize() async {
    try {
      final settingsBox = await Hive.openBox('settings');
      _isEnabled = settingsBox.get('yeoman_enabled', defaultValue: false);
      _baseUrl = settingsBox.get('yeoman_base_url');
      _apiKey = settingsBox.get('yeoman_api_key');
      final lastSynced = settingsBox.get('yeoman_last_synced_at');
      if (lastSynced != null) {
        _lastSyncedAt = DateTime.tryParse(lastSynced);
      }

      _isInitialized = true;

      if (_isEnabled && isConnected) {
        _startPeriodicSync();
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize YeomanService',
        name: 'YeomanService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Configure connection to SecureYeoman instance.
  Future<bool> configure({
    required String baseUrl,
    String? apiKey,
    String? password,
  }) async {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    if (apiKey != null) {
      _apiKey = apiKey;
    } else if (password != null) {
      final success = await _authenticate(password);
      if (!success) return false;
    }

    final settingsBox = Hive.box('settings');
    await settingsBox.put('yeoman_base_url', _baseUrl);
    if (_apiKey != null) {
      await settingsBox.put('yeoman_api_key', _apiKey);
    }

    notifyListeners();
    return true;
  }

  /// Enable or disable SecureYeoman sync.
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final settingsBox = Hive.box('settings');
    await settingsBox.put('yeoman_enabled', enabled);

    if (enabled && isConnected) {
      _startPeriodicSync();
      syncAll();
    } else {
      _stopPeriodicSync();
    }
    notifyListeners();
  }

  /// Test connection to SecureYeoman.
  Future<bool> testConnection() async {
    if (_baseUrl == null) return false;

    try {
      final response = await _httpClient
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      developer.log(
        'Connection test failed',
        name: 'YeomanService',
        error: e,
      );
      return false;
    }
  }

  // ── Task Sync to Brain ──

  /// Sync all tasks to SecureYeoman's brain/knowledge system.
  Future<bool> syncTasks() async {
    if (!isConnected) return false;

    try {
      final taskBox = Hive.box<Task>('tasks');
      final projectBox = Hive.box<Project>('projects');
      final tasks = taskBox.values.toList();
      final projects = projectBox.values.toList();
      final projectMap = {for (var p in projects) p.id: p};

      // Build task summary for brain knowledge
      final tasksByProject = <String, List<Map<String, dynamic>>>{};
      for (final task in tasks) {
        final projectName = task.projectId != null
            ? (projectMap[task.projectId]?.name ?? 'Unknown')
            : 'Unassigned';
        tasksByProject.putIfAbsent(projectName, () => []);
        tasksByProject[projectName]!.add(_taskToKnowledge(task));
      }

      // Summary stats
      final stats = _buildTaskStats(tasks);

      // Push knowledge entry with full task state
      final success = await _upsertKnowledge(
        topic: 'photis-nadi-tasks',
        content: jsonEncode({
          'synced_at': DateTime.now().toIso8601String(),
          'stats': stats,
          'tasks_by_project': tasksByProject,
        }),
        source: 'photis-nadi',
        confidence: 1.0,
      );

      return success;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to sync tasks to Yeoman',
        name: 'YeomanService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Sync ritual analytics to SecureYeoman's brain.
  Future<bool> syncRitualAnalytics() async {
    if (!isConnected) return false;

    try {
      final ritualBox = Hive.box<Ritual>('rituals');
      final rituals = ritualBox.values.toList();

      final analytics = _buildRitualAnalytics(rituals);

      final success = await _upsertKnowledge(
        topic: 'photis-nadi-rituals',
        content: jsonEncode({
          'synced_at': DateTime.now().toIso8601String(),
          'analytics': analytics,
          'rituals': rituals.map(_ritualToKnowledge).toList(),
        }),
        source: 'photis-nadi',
        confidence: 1.0,
      );

      return success;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to sync ritual analytics to Yeoman',
        name: 'YeomanService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Full sync: tasks + rituals.
  Future<bool> syncAll() async {
    if (_disposed || !isConnected) return false;
    if (_syncState == YeomanSyncState.syncing) return false;

    _syncState = YeomanSyncState.syncing;
    _syncError = null;
    notifyListeners();

    try {
      final tasksOk = await syncTasks();
      final ritualsOk = await syncRitualAnalytics();

      final success = tasksOk && ritualsOk;
      _syncState = success ? YeomanSyncState.success : YeomanSyncState.error;
      if (success) {
        _lastSyncedAt = DateTime.now();
        final settingsBox = Hive.box('settings');
        await settingsBox.put(
          'yeoman_last_synced_at',
          _lastSyncedAt!.toIso8601String(),
        );
      } else {
        _syncError = 'Some items failed to sync';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _syncState = YeomanSyncState.error;
      _syncError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── API Key Management ──

  /// Generate an API key in SecureYeoman for Photis Nadi MCP server.
  /// Returns the API key string, or null on failure.
  Future<String?> generateApiKey({
    String name = 'Photis Nadi MCP',
    List<String> permissions = const [
      'brain.read',
      'brain.write',
      'tasks.read',
      'tasks.write',
    ],
  }) async {
    if (!isConnected) return null;

    try {
      final response = await _request(
        'POST',
        '/api/v1/auth/api-keys',
        body: {
          'name': name,
          'permissions': permissions,
        },
      );

      if (response != null && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return data['api_key'] as String?;
      }
      return null;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to generate API key',
        name: 'YeomanService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ── MCP Tool Registration ──

  /// Register Photis Nadi MCP tools in SecureYeoman.
  /// Requires Supabase URL and service role key for direct DB access.
  Future<bool> registerMcpTools({
    required String supabaseUrl,
    required String supabaseServiceKey,
  }) async {
    if (!isConnected) return false;

    try {
      final tools = [
        {
          'name': 'photis_list_tasks',
          'description': 'List tasks from Photis Nadi. Returns tasks with status, priority, due dates, tags, and dependencies.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'project_id': {'type': 'string', 'description': 'Filter by project ID'},
              'status': {'type': 'string', 'enum': ['todo', 'inProgress', 'inReview', 'blocked', 'done']},
              'priority': {'type': 'string', 'enum': ['low', 'medium', 'high']},
              'limit': {'type': 'number', 'description': 'Max results (default 50)'},
            },
          },
        },
        {
          'name': 'photis_create_task',
          'description': 'Create a new task in Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'description': 'Task title'},
              'description': {'type': 'string', 'description': 'Task description'},
              'project_id': {'type': 'string', 'description': 'Project ID'},
              'priority': {'type': 'string', 'enum': ['low', 'medium', 'high']},
              'status': {'type': 'string', 'enum': ['todo', 'inProgress', 'inReview', 'blocked', 'done']},
              'due_date': {'type': 'string', 'format': 'date-time'},
              'tags': {'type': 'array', 'items': {'type': 'string'}},
            },
            'required': ['title'],
          },
        },
        {
          'name': 'photis_update_task',
          'description': 'Update an existing task in Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'task_id': {'type': 'string', 'description': 'Task ID to update'},
              'title': {'type': 'string'},
              'description': {'type': 'string'},
              'status': {'type': 'string', 'enum': ['todo', 'inProgress', 'inReview', 'blocked', 'done']},
              'priority': {'type': 'string', 'enum': ['low', 'medium', 'high']},
              'due_date': {'type': 'string', 'format': 'date-time'},
              'tags': {'type': 'array', 'items': {'type': 'string'}},
            },
            'required': ['task_id'],
          },
        },
        {
          'name': 'photis_list_projects',
          'description': 'List projects from Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'include_archived': {'type': 'boolean', 'description': 'Include archived projects'},
            },
          },
        },
        {
          'name': 'photis_list_rituals',
          'description': 'List rituals with completion status and streak data from Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'frequency': {'type': 'string', 'enum': ['daily', 'weekly', 'monthly']},
            },
          },
        },
        {
          'name': 'photis_task_analytics',
          'description': 'Get task analytics and productivity insights from Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {},
          },
        },
      ];

      final response = await _request(
        'POST',
        '/api/v1/mcp/servers',
        body: {
          'name': 'Photis Nadi',
          'description': 'Task management and ritual tracking from Photis Nadi',
          'transport': 'streamable-http',
          'url': supabaseUrl,
          'env': {
            'SUPABASE_URL': supabaseUrl,
            'SUPABASE_SERVICE_KEY': supabaseServiceKey,
          },
          'enabled': true,
          'tools': tools,
        },
      );

      return response != null && response.statusCode < 300;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to register MCP tools',
        name: 'YeomanService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ── Private Helpers ──

  Future<bool> _authenticate(String password) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Auth failed', name: 'YeomanService', error: e);
      return false;
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_apiKey != null) {
      headers['X-API-Key'] = _apiKey!;
    } else if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<http.Response?> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    if (_baseUrl == null) return null;

    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);

    try {
      late http.Response response;
      final bodyStr = body != null ? jsonEncode(body) : null;

      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: _headers);
        case 'POST':
          response = await _httpClient.post(uri, headers: _headers, body: bodyStr);
        case 'PUT':
          response = await _httpClient.put(uri, headers: _headers, body: bodyStr);
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: _headers);
        default:
          return null;
      }

      if (response.statusCode == 401 && _accessToken != null) {
        // Token expired — clear it
        _accessToken = null;
        _syncError = 'Authentication expired';
        notifyListeners();
      }

      return response;
    } catch (e) {
      developer.log(
        'Request failed: $method $path',
        name: 'YeomanService',
        error: e,
      );
      return null;
    }
  }

  /// Upsert a knowledge entry in SecureYeoman's brain.
  Future<bool> _upsertKnowledge({
    required String topic,
    required String content,
    required String source,
    required double confidence,
  }) async {
    // Check if existing knowledge entry exists for this topic
    final existing = await _request(
      'GET',
      '/api/v1/brain/knowledge',
      queryParams: {'topic': topic, 'limit': '1'},
    );

    if (existing != null && existing.statusCode == 200) {
      final data = jsonDecode(existing.body);
      final entries = data['knowledge'] as List?;

      if (entries != null && entries.isNotEmpty) {
        // Update existing — delete and recreate
        final existingId = entries.first['id'];
        await _request('DELETE', '/api/v1/brain/knowledge/$existingId');
      }
    }

    final response = await _request(
      'POST',
      '/api/v1/brain/knowledge',
      body: {
        'topic': topic,
        'content': content,
        'source': source,
        'confidence': confidence,
      },
    );

    return response != null && response.statusCode < 300;
  }

  Map<String, dynamic> _taskToKnowledge(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'status': task.status.toString().split('.').last,
      'priority': task.priority.toString().split('.').last,
      'task_key': task.taskKey,
      'due_date': task.dueDate?.toIso8601String(),
      'tags': task.tags,
      'depends_on': task.dependsOn,
      'created_at': task.createdAt.toIso8601String(),
      'modified_at': task.modifiedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _buildTaskStats(List<Task> tasks) {
    final byStatus = <String, int>{};
    final byPriority = <String, int>{};
    int overdue = 0;
    int dueToday = 0;
    int blocked = 0;

    final now = DateTime.now();

    for (final task in tasks) {
      final status = task.status.toString().split('.').last;
      byStatus[status] = (byStatus[status] ?? 0) + 1;

      final priority = task.priority.toString().split('.').last;
      byPriority[priority] = (byPriority[priority] ?? 0) + 1;

      if (task.dueDate != null && task.status != TaskStatus.done) {
        if (task.dueDate!.isBefore(now)) overdue++;
        if (task.dueDate!.year == now.year &&
            task.dueDate!.month == now.month &&
            task.dueDate!.day == now.day) {
          dueToday++;
        }
      }

      if (task.dependsOn.isNotEmpty && task.status != TaskStatus.done) {
        blocked++;
      }
    }

    return {
      'total': tasks.length,
      'by_status': byStatus,
      'by_priority': byPriority,
      'overdue': overdue,
      'due_today': dueToday,
      'blocked': blocked,
    };
  }

  Map<String, dynamic> _ritualToKnowledge(Ritual ritual) {
    return {
      'id': ritual.id,
      'title': ritual.title,
      'description': ritual.description,
      'frequency': ritual.frequency.toString().split('.').last,
      'is_completed': ritual.isCompleted,
      'streak_count': ritual.streakCount,
      'last_completed': ritual.lastCompleted?.toIso8601String(),
    };
  }

  Map<String, dynamic> _buildRitualAnalytics(List<Ritual> rituals) {
    final total = rituals.length;
    final completed = rituals.where((r) => r.isCompleted).length;
    final avgStreak = total > 0
        ? rituals.fold<int>(0, (sum, r) => sum + r.streakCount) / total
        : 0.0;
    final longestStreak = rituals.fold<int>(0, (max, r) =>
        r.streakCount > max ? r.streakCount : max);

    final byFrequency = <String, Map<String, dynamic>>{};
    for (final freq in ['daily', 'weekly', 'monthly']) {
      final group = rituals.where(
        (r) => r.frequency.toString().split('.').last == freq,
      ).toList();
      if (group.isNotEmpty) {
        final groupCompleted = group.where((r) => r.isCompleted).length;
        byFrequency[freq] = {
          'total': group.length,
          'completed': groupCompleted,
          'completion_rate': groupCompleted / group.length,
          'avg_streak': group.fold<int>(0, (s, r) => s + r.streakCount) / group.length,
        };
      }
    }

    return {
      'total_rituals': total,
      'completed_today': completed,
      'completion_rate': total > 0 ? completed / total : 0.0,
      'average_streak': avgStreak,
      'longest_streak': longestStreak,
      'by_frequency': byFrequency,
    };
  }

  void _startPeriodicSync() {
    _stopPeriodicSync();
    // Sync every 10 minutes
    _syncTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => syncAll(),
    );
    // Sync immediately
    syncAll();
  }

  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Disconnect and clear stored credentials.
  Future<void> disconnect() async {
    _stopPeriodicSync();
    _accessToken = null;
    _apiKey = null;
    _isEnabled = false;
    _syncState = YeomanSyncState.idle;

    final settingsBox = Hive.box('settings');
    await settingsBox.delete('yeoman_api_key');
    await settingsBox.put('yeoman_enabled', false);

    notifyListeners();
  }

  @visibleForTesting
  void setHttpClient(http.Client client) {
    _httpClient = client;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPeriodicSync();
    super.dispose();
  }
}

enum YeomanSyncState { idle, syncing, success, error }
