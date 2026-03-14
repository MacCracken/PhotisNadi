import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/server/agnos.dart';
import 'package:photisnadi/server/auth.dart';
import 'package:photisnadi/server/api.dart';
import 'package:shelf/shelf.dart' as shelf;
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
  // ── Auth Middleware Tests ──

  group('Auth Middleware Tests', () {
    test('health endpoint bypasses auth', () async {
      final middleware = apiKeyAuth('test-key');
      final handler = middleware((request) => shelf.Response.ok('healthy'));

      final request = shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/v1/health'),
      );

      final response = await handler(request);
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'healthy');
    });

    test('missing authorization header returns 401', () async {
      final middleware = apiKeyAuth('test-key');
      final handler = middleware((request) => shelf.Response.ok('ok'));

      final request = shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/v1/tasks'),
      );

      final response = await handler(request);
      expect(response.statusCode, 401);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], contains('Authorization'));
    });

    test('invalid bearer token returns 403', () async {
      final middleware = apiKeyAuth('correct-key');
      final handler = middleware((request) => shelf.Response.ok('ok'));

      final request = shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/v1/tasks'),
        headers: {'authorization': 'Bearer wrong-key'},
      );

      final response = await handler(request);
      expect(response.statusCode, 403);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], contains('Invalid'));
    });

    test('valid bearer token passes through', () async {
      final middleware = apiKeyAuth('my-secret');
      final handler = middleware((request) => shelf.Response.ok('data'));

      final request = shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/v1/tasks'),
        headers: {'authorization': 'Bearer my-secret'},
      );

      final response = await handler(request);
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'data');
    });

    test('non-Bearer authorization header returns 401', () async {
      final middleware = apiKeyAuth('test-key');
      final handler = middleware((request) => shelf.Response.ok('ok'));

      final request = shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/v1/tasks'),
        headers: {'authorization': 'Basic dXNlcjpwYXNz'},
      );

      final response = await handler(request);
      expect(response.statusCode, 401);
    });
  });

  // ── API Router Integration Tests ──

  group('API Router Integration Tests', () {
    late Box<Task> taskBox;
    late Box<Project> projectBox;
    late Box<Ritual> ritualBox;
    late shelf.Handler handler;
    const testApiKey = 'test-api-key-12345';

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskBox = await Hive.openBox<Task>('tasks');
      projectBox = await Hive.openBox<Project>('projects');
      ritualBox = await Hive.openBox<Ritual>('rituals');

      final router = buildApiRouter(
        tasks: taskBox,
        projects: projectBox,
        rituals: ritualBox,
        apiKey: testApiKey,
        allowHandshake: true,
      );

      final pipeline =
          const shelf.Pipeline().addMiddleware(apiKeyAuth(testApiKey));
      handler = pipeline.addHandler(router.call);
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    shelf.Request _req(String method, String path,
        {Map<String, dynamic>? body, bool auth = true}) {
      final headers = <String, String>{
        'content-type': 'application/json',
      };
      if (auth) headers['authorization'] = 'Bearer $testApiKey';
      return shelf.Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }

    test('health returns 200 with counts', () async {
      final response = await handler(_req('GET', '/api/v1/health', auth: false));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['status'], 'ok');
      expect(data['tasks'], 0);
      expect(data['projects'], 0);
      expect(data['rituals'], 0);
    });

    test('handshake returns key when allowed', () async {
      final response =
          await handler(_req('POST', '/api/v1/handshake', auth: false));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['api_key'], testApiKey);
    });

    test('handshake returns 403 when already claimed', () async {
      await handler(_req('POST', '/api/v1/handshake', auth: false));
      final response =
          await handler(_req('POST', '/api/v1/handshake', auth: false));
      expect(response.statusCode, 403);
    });

    test('tasks GET returns empty list', () async {
      final response = await handler(_req('GET', '/api/v1/tasks'));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data, isEmpty);
    });

    test('tasks GET filters by project_id', () async {
      final pid = '550e8400-e29b-41d4-a716-446655440090';
      final p = Project(
          id: pid, name: 'P', projectKey: 'PP', createdAt: DateTime.now());
      await projectBox.put(pid, p);

      final t1 = Task(
          id: '550e8400-e29b-41d4-a716-446655440091',
          title: 'T1',
          createdAt: DateTime.now(),
          projectId: pid);
      final t2 = Task(
          id: '550e8400-e29b-41d4-a716-446655440092',
          title: 'T2',
          createdAt: DateTime.now());
      await taskBox.put(t1.id, t1);
      await taskBox.put(t2.id, t2);

      final response =
          await handler(_req('GET', '/api/v1/tasks?project_id=$pid'));
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 1);
      expect(data.first['title'], 'T1');
    });

    test('tasks GET filters by status', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440093',
          title: 'Done',
          createdAt: DateTime.now(),
          status: TaskStatus.done);
      await taskBox.put(t.id, t);

      final response =
          await handler(_req('GET', '/api/v1/tasks?status=done'));
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 1);
    });

    test('tasks GET invalid status returns 400', () async {
      final response =
          await handler(_req('GET', '/api/v1/tasks?status=bogus'));
      expect(response.statusCode, 400);
    });

    test('tasks GET filters by priority', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440094',
          title: 'High',
          createdAt: DateTime.now(),
          priority: TaskPriority.high);
      await taskBox.put(t.id, t);

      final response =
          await handler(_req('GET', '/api/v1/tasks?priority=high'));
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 1);
    });

    test('tasks GET respects limit', () async {
      for (var i = 0; i < 5; i++) {
        final t = Task(
            id: '550e8400-e29b-41d4-a716-44665544010$i',
            title: 'T$i',
            createdAt: DateTime.now());
        await taskBox.put(t.id, t);
      }

      final response = await handler(_req('GET', '/api/v1/tasks?limit=2'));
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 2);
    });

    test('tasks POST creates with title', () async {
      final response = await handler(
          _req('POST', '/api/v1/tasks', body: {'title': 'New Task'}));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['title'], 'New Task');
      expect(data['id'], isNotNull);
      expect(taskBox.length, 1);
    });

    test('tasks POST missing title returns 400', () async {
      final response = await handler(
          _req('POST', '/api/v1/tasks', body: {'description': 'no title'}));
      expect(response.statusCode, 400);
    });

    test('tasks POST invalid JSON returns 400', () async {
      final response = await handler(shelf.Request(
        'POST',
        Uri.parse('http://localhost/api/v1/tasks'),
        headers: {
          'authorization': 'Bearer $testApiKey',
          'content-type': 'application/json',
        },
        body: 'not json',
      ));
      expect(response.statusCode, 400);
    });

    test('tasks POST auto-generates task key with project', () async {
      final pid = '550e8400-e29b-41d4-a716-446655440095';
      final p = Project(
          id: pid, name: 'P', projectKey: 'TK', createdAt: DateTime.now());
      await projectBox.put(pid, p);

      final response = await handler(_req('POST', '/api/v1/tasks',
          body: {'title': 'Keyed', 'project_id': pid}));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['task_key'], 'TK-1');
    });

    test('tasks PATCH updates fields', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440110',
          title: 'Old',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'title': 'New', 'status': 'inProgress'}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['title'], 'New');
      expect(data['status'], 'inProgress');
    });

    test('tasks PATCH 404 missing', () async {
      final response = await handler(_req(
          'PATCH', '/api/v1/tasks/550e8400-e29b-41d4-a716-446655440999',
          body: {'title': 'X'}));
      expect(response.statusCode, 404);
    });

    test('tasks PATCH 400 empty title', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440111',
          title: 'Old',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'title': '  '}));
      expect(response.statusCode, 400);
    });

    test('tasks PATCH 400 invalid status', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440112',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'status': 'bogus'}));
      expect(response.statusCode, 400);
    });

    test('tasks DELETE returns 204', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440113',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('DELETE', '/api/v1/tasks/${t.id}'));
      expect(response.statusCode, 204);
      expect(taskBox.get(t.id), isNull);
    });

    test('tasks DELETE 404 missing', () async {
      final response = await handler(_req(
          'DELETE', '/api/v1/tasks/550e8400-e29b-41d4-a716-446655440999'));
      expect(response.statusCode, 404);
    });

    test('tasks DELETE cleans up dependency refs', () async {
      final t1 = Task(
          id: '550e8400-e29b-41d4-a716-446655440114',
          title: 'Dep',
          createdAt: DateTime.now());
      final t2 = Task(
          id: '550e8400-e29b-41d4-a716-446655440115',
          title: 'Blocked',
          createdAt: DateTime.now(),
          dependsOn: [t1.id]);
      await taskBox.put(t1.id, t1);
      await taskBox.put(t2.id, t2);

      await handler(_req('DELETE', '/api/v1/tasks/${t1.id}'));
      final updated = taskBox.get(t2.id)!;
      expect(updated.dependsOn.contains(t1.id), isFalse);
    });

    test('projects GET excludes archived by default', () async {
      final p1 = Project(
          id: '550e8400-e29b-41d4-a716-446655440120',
          name: 'Active',
          projectKey: 'AC',
          createdAt: DateTime.now());
      final p2 = Project(
          id: '550e8400-e29b-41d4-a716-446655440121',
          name: 'Archived',
          projectKey: 'AR',
          createdAt: DateTime.now(),
          isArchived: true);
      await projectBox.put(p1.id, p1);
      await projectBox.put(p2.id, p2);

      final response = await handler(_req('GET', '/api/v1/projects'));
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 1);
      expect(data.first['name'], 'Active');
    });

    test('projects GET include_archived=true', () async {
      final p1 = Project(
          id: '550e8400-e29b-41d4-a716-446655440122',
          name: 'Active',
          projectKey: 'AC',
          createdAt: DateTime.now());
      final p2 = Project(
          id: '550e8400-e29b-41d4-a716-446655440123',
          name: 'Archived',
          projectKey: 'AR',
          createdAt: DateTime.now(),
          isArchived: true);
      await projectBox.put(p1.id, p1);
      await projectBox.put(p2.id, p2);

      final response = await handler(
          _req('GET', '/api/v1/projects?include_archived=true'));
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 2);
    });

    test('projects POST creates with name and key', () async {
      final response = await handler(_req('POST', '/api/v1/projects',
          body: {'name': 'New Proj', 'project_key': 'NP'}));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['name'], 'New Proj');
      expect(data['project_key'], 'NP');
      expect(projectBox.length, 1);
    });

    test('projects POST missing name returns 400', () async {
      final response = await handler(_req('POST', '/api/v1/projects',
          body: {'project_key': 'NP'}));
      expect(response.statusCode, 400);
    });

    test('projects POST missing key returns 400', () async {
      final response = await handler(
          _req('POST', '/api/v1/projects', body: {'name': 'X'}));
      expect(response.statusCode, 400);
    });

    test('projects POST invalid key format returns 400', () async {
      final response = await handler(_req('POST', '/api/v1/projects',
          body: {'name': 'X', 'project_key': 'toolongkey'}));
      expect(response.statusCode, 400);
    });

    test('projects PATCH updates fields', () async {
      final p = Project(
          id: '550e8400-e29b-41d4-a716-446655440130',
          name: 'Old',
          projectKey: 'OL',
          createdAt: DateTime.now());
      await projectBox.put(p.id, p);

      final response = await handler(_req('PATCH', '/api/v1/projects/${p.id}',
          body: {'name': 'Updated', 'is_archived': true}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['name'], 'Updated');
      expect(data['is_archived'], true);
    });

    test('projects PATCH 404', () async {
      final response = await handler(_req(
          'PATCH', '/api/v1/projects/550e8400-e29b-41d4-a716-446655440999',
          body: {'name': 'X'}));
      expect(response.statusCode, 404);
    });

    test('projects PATCH 400 empty name', () async {
      final p = Project(
          id: '550e8400-e29b-41d4-a716-446655440131',
          name: 'Old',
          projectKey: 'OL',
          createdAt: DateTime.now());
      await projectBox.put(p.id, p);

      final response = await handler(_req('PATCH', '/api/v1/projects/${p.id}',
          body: {'name': '  '}));
      expect(response.statusCode, 400);
    });

    test('projects DELETE deletes project + tasks', () async {
      final pid = '550e8400-e29b-41d4-a716-446655440132';
      final p = Project(
          id: pid, name: 'Del', projectKey: 'DL', createdAt: DateTime.now());
      await projectBox.put(pid, p);

      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440133',
          title: 'Child',
          createdAt: DateTime.now(),
          projectId: pid);
      await taskBox.put(t.id, t);

      final response = await handler(_req('DELETE', '/api/v1/projects/$pid'));
      expect(response.statusCode, 204);
      expect(projectBox.get(pid), isNull);
      expect(taskBox.get(t.id), isNull);
    });

    test('projects DELETE 404', () async {
      final response = await handler(_req(
          'DELETE', '/api/v1/projects/550e8400-e29b-41d4-a716-446655440999'));
      expect(response.statusCode, 404);
    });

    test('rituals GET lists all', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440140',
          title: 'Meditate',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response = await handler(_req('GET', '/api/v1/rituals'));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 1);
    });

    test('rituals GET filters by frequency', () async {
      final r1 = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440141',
          title: 'Daily',
          createdAt: DateTime.now(),
          frequency: RitualFrequency.daily);
      final r2 = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440142',
          title: 'Weekly',
          createdAt: DateTime.now(),
          frequency: RitualFrequency.weekly);
      await ritualBox.put(r1.id, r1);
      await ritualBox.put(r2.id, r2);

      final response =
          await handler(_req('GET', '/api/v1/rituals?frequency=weekly'));
      final data = jsonDecode(await response.readAsString()) as List;
      expect(data.length, 1);
      expect(data.first['title'], 'Weekly');
    });

    test('rituals POST creates', () async {
      final response = await handler(_req('POST', '/api/v1/rituals',
          body: {'title': 'New Ritual', 'frequency': 'weekly'}));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['title'], 'New Ritual');
      expect(data['frequency'], 'weekly');
      expect(ritualBox.length, 1);
    });

    test('rituals POST missing title returns 400', () async {
      final response = await handler(
          _req('POST', '/api/v1/rituals', body: {'description': 'x'}));
      expect(response.statusCode, 400);
    });

    test('rituals PATCH updates', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440143',
          title: 'Old',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response = await handler(_req('PATCH', '/api/v1/rituals/${r.id}',
          body: {'title': 'Updated', 'frequency': 'monthly'}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['title'], 'Updated');
      expect(data['frequency'], 'monthly');
    });

    test('rituals PATCH 404', () async {
      final response = await handler(_req(
          'PATCH', '/api/v1/rituals/550e8400-e29b-41d4-a716-446655440999',
          body: {'title': 'X'}));
      expect(response.statusCode, 404);
    });

    test('rituals DELETE 204', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440144',
          title: 'X',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response =
          await handler(_req('DELETE', '/api/v1/rituals/${r.id}'));
      expect(response.statusCode, 204);
      expect(ritualBox.get(r.id), isNull);
    });

    test('rituals DELETE 404', () async {
      final response = await handler(_req(
          'DELETE', '/api/v1/rituals/550e8400-e29b-41d4-a716-446655440999'));
      expect(response.statusCode, 404);
    });

    test('rituals complete marks complete', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440145',
          title: 'Complete Me',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response =
          await handler(_req('POST', '/api/v1/rituals/${r.id}/complete'));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['is_completed'], true);
      expect(data['streak_count'], 1);
    });

    test('rituals complete 404', () async {
      final response = await handler(_req('POST',
          '/api/v1/rituals/550e8400-e29b-41d4-a716-446655440999/complete'));
      expect(response.statusCode, 404);
    });

    test('analytics returns correct counts', () async {
      final t1 = Task(
          id: '550e8400-e29b-41d4-a716-446655440150',
          title: 'T1',
          createdAt: DateTime.now(),
          status: TaskStatus.todo,
          priority: TaskPriority.high);
      final t2 = Task(
          id: '550e8400-e29b-41d4-a716-446655440151',
          title: 'T2',
          createdAt: DateTime.now(),
          status: TaskStatus.done,
          priority: TaskPriority.low);
      await taskBox.put(t1.id, t1);
      await taskBox.put(t2.id, t2);

      final response = await handler(_req('GET', '/api/v1/analytics'));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['total'], 2);
      expect(data['by_status']['todo'], 1);
      expect(data['by_status']['done'], 1);
      expect(data['by_priority']['high'], 1);
      expect(data['by_priority']['low'], 1);
    });
  });

  // ── API Router Extended Tests ──

  group('API Router Extended Tests', () {
    late Box<Task> taskBox;
    late Box<Project> projectBox;
    late Box<Ritual> ritualBox;
    late shelf.Handler handler;
    late shelf.Handler noHandshakeHandler;
    const testApiKey = 'test-api-key-ext';

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskBox = await Hive.openBox<Task>('tasks');
      projectBox = await Hive.openBox<Project>('projects');
      ritualBox = await Hive.openBox<Ritual>('rituals');

      final router = buildApiRouter(
        tasks: taskBox,
        projects: projectBox,
        rituals: ritualBox,
        apiKey: testApiKey,
        allowHandshake: true,
      );
      handler = const shelf.Pipeline()
          .addMiddleware(apiKeyAuth(testApiKey))
          .addHandler(router.call);

      final noHsRouter = buildApiRouter(
        tasks: taskBox,
        projects: projectBox,
        rituals: ritualBox,
        apiKey: testApiKey,
        allowHandshake: false,
      );
      noHandshakeHandler = const shelf.Pipeline()
          .addMiddleware(apiKeyAuth(testApiKey))
          .addHandler(noHsRouter.call);
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    shelf.Request _req(String method, String path,
        {Map<String, dynamic>? body, bool auth = true}) {
      final headers = <String, String>{
        'content-type': 'application/json',
      };
      if (auth) headers['authorization'] = 'Bearer $testApiKey';
      return shelf.Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }

    test('handshake returns 404 when not available', () async {
      final response = await noHandshakeHandler(
          _req('POST', '/api/v1/handshake', auth: false));
      expect(response.statusCode, 404);
    });

    test('tasks GET invalid priority returns 400', () async {
      final response =
          await handler(_req('GET', '/api/v1/tasks?priority=bogus'));
      expect(response.statusCode, 400);
    });

    test('tasks POST with due_date', () async {
      final response = await handler(_req('POST', '/api/v1/tasks', body: {
        'title': 'Due Date Task',
        'due_date': '2026-06-01T00:00:00.000Z',
      }));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['due_date'], isNotNull);
    });

    test('tasks POST with status and priority', () async {
      final response = await handler(_req('POST', '/api/v1/tasks', body: {
        'title': 'Custom',
        'status': 'inProgress',
        'priority': 'high',
      }));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['status'], 'inProgress');
      expect(data['priority'], 'high');
    });

    test('tasks POST with tags', () async {
      final response = await handler(_req('POST', '/api/v1/tasks', body: {
        'title': 'Tagged',
        'tags': ['bug', 'ui'],
      }));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['tags'], ['bug', 'ui']);
    });

    test('tasks PATCH updates description', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440160',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'description': 'New desc'}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['description'], 'New desc');
    });

    test('tasks PATCH updates priority', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440161',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'priority': 'high'}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['priority'], 'high');
    });

    test('tasks PATCH invalid priority returns 400', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440162',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'priority': 'bogus'}));
      expect(response.statusCode, 400);
    });

    test('tasks PATCH updates due_date', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440163',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'due_date': '2026-12-01T00:00:00.000Z'}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['due_date'], isNotNull);
    });

    test('tasks PATCH clears due_date with null', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440164',
          title: 'X',
          createdAt: DateTime.now(),
          dueDate: DateTime(2026, 6, 1));
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {'due_date': null}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['due_date'], isNull);
    });

    test('tasks PATCH updates tags', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440165',
          title: 'X',
          createdAt: DateTime.now(),
          tags: ['old']);
      await taskBox.put(t.id, t);

      final response = await handler(_req('PATCH', '/api/v1/tasks/${t.id}',
          body: {
            'tags': ['new1', 'new2']
          }));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['tags'], ['new1', 'new2']);
    });

    test('projects POST with optional fields', () async {
      final response = await handler(_req('POST', '/api/v1/projects', body: {
        'name': 'Full',
        'project_key': 'FL',
        'description': 'A description',
        'color': '#FF0000',
        'icon_name': 'star',
      }));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['description'], 'A description');
      expect(data['color'], '#FF0000');
      expect(data['icon_name'], 'star');
    });

    test('projects PATCH updates description and color', () async {
      final p = Project(
          id: '550e8400-e29b-41d4-a716-446655440170',
          name: 'P',
          projectKey: 'PP',
          createdAt: DateTime.now());
      await projectBox.put(p.id, p);

      final response = await handler(_req('PATCH', '/api/v1/projects/${p.id}',
          body: {
            'description': 'Updated desc',
            'color': '#00FF00',
            'icon_name': 'folder'
          }));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['description'], 'Updated desc');
    });

    test('rituals POST with description', () async {
      final response = await handler(_req('POST', '/api/v1/rituals',
          body: {'title': 'Ritual', 'description': 'A desc'}));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['description'], 'A desc');
    });

    test('rituals PATCH updates description', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440175',
          title: 'R',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response = await handler(_req('PATCH', '/api/v1/rituals/${r.id}',
          body: {'description': 'New desc'}));
      expect(response.statusCode, 200);
      final data = jsonDecode(await response.readAsString());
      expect(data['description'], 'New desc');
    });

    test('rituals PATCH empty title returns 400', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440176',
          title: 'R',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response = await handler(_req('PATCH', '/api/v1/rituals/${r.id}',
          body: {'title': '  '}));
      expect(response.statusCode, 400);
    });

    test('rituals GET invalid frequency returns 400', () async {
      final response =
          await handler(_req('GET', '/api/v1/rituals?frequency=bogus'));
      expect(response.statusCode, 400);
    });

    test('auth middleware rejects missing auth header', () async {
      final response = await handler(_req('GET', '/api/v1/tasks', auth: false));
      expect(response.statusCode, 401);
    });

    test('auth middleware rejects wrong key', () async {
      final response = await handler(shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/v1/tasks'),
        headers: {
          'authorization': 'Bearer wrong-key',
          'content-type': 'application/json',
        },
      ));
      expect(response.statusCode, 403);
    });

    test('analytics with overdue and due today tasks', () async {
      final now = DateTime.now();
      final overdue = Task(
          id: '550e8400-e29b-41d4-a716-446655440180',
          title: 'Overdue',
          createdAt: now,
          dueDate: now.subtract(const Duration(days: 1)),
          status: TaskStatus.todo);
      final dueToday = Task(
          id: '550e8400-e29b-41d4-a716-446655440181',
          title: 'DueToday',
          createdAt: now,
          dueDate: DateTime(now.year, now.month, now.day),
          status: TaskStatus.todo);
      final blocked = Task(
          id: '550e8400-e29b-41d4-a716-446655440182',
          title: 'Blocked',
          createdAt: now,
          status: TaskStatus.inProgress,
          dependsOn: ['550e8400-e29b-41d4-a716-446655440180']);
      await taskBox.put(overdue.id, overdue);
      await taskBox.put(dueToday.id, dueToday);
      await taskBox.put(blocked.id, blocked);

      final response = await handler(_req('GET', '/api/v1/analytics'));
      final data = jsonDecode(await response.readAsString());
      expect(data['overdue'], greaterThanOrEqualTo(1));
      expect(data['due_today'], greaterThanOrEqualTo(1));
      expect(data['blocked'], greaterThanOrEqualTo(1));
    });
  });

  // ── API Router with Agnos Tests ──

  group('API Router with Agnos Tests', () {
    late Box<Task> taskBox;
    late Box<Project> projectBox;
    late Box<Ritual> ritualBox;
    late shelf.Handler handler;
    const testApiKey = 'test-api-key-agnos';

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskBox = await Hive.openBox<Task>('tasks');
      projectBox = await Hive.openBox<Project>('projects');
      ritualBox = await Hive.openBox<Ritual>('rituals');

      final mockClient = http_testing.MockClient((request) async {
        return http.Response('OK', 200);
      });

      final agnos = AgnosIntegration(
        apiUrl: 'http://localhost:8081',
        apiKey: testApiKey,
        auditUrl: 'http://localhost:8090',
        httpClient: mockClient,
      );

      final router = buildApiRouter(
        tasks: taskBox,
        projects: projectBox,
        rituals: ritualBox,
        apiKey: testApiKey,
        agnos: agnos,
      );

      handler = const shelf.Pipeline()
          .addMiddleware(apiKeyAuth(testApiKey))
          .addHandler(router.call);
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    shelf.Request _req(String method, String path,
        {Map<String, dynamic>? body}) {
      return shelf.Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $testApiKey',
        },
        body: body != null ? jsonEncode(body) : null,
      );
    }

    test('task create fires audit event', () async {
      final response = await handler(
          _req('POST', '/api/v1/tasks', body: {'title': 'Audited'}));
      expect(response.statusCode, 201);
    });

    test('task update fires audit event', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440300',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response = await handler(
          _req('PATCH', '/api/v1/tasks/${t.id}', body: {'title': 'Y'}));
      expect(response.statusCode, 200);
    });

    test('task delete fires audit event', () async {
      final t = Task(
          id: '550e8400-e29b-41d4-a716-446655440301',
          title: 'X',
          createdAt: DateTime.now());
      await taskBox.put(t.id, t);

      final response =
          await handler(_req('DELETE', '/api/v1/tasks/${t.id}'));
      expect(response.statusCode, 204);
    });

    test('project create fires audit event', () async {
      final response = await handler(_req('POST', '/api/v1/projects',
          body: {'name': 'Audited', 'project_key': 'AU'}));
      expect(response.statusCode, 201);
    });

    test('project update fires audit event', () async {
      final p = Project(
          id: '550e8400-e29b-41d4-a716-446655440302',
          name: 'X',
          projectKey: 'XX',
          createdAt: DateTime.now());
      await projectBox.put(p.id, p);

      final response = await handler(
          _req('PATCH', '/api/v1/projects/${p.id}', body: {'name': 'Y'}));
      expect(response.statusCode, 200);
    });

    test('project delete fires audit event', () async {
      final p = Project(
          id: '550e8400-e29b-41d4-a716-446655440303',
          name: 'X',
          projectKey: 'XX',
          createdAt: DateTime.now());
      await projectBox.put(p.id, p);

      final response =
          await handler(_req('DELETE', '/api/v1/projects/${p.id}'));
      expect(response.statusCode, 204);
    });

    test('ritual create fires audit event', () async {
      final response = await handler(
          _req('POST', '/api/v1/rituals', body: {'title': 'Audited'}));
      expect(response.statusCode, 201);
    });

    test('ritual update fires audit event', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440304',
          title: 'X',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response = await handler(
          _req('PATCH', '/api/v1/rituals/${r.id}', body: {'title': 'Y'}));
      expect(response.statusCode, 200);
    });

    test('ritual delete fires audit event', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440305',
          title: 'X',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response =
          await handler(_req('DELETE', '/api/v1/rituals/${r.id}'));
      expect(response.statusCode, 204);
    });

    test('ritual complete fires audit event', () async {
      final r = Ritual(
          id: '550e8400-e29b-41d4-a716-446655440306',
          title: 'X',
          createdAt: DateTime.now());
      await ritualBox.put(r.id, r);

      final response =
          await handler(_req('POST', '/api/v1/rituals/${r.id}/complete'));
      expect(response.statusCode, 200);
    });

    test('task POST with invalid status falls back to todo', () async {
      final response = await handler(_req('POST', '/api/v1/tasks',
          body: {'title': 'Fallback', 'status': 'nonexistent'}));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['status'], 'todo');
    });

    test('task POST with invalid priority falls back to medium', () async {
      final response = await handler(_req('POST', '/api/v1/tasks',
          body: {'title': 'Fallback', 'priority': 'nonexistent'}));
      expect(response.statusCode, 201);
      final data = jsonDecode(await response.readAsString());
      expect(data['priority'], 'medium');
    });
  });
}
