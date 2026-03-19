import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/services/task_service.dart';
import 'package:photisnadi/services/yeoman_service.dart';
import 'package:photisnadi/services/theme_service.dart';
import 'package:photisnadi/services/export_import_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

bool _adaptersRegistered = false;

void _registerAdapters() {
  if (_adaptersRegistered) return;
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(TaskPriorityAdapter());
  Hive.registerAdapter(RitualAdapter());
  Hive.registerAdapter(RitualFrequencyAdapter());
  Hive.registerAdapter(BoardAdapter());
  Hive.registerAdapter(BoardColumnAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(TagAdapter());
  _adaptersRegistered = true;
}

void main() {
  // ── YeomanService Tests ──

  group('YeomanService Tests', () {
    late YeomanService yeomanService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      await Hive.openBox('settings');
      await Hive.openBox<Task>('tasks');
      await Hive.openBox<Ritual>('rituals');
      await Hive.openBox<Project>('projects');
      yeomanService = YeomanService();
    });

    tearDown(() async {
      yeomanService.dispose();
      await tearDownTestHive();
    });

    test('initial state is disconnected', () {
      expect(yeomanService.isInitialized, false);
      expect(yeomanService.isEnabled, false);
      expect(yeomanService.isConnected, false);
      expect(yeomanService.syncState, YeomanSyncState.idle);
    });

    test('initialize loads settings from Hive', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge') {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'knowledge': []}), 200);
          }
          return http.Response(jsonEncode({'id': 'k1'}), 201);
        }
        return http.Response('OK', 200);
      });
      yeomanService.httpClient = mockClient;

      final settingsBox = Hive.box('settings');
      await settingsBox.put('yeoman_enabled', true);
      await settingsBox.put('yeoman_base_url', 'http://localhost:18789');
      await settingsBox.put('yeoman_api_key', 'sk-test-key');
      await settingsBox.put(
          'yeoman_last_synced_at', '2026-03-01T00:00:00.000Z');

      await yeomanService.initialize();

      expect(yeomanService.isInitialized, true);
      expect(yeomanService.isEnabled, true);
      expect(yeomanService.baseUrl, 'http://localhost:18789');
      expect(yeomanService.isConnected, true);
      expect(yeomanService.lastSyncedAt, isNotNull);
    });

    test('configure saves baseUrl and apiKey', () async {
      await yeomanService.initialize();

      final result = await yeomanService.configure(
        baseUrl: 'http://localhost:18789/',
        apiKey: 'sk-test',
      );

      expect(result, true);
      expect(yeomanService.baseUrl, 'http://localhost:18789');
      expect(yeomanService.isConnected, true);

      final settingsBox = Hive.box('settings');
      expect(settingsBox.get('yeoman_base_url'), 'http://localhost:18789');
      expect(settingsBox.get('yeoman_api_key'), 'sk-test');
    });

    test('configure with password authenticates via API', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'access_token': 'jwt-test-token',
              'refresh_token': 'refresh-token',
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();

      final result = await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        password: 'admin-pass',
      );

      expect(result, true);
      expect(yeomanService.isConnected, true);
    });

    test('configure with wrong password fails', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();

      final result = await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        password: 'wrong',
      );

      expect(result, false);
    });

    test('testConnection returns true on healthy server', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response(jsonEncode({'status': 'healthy'}), 200);
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.testConnection();
      expect(result, true);
    });

    test('testConnection returns false on unreachable server', () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception('Connection refused');
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:99999',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.testConnection();
      expect(result, false);
    });

    test('setEnabled persists to settings', () async {
      await yeomanService.initialize();
      await yeomanService.setEnabled(enabled: true);

      final settingsBox = Hive.box('settings');
      expect(settingsBox.get('yeoman_enabled'), true);
      expect(yeomanService.isEnabled, true);

      await yeomanService.setEnabled(enabled: false);
      expect(settingsBox.get('yeoman_enabled'), false);
    });

    test('syncTasks pushes task data to brain knowledge', () async {
      final requests = <http.Request>[];
      final mockClient = http_testing.MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'GET') {
          return http.Response(jsonEncode({'knowledge': []}), 200);
        }
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'know_123'}), 201);
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final taskBox = Hive.box<Task>('tasks');
      const taskId = '550e8400-e29b-41d4-a716-446655440000';
      await taskBox.put(
        taskId,
        Task(
          id: taskId,
          title: 'Test Task',
          status: TaskStatus.todo,
          priority: TaskPriority.high,
          createdAt: DateTime.now(),
        ),
      );

      final result = await yeomanService.syncTasks();
      expect(result, true);

      final postRequests = requests.where(
        (r) => r.method == 'POST' && r.url.path == '/api/v1/brain/knowledge',
      );
      expect(postRequests, isNotEmpty);

      final postBody = jsonDecode(postRequests.first.body);
      expect(postBody['topic'], 'photis-nadi-tasks');
      expect(postBody['source'], 'photis-nadi');
    });

    test('syncRitualAnalytics computes correct stats', () async {
      final capturedBody = <String, dynamic>{};
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'GET') {
          return http.Response(jsonEncode({'knowledge': []}), 200);
        }
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'POST') {
          capturedBody.addAll(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          return http.Response(jsonEncode({'id': 'know_456'}), 201);
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final ritualBox = Hive.box<Ritual>('rituals');
      const ritualId1 = '550e8400-e29b-41d4-a716-446655440001';
      const ritualId2 = '550e8400-e29b-41d4-a716-446655440002';
      await ritualBox.put(
        ritualId1,
        Ritual(
          id: ritualId1,
          title: 'Morning Meditation',
          isCompleted: true,
          createdAt: DateTime.now(),
          streakCount: 5,
          frequency: RitualFrequency.daily,
        ),
      );
      await ritualBox.put(
        ritualId2,
        Ritual(
          id: ritualId2,
          title: 'Weekly Review',
          isCompleted: false,
          createdAt: DateTime.now(),
          streakCount: 3,
          frequency: RitualFrequency.weekly,
        ),
      );

      final result = await yeomanService.syncRitualAnalytics();
      expect(result, true);

      expect(capturedBody['topic'], 'photis-nadi-rituals');
      final content = jsonDecode(capturedBody['content']);
      final analytics = content['analytics'];
      expect(analytics['total_rituals'], 2);
      expect(analytics['completed_today'], 1);
      expect(analytics['longest_streak'], 5);
      expect(analytics['average_streak'], 4.0);
      expect(analytics['by_frequency']['daily']['total'], 1);
      expect(analytics['by_frequency']['weekly']['total'], 1);
    });

    test('syncAll sets state correctly on success', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge') {
          if (request.method == 'GET') {
            return http.Response(jsonEncode({'knowledge': []}), 200);
          }
          if (request.method == 'POST') {
            return http.Response(jsonEncode({'id': 'k1'}), 201);
          }
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.syncAll();
      expect(result, true);
      expect(yeomanService.syncState, YeomanSyncState.success);
      expect(yeomanService.lastSyncedAt, isNotNull);
    });

    test('syncAll sets error state on failure', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.syncAll();
      expect(result, false);
      expect(yeomanService.syncState, YeomanSyncState.error);
    });

    test('generateApiKey returns key on success', () async {
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/auth/api-keys' &&
            request.method == 'POST') {
          final body = jsonDecode(request.body);
          expect(body['name'], 'Photis Nadi MCP');
          expect(body['permissions'], contains('brain.read'));
          return http.Response(
            jsonEncode({
              'id': 'key_123',
              'name': 'Photis Nadi MCP',
              'api_key': 'sk-generated-key',
              'permissions': body['permissions'],
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-admin',
      );

      final key = await yeomanService.generateApiKey();
      expect(key, 'sk-generated-key');
    });

    test('generateApiKey returns null when not connected', () async {
      await yeomanService.initialize();
      final key = await yeomanService.generateApiKey();
      expect(key, null);
    });

    test('registerMcpTools sends correct tool manifest', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/mcp/servers' &&
            request.method == 'POST') {
          capturedBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'server': {'id': 'srv_123'}
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.registerMcpTools(
        apiUrl: 'http://photisnadi:8081',
        apiKey: 'test-api-key-123',
      );

      expect(result, true);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['name'], 'Photis Nadi');
      expect(capturedBody!['transport'], 'streamable-http');

      final tools = capturedBody!['tools'] as List;
      expect(tools.length, 6);

      final toolNames = tools.map((t) => t['name']).toSet();
      expect(toolNames, contains('photis_list_tasks'));
      expect(toolNames, contains('photis_create_task'));
      expect(toolNames, contains('photis_update_task'));
      expect(toolNames, contains('photis_list_projects'));
      expect(toolNames, contains('photis_list_rituals'));
      expect(toolNames, contains('photis_task_analytics'));
    });

    test('disconnect clears credentials and stops sync', () async {
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );
      await yeomanService.setEnabled(enabled: true);

      expect(yeomanService.isConnected, true);
      expect(yeomanService.isEnabled, true);

      await yeomanService.disconnect();

      expect(yeomanService.isConnected, false);
      expect(yeomanService.isEnabled, false);
      expect(yeomanService.syncState, YeomanSyncState.idle);

      final settingsBox = Hive.box('settings');
      expect(settingsBox.get('yeoman_api_key'), null);
      expect(settingsBox.get('yeoman_enabled'), false);
    });

    test('upserts knowledge by deleting existing entry first', () async {
      final deleteCalled = <String>[];
      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'knowledge': [
                {'id': 'existing_123', 'topic': 'photis-nadi-tasks'}
              ]
            }),
            200,
          );
        }
        if (request.url.path.startsWith('/api/v1/brain/knowledge/') &&
            request.method == 'DELETE') {
          deleteCalled.add(request.url.pathSegments.last);
          return http.Response('', 204);
        }
        if (request.url.path == '/api/v1/brain/knowledge' &&
            request.method == 'POST') {
          return http.Response(jsonEncode({'id': 'new_456'}), 201);
        }
        return http.Response('Not found', 404);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-test',
      );

      final result = await yeomanService.syncTasks();
      expect(result, true);
      expect(deleteCalled, contains('existing_123'));
    });

    test('headers include API key when set', () async {
      String? capturedAuthHeader;
      final mockClient = http_testing.MockClient((request) async {
        capturedAuthHeader = request.headers['X-API-Key'];
        return http.Response(jsonEncode({'knowledge': []}), 200);
      });

      yeomanService.httpClient = mockClient;
      await yeomanService.initialize();
      await yeomanService.configure(
        baseUrl: 'http://localhost:18789',
        apiKey: 'sk-my-key',
      );

      await yeomanService.syncTasks();
      expect(capturedAuthHeader, 'sk-my-key');
    });
  });

  // ── YeomanService Extended Tests ──

  group('YeomanService Extended Tests', () {
    test('default state is not initialized', () {
      final service = YeomanService();
      expect(service.isInitialized, false);
      expect(service.isEnabled, false);
      expect(service.isConnected, false);
      expect(service.baseUrl, isNull);
      expect(service.lastSyncedAt, isNull);
      expect(service.syncState, YeomanSyncState.idle);
      expect(service.syncError, isNull);
    });

    test('accepts custom http client', () {
      final client = http_testing.MockClient(
        (request) async => http.Response('{}', 200),
      );
      final service = YeomanService(httpClient: client);
      expect(service, isNotNull);
    });
  });

  // ── ThemeService Tests ──

  group('ThemeService Tests', () {
    test('AccentColor enum has correct values', () {
      expect(AccentColor.values.length, 8);
      expect(AccentColor.indigo.label, 'Indigo');
      expect(AccentColor.rose.label, 'Rose');
      expect(AccentColor.emerald.label, 'Emerald');
    });

    test('default state is comfortable with indigo', () {
      final service = ThemeService();
      expect(service.accentColor, AccentColor.indigo);
      expect(service.layoutDensity, LayoutDensity.comfortable);
      expect(service.isCompact, false);
      expect(service.isEReaderMode, false);
      expect(service.isDarkMode, false);
    });

    test('LayoutDensity compact check works', () {
      final service = ThemeService();
      expect(service.isCompact, false);
    });

    test('default values are correct', () {
      final service = ThemeService();
      expect(service.isEReaderMode, isFalse);
      expect(service.isDarkMode, isFalse);
      expect(service.accentColor, AccentColor.indigo);
      expect(service.layoutDensity, LayoutDensity.comfortable);
      expect(service.isCompact, isFalse);
    });

    test('AccentColor enum has correct labels', () {
      expect(AccentColor.indigo.label, 'Indigo');
      expect(AccentColor.teal.label, 'Teal');
      expect(AccentColor.rose.label, 'Rose');
    });

    test('AccentColor enum has non-zero colors', () {
      for (final color in AccentColor.values) {
        expect(color.color.toARGB32(), isNonZero);
      }
    });
  });

  // ── ThemeService Extended Tests ──

  group('ThemeService Extended Tests', () {
    test('LayoutDensity enum values', () {
      expect(LayoutDensity.values.length, 2);
      expect(LayoutDensity.compact.name, 'compact');
      expect(LayoutDensity.comfortable.name, 'comfortable');
    });

    test('isCompact reflects layout density', () {
      final service = ThemeService();
      expect(service.isCompact, false);
    });

    test('AccentColor has all expected values', () {
      expect(AccentColor.values.length, 8);
      final names = AccentColor.values.map((c) => c.label).toList();
      expect(
          names,
          containsAll([
            'Indigo',
            'Teal',
            'Rose',
            'Amber',
            'Emerald',
            'Violet',
            'Sky',
            'Orange'
          ]));
    });
  });

  // ── ThemeService Persistence Tests ──

  group('ThemeService Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('toggleDarkMode toggles and persists', () async {
      final service = ThemeService();
      expect(service.isDarkMode, false);

      final result = await service.toggleDarkMode();
      expect(result, true);
      expect(service.isDarkMode, true);

      final result2 = await service.toggleDarkMode();
      expect(result2, true);
      expect(service.isDarkMode, false);
    });

    test('toggleEReaderMode toggles and persists', () async {
      final service = ThemeService();
      expect(service.isEReaderMode, false);

      final result = await service.toggleEReaderMode();
      expect(result, true);
      expect(service.isEReaderMode, true);
    });

    test('setAccentColor changes and persists', () async {
      final service = ThemeService();
      final result = await service.setAccentColor(AccentColor.rose);
      expect(result, true);
      expect(service.accentColor, AccentColor.rose);
    });

    test('setLayoutDensity changes and persists', () async {
      final service = ThemeService();
      final result = await service.setLayoutDensity(LayoutDensity.compact);
      expect(result, true);
      expect(service.layoutDensity, LayoutDensity.compact);
      expect(service.isCompact, true);
    });

    test('loadPreferences restores saved values', () async {
      SharedPreferences.setMockInitialValues({
        'dark_mode': true,
        'e_reader_mode': true,
        'accent_color': 'teal',
        'layout_density': 'compact',
      });

      final service = ThemeService();
      final result = await service.loadPreferences();
      expect(result, true);
      expect(service.isDarkMode, true);
      expect(service.isEReaderMode, true);
      expect(service.accentColor, AccentColor.teal);
      expect(service.layoutDensity, LayoutDensity.compact);
    });

    test('loadPreferences handles unknown accent color', () async {
      SharedPreferences.setMockInitialValues({
        'accent_color': 'nonexistent',
      });

      final service = ThemeService();
      await service.loadPreferences();
      expect(service.accentColor, AccentColor.indigo);
    });

    test('loadPreferences handles unknown layout density', () async {
      SharedPreferences.setMockInitialValues({
        'layout_density': 'nonexistent',
      });

      final service = ThemeService();
      await service.loadPreferences();
      expect(service.layoutDensity, LayoutDensity.comfortable);
    });

    test('loadPreferences with defaults', () async {
      final service = ThemeService();
      final result = await service.loadPreferences();
      expect(result, isTrue);
      expect(service.isEReaderMode, isFalse);
      expect(service.isDarkMode, isFalse);
      expect(service.accentColor, AccentColor.indigo);
      expect(service.layoutDensity, LayoutDensity.comfortable);
      expect(service.isCompact, isFalse);
    });

    test('loadPreferences with saved values', () async {
      SharedPreferences.setMockInitialValues({
        'e_reader_mode': true,
        'dark_mode': true,
        'accent_color': 'teal',
        'layout_density': 'compact',
      });
      final service = ThemeService();
      await service.loadPreferences();
      expect(service.isEReaderMode, isTrue);
      expect(service.isDarkMode, isTrue);
      expect(service.accentColor, AccentColor.teal);
      expect(service.layoutDensity, LayoutDensity.compact);
      expect(service.isCompact, isTrue);
    });

    test('AccentColor enum has expected values', () {
      expect(AccentColor.indigo.label, 'Indigo');
      expect(AccentColor.teal.label, 'Teal');
      expect(AccentColor.rose.label, 'Rose');
      expect(AccentColor.amber.label, 'Amber');
      expect(AccentColor.emerald.label, 'Emerald');
      expect(AccentColor.violet.label, 'Violet');
      expect(AccentColor.sky.label, 'Sky');
      expect(AccentColor.orange.label, 'Orange');
      for (final c in AccentColor.values) {
        expect(c.color, isNotNull);
      }
    });

    test('loadPreferences with invalid accent color falls back', () async {
      SharedPreferences.setMockInitialValues({
        'accent_color': 'nonexistent',
      });
      final service = ThemeService();
      await service.loadPreferences();
      expect(service.accentColor, AccentColor.indigo);
    });

    test('loadPreferences with invalid density falls back', () async {
      SharedPreferences.setMockInitialValues({
        'layout_density': 'nonexistent',
      });
      final service = ThemeService();
      await service.loadPreferences();
      expect(service.layoutDensity, LayoutDensity.comfortable);
    });
  });

  // ── Export Import Tests ──

  group('Export Import Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('exportAllJson produces valid JSON', () async {
      await taskService.addProject('Test Project', 'TP');
      await taskService.addTask('Task 1');
      await taskService.addRitual('Daily Ritual');

      final json = ExportImportService.exportAllJson(taskService);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['version'], 1);
      expect(data['exported_at'], isNotNull);
      expect(data['projects'], isA<List>());
      expect((data['projects'] as List).length, greaterThanOrEqualTo(1));
      expect(data['tasks'], isA<List>());
      expect((data['tasks'] as List).length, greaterThanOrEqualTo(1));
      expect(data['rituals'], isA<List>());
      expect((data['rituals'] as List).length, greaterThanOrEqualTo(1));
    });

    test('exportProjectJson exports single project', () async {
      final project = await taskService.addProject('Test Project', 'TP');
      await taskService.addTask('Task 1', projectId: project!.id);
      await taskService.addTask('Task 2', projectId: project.id);

      final json =
          ExportImportService.exportProjectJson(taskService, project.id);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect((data['projects'] as List).length, 1);
      expect((data['tasks'] as List).length, 2);
    });

    test('exportTasksCsv produces valid CSV', () async {
      await taskService.addTask('Test Task');

      final csv = ExportImportService.exportTasksCsv(taskService);
      final lines = csv.trim().split('\n');

      expect(lines.length, 2);
      expect(lines[0], contains('Key,Title,Status'));
      expect(lines[1], contains('Test Task'));
    });

    test('exportTasksCsv escapes commas in values', () async {
      await taskService.addTask('Task, with comma');

      final csv = ExportImportService.exportTasksCsv(taskService);
      expect(csv, contains('"Task, with comma"'));
    });

    test('importJson round-trips with exportAllJson', () async {
      await taskService.addProject('Test Project', 'TP');
      await taskService.addTask('Task 1');
      await taskService.addRitual('Ritual 1');

      final exported = ExportImportService.exportAllJson(taskService);

      await tearDownTestHive();
      await setUpTestHive();
      _registerAdapters();
      final freshService = TaskService();
      await freshService.init();

      final summary =
          await ExportImportService.importJson(freshService, exported);
      expect(summary.projects, greaterThanOrEqualTo(1));
      expect(summary.tasks, greaterThanOrEqualTo(1));
      expect(summary.rituals, greaterThanOrEqualTo(1));
      expect(freshService.projects.length, greaterThanOrEqualTo(1));
      expect(freshService.tasks.length, greaterThanOrEqualTo(1));
      expect(freshService.rituals.length, greaterThanOrEqualTo(1));
    });

    test('ImportSummary toString formats correctly', () {
      const summary = ImportSummary(projects: 2, tasks: 5, rituals: 3, tags: 1);
      expect(summary.toString(),
          'Imported 2 projects, 5 tasks, 3 rituals, 1 tags');
    });
  });

  // ── Export Import Extended Tests ──

  group('Export Import Extended Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('exportTasksCsv with specific projectId', () async {
      final project = await taskService.addProject('CSV Project', 'CSV');
      await taskService.addTask('In Project', projectId: project!.id);
      await taskService.addTask('No Project');

      final csv = ExportImportService.exportTasksCsv(taskService,
          projectId: project.id);
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[1], contains('In Project'));
    });

    test('exportTasksCsv escapes quotes in values', () async {
      await taskService.addTask('Task with "quotes"');

      final csv = ExportImportService.exportTasksCsv(taskService);
      expect(csv, contains('"Task with ""quotes"""'));
    });

    test('exportTasksCsv includes all task fields', () async {
      final project = await taskService.addProject('Full', 'FLL');
      final task = await taskService.addTask('Detailed',
          projectId: project!.id,
          description: 'A description',
          priority: TaskPriority.high,
          tags: ['alpha', 'beta'],
          dueDate: DateTime(2026, 6, 15));
      task!.estimatedMinutes = 60;
      task.trackedMinutes = 30;
      await taskService.updateTask(task);

      final csv = ExportImportService.exportTasksCsv(taskService);
      expect(csv, contains('high'));
      expect(csv, contains('2026-06-15'));
      expect(csv, contains('alpha; beta'));
      expect(csv, contains('60'));
      expect(csv, contains('30'));
    });

    test('importJson with tags round-trips', () async {
      final project = await taskService.addProject('Tag Export', 'TGE');
      await taskService.addTag('imported-tag', '#FF0000', project!.id);
      await taskService
          .addTask('Tagged', projectId: project.id, tags: ['imported-tag']);

      final exported = ExportImportService.exportAllJson(taskService);

      await tearDownTestHive();
      await setUpTestHive();
      _registerAdapters();
      final freshService = TaskService();
      await freshService.init();

      final summary =
          await ExportImportService.importJson(freshService, exported);
      expect(summary.tags, greaterThanOrEqualTo(1));
    });

    test('exportProjectJson includes project tags', () async {
      final project = await taskService.addProject('Export Tags', 'ET');
      await taskService.addTag('proj-tag', '#AABB00', project!.id);
      await taskService.addTask('Task in project', projectId: project.id);

      final json =
          ExportImportService.exportProjectJson(taskService, project.id);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['tags'], isNotNull);
      expect((data['tags'] as List).length, greaterThanOrEqualTo(1));
      expect(data['tasks'], isNotNull);
      expect((data['tasks'] as List).length, greaterThanOrEqualTo(1));
    });
  });
}
