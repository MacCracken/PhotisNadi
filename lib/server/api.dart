import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/ritual.dart';
import 'agnos.dart';
import 'serializers.dart';

const _json = {'content-type': 'application/json'};
const _uuid = Uuid();

/// Build the v1 API router backed by Hive boxes.
Router buildApiRouter({
  required Box<Task> tasks,
  required Box<Project> projects,
  required Box<Ritual> rituals,
  AgnosIntegration? agnos,
  required String apiKey,
  bool allowHandshake = false,
}) {
  final router = Router();
  bool handshakeClaimed = false;

  // ── Health ──

  router.get('/api/v1/health', (Request _) {
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'tasks': tasks.length,
        'projects': projects.length,
        'rituals': rituals.length,
      }),
      headers: _json,
    );
  });

  // ── Handshake ──

  router.post('/api/v1/handshake', (Request request) async {
    if (!allowHandshake) {
      return Response(404,
          body: jsonEncode({
            'error': 'Handshake not available — '
                'API key was pre-configured via PHOTISNADI_API_KEY'
          }),
          headers: _json);
    }

    // Atomic claim: test-and-set to prevent race condition
    if (handshakeClaimed) {
      return Response(403,
          body: jsonEncode({'error': 'Handshake already claimed'}),
          headers: _json);
    }
    handshakeClaimed = true;

    return Response.ok(
      jsonEncode({
        'api_key': apiKey,
        'message': 'API key granted. Use Authorization: Bearer <key> '
            'for subsequent requests.',
      }),
      headers: _json,
    );
  });

  // ── Tasks ──

  router.get('/api/v1/tasks', (Request request) {
    var items = tasks.values.toList();

    final projectId = request.url.queryParameters['project_id'];
    if (projectId != null) {
      items = items.where((t) => t.projectId == projectId).toList();
    }

    final status = request.url.queryParameters['status'];
    if (status != null) {
      final parsed = TaskStatus.values.where((s) => s.name == status);
      if (parsed.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid status value'}),
            headers: _json);
      }
      items = items.where((t) => t.status == parsed.first).toList();
    }

    final priority = request.url.queryParameters['priority'];
    if (priority != null) {
      final parsed = TaskPriority.values.where((p) => p.name == priority);
      if (parsed.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid priority value'}),
            headers: _json);
      }
      items = items.where((t) => t.priority == parsed.first).toList();
    }

    final limitStr = request.url.queryParameters['limit'];
    final limit =
        (limitStr != null ? int.tryParse(limitStr) ?? 50 : 50).clamp(0, 1000);

    // Sort by modifiedAt descending
    items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    if (items.length > limit) items = items.sublist(0, limit);

    return Response.ok(jsonEncode(items.map(taskToJson).toList()),
        headers: _json);
  });

  router.post('/api/v1/tasks', (Request request) async {
    final body = await _parseBody(request);
    if (body == null) return _badJson();

    final title = body['title'] as String?;
    if (title == null || title.trim().isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'title is required'}), headers: _json);
    }

    final now = DateTime.now();
    final id = _uuid.v4();
    final projectId = body['project_id'] as String?;

    // Auto-generate task key if project exists
    String? taskKey;
    if (projectId != null) {
      final project = projects.get(projectId);
      if (project != null) {
        taskKey = project.generateNextTaskKey();
        await projects.put(projectId, project);
      }
    }

    final statusStr = body['status'] as String? ?? 'todo';
    final priorityStr = body['priority'] as String? ?? 'medium';
    final taskStatus = TaskStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => TaskStatus.todo,
    );
    final taskPriority = TaskPriority.values.firstWhere(
      (p) => p.name == priorityStr,
      orElse: () => TaskPriority.medium,
    );

    DateTime? dueDate;
    if (body['due_date'] != null) {
      dueDate = DateTime.tryParse(body['due_date'] as String);
    }

    final task = Task(
      id: id,
      title: title,
      description: body['description'] as String?,
      status: taskStatus,
      priority: taskPriority,
      createdAt: now,
      modifiedAt: now,
      dueDate: dueDate,
      projectId: projectId,
      tags: (body['tags'] as List<dynamic>?)
              ?.whereType<String>()
              .where((t) => t.isNotEmpty)
              .toList() ??
          [],
      taskKey: taskKey,
    );

    await tasks.put(id, task);

    agnos?.forwardAuditEvent(
      action: 'create',
      entityType: 'task',
      entityId: id,
      payload: {'title': task.title, 'project_id': projectId},
    );

    return Response(201, body: jsonEncode(taskToJson(task)), headers: _json);
  });

  router.patch('/api/v1/tasks/<id>', (Request request, String id) async {
    final task = tasks.get(id);
    if (task == null) {
      return Response(404,
          body: jsonEncode({'error': 'Task not found'}), headers: _json);
    }

    final body = await _parseBody(request);
    if (body == null) return _badJson();

    if (body.containsKey('title')) {
      final title = body['title'] as String?;
      if (title == null || title.trim().isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'title cannot be empty'}),
            headers: _json);
      }
      task.title = title;
    }
    if (body.containsKey('description')) {
      task.description = body['description'] as String?;
    }
    if (body.containsKey('status')) {
      final s = TaskStatus.values.where((v) => v.name == body['status']);
      if (s.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid status'}), headers: _json);
      }
      task.status = s.first;
    }
    if (body.containsKey('priority')) {
      final p = TaskPriority.values.where((v) => v.name == body['priority']);
      if (p.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid priority'}), headers: _json);
      }
      task.priority = p.first;
    }
    if (body.containsKey('due_date')) {
      task.dueDate = body['due_date'] != null
          ? DateTime.tryParse(body['due_date'] as String)
          : null;
    }
    if (body.containsKey('tags')) {
      task.tags = (body['tags'] as List<dynamic>?)
              ?.whereType<String>()
              .where((t) => t.isNotEmpty)
              .toList() ??
          [];
    }

    task.modifiedAt = DateTime.now();
    await tasks.put(id, task);

    agnos?.forwardAuditEvent(
      action: 'update',
      entityType: 'task',
      entityId: id,
      payload: body,
    );

    return Response.ok(jsonEncode(taskToJson(task)), headers: _json);
  });

  router.delete('/api/v1/tasks/<id>', (Request request, String id) async {
    final task = tasks.get(id);
    if (task == null) {
      return Response(404,
          body: jsonEncode({'error': 'Task not found'}), headers: _json);
    }

    // Clean up dependency references in other tasks
    for (final other in tasks.values) {
      if (other.dependsOn.contains(id)) {
        other.dependsOn = other.dependsOn.where((d) => d != id).toList();
        await tasks.put(other.id, other);
      }
    }

    await tasks.delete(id);

    agnos?.forwardAuditEvent(
      action: 'delete',
      entityType: 'task',
      entityId: id,
    );

    return Response(204);
  });

  // ── Projects ──

  router.get('/api/v1/projects', (Request request) {
    var items = projects.values.toList();

    final includeArchived =
        request.url.queryParameters['include_archived'] == 'true';
    if (!includeArchived) {
      items = items.where((p) => !p.isArchived).toList();
    }

    items.sort((a, b) => a.name.compareTo(b.name));
    return Response.ok(jsonEncode(items.map(projectToJson).toList()),
        headers: _json);
  });

  router.post('/api/v1/projects', (Request request) async {
    final body = await _parseBody(request);
    if (body == null) return _badJson();

    final name = body['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'name is required'}), headers: _json);
    }

    final projectKey = body['project_key'] as String?;
    if (projectKey == null || projectKey.trim().isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'project_key is required'}),
          headers: _json);
    }

    final normalizedKey = projectKey.toUpperCase().trim();
    final keyRegex = RegExp(r'^[A-Z0-9]{2,5}$');
    if (!keyRegex.hasMatch(normalizedKey)) {
      return Response(400,
          body: jsonEncode({
            'error': 'project_key must be 2-5 uppercase alphanumeric characters'
          }),
          headers: _json);
    }

    final now = DateTime.now();
    final id = _uuid.v4();

    final project = Project(
      id: id,
      name: name,
      projectKey: normalizedKey,
      description: body['description'] as String?,
      createdAt: now,
      color: body['color'] as String? ?? '#4A90E2',
      iconName: body['icon_name'] as String?,
    );

    await projects.put(id, project);

    agnos?.forwardAuditEvent(
      action: 'create',
      entityType: 'project',
      entityId: id,
      payload: {'name': name, 'project_key': normalizedKey},
    );

    return Response(201,
        body: jsonEncode(projectToJson(project)), headers: _json);
  });

  router.patch('/api/v1/projects/<id>', (Request request, String id) async {
    final project = projects.get(id);
    if (project == null) {
      return Response(404,
          body: jsonEncode({'error': 'Project not found'}), headers: _json);
    }

    final body = await _parseBody(request);
    if (body == null) return _badJson();

    if (body.containsKey('name')) {
      final name = body['name'] as String?;
      if (name == null || name.trim().isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'name cannot be empty'}),
            headers: _json);
      }
      project.name = name;
    }
    if (body.containsKey('description')) {
      project.description = body['description'] as String?;
    }
    if (body.containsKey('color')) {
      project.color = body['color'] as String? ?? project.color;
    }
    if (body.containsKey('icon_name')) {
      project.iconName = body['icon_name'] as String?;
    }
    if (body.containsKey('is_archived')) {
      project.isArchived = body['is_archived'] as bool? ?? false;
    }

    project.modifiedAt = DateTime.now();
    await projects.put(id, project);

    agnos?.forwardAuditEvent(
      action: 'update',
      entityType: 'project',
      entityId: id,
      payload: body,
    );

    return Response.ok(jsonEncode(projectToJson(project)), headers: _json);
  });

  router.delete('/api/v1/projects/<id>', (Request request, String id) async {
    final project = projects.get(id);
    if (project == null) {
      return Response(404,
          body: jsonEncode({'error': 'Project not found'}), headers: _json);
    }

    // Delete all tasks belonging to this project
    final projectTasks = tasks.values.where((t) => t.projectId == id).toList();
    for (final task in projectTasks) {
      await tasks.delete(task.id);
    }

    await projects.delete(id);

    agnos?.forwardAuditEvent(
      action: 'delete',
      entityType: 'project',
      entityId: id,
    );

    return Response(204);
  });

  // ── Rituals ──

  router.get('/api/v1/rituals', (Request request) async {
    var items = rituals.values.toList();

    // Reset rituals that need it
    for (final ritual in items) {
      await ritual.resetIfNeeded();
    }

    final frequency = request.url.queryParameters['frequency'];
    if (frequency != null) {
      final parsed = RitualFrequency.values.where((f) => f.name == frequency);
      if (parsed.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid frequency value'}),
            headers: _json);
      }
      items = items.where((r) => r.frequency == parsed.first).toList();
    }

    items.sort((a, b) => a.title.compareTo(b.title));
    return Response.ok(jsonEncode(items.map(ritualToJson).toList()),
        headers: _json);
  });

  router.post('/api/v1/rituals', (Request request) async {
    final body = await _parseBody(request);
    if (body == null) return _badJson();

    final title = body['title'] as String?;
    if (title == null || title.trim().isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'title is required'}), headers: _json);
    }

    final id = _uuid.v4();
    final frequencyStr = body['frequency'] as String? ?? 'daily';
    final frequency = RitualFrequency.values.firstWhere(
      (f) => f.name == frequencyStr,
      orElse: () => RitualFrequency.daily,
    );

    final ritual = Ritual(
      id: id,
      title: title,
      description: body['description'] as String?,
      createdAt: DateTime.now(),
      frequency: frequency,
    );

    await rituals.put(id, ritual);

    agnos?.forwardAuditEvent(
      action: 'create',
      entityType: 'ritual',
      entityId: id,
      payload: {'title': title},
    );

    return Response(201,
        body: jsonEncode(ritualToJson(ritual)), headers: _json);
  });

  router.patch('/api/v1/rituals/<id>', (Request request, String id) async {
    final ritual = rituals.get(id);
    if (ritual == null) {
      return Response(404,
          body: jsonEncode({'error': 'Ritual not found'}), headers: _json);
    }

    final body = await _parseBody(request);
    if (body == null) return _badJson();

    if (body.containsKey('title')) {
      final title = body['title'] as String?;
      if (title == null || title.trim().isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'title cannot be empty'}),
            headers: _json);
      }
      ritual.title = title;
    }
    if (body.containsKey('description')) {
      ritual.description = body['description'] as String?;
    }
    if (body.containsKey('frequency')) {
      final f =
          RitualFrequency.values.where((v) => v.name == body['frequency']);
      if (f.isNotEmpty) ritual.frequency = f.first;
    }

    await rituals.put(id, ritual);

    agnos?.forwardAuditEvent(
      action: 'update',
      entityType: 'ritual',
      entityId: id,
      payload: body,
    );

    return Response.ok(jsonEncode(ritualToJson(ritual)), headers: _json);
  });

  router.delete('/api/v1/rituals/<id>', (Request request, String id) async {
    final ritual = rituals.get(id);
    if (ritual == null) {
      return Response(404,
          body: jsonEncode({'error': 'Ritual not found'}), headers: _json);
    }

    await rituals.delete(id);

    agnos?.forwardAuditEvent(
      action: 'delete',
      entityType: 'ritual',
      entityId: id,
    );

    return Response(204);
  });

  router.post('/api/v1/rituals/<id>/complete',
      (Request request, String id) async {
    final ritual = rituals.get(id);
    if (ritual == null) {
      return Response(404,
          body: jsonEncode({'error': 'Ritual not found'}), headers: _json);
    }

    ritual.isCompleted = true;
    ritual.lastCompleted = DateTime.now();
    ritual.streakCount++;
    await rituals.put(id, ritual);

    agnos?.forwardAuditEvent(
      action: 'complete',
      entityType: 'ritual',
      entityId: id,
    );

    return Response.ok(jsonEncode(ritualToJson(ritual)), headers: _json);
  });

  // ── Analytics ──

  router.get('/api/v1/analytics', (Request _) {
    final allTasks = tasks.values.toList();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final byStatus = <String, int>{};
    final byPriority = <String, int>{};
    int overdue = 0;
    int dueToday = 0;
    int blocked = 0;
    int completedThisWeek = 0;

    for (final task in allTasks) {
      byStatus[task.status.name] = (byStatus[task.status.name] ?? 0) + 1;
      byPriority[task.priority.name] =
          (byPriority[task.priority.name] ?? 0) + 1;

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

      if (task.status == TaskStatus.done && task.modifiedAt.isAfter(weekAgo)) {
        completedThisWeek++;
      }
    }

    return Response.ok(
      jsonEncode({
        'total': allTasks.length,
        'by_status': byStatus,
        'by_priority': byPriority,
        'overdue': overdue,
        'due_today': dueToday,
        'blocked': blocked,
        'completed_this_week': completedThisWeek,
      }),
      headers: _json,
    );
  });

  return router;
}

/// Parse JSON body, returning null on failure.
Future<Map<String, dynamic>?> _parseBody(Request request) async {
  try {
    final raw = await request.readAsString();
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Response _badJson() => Response(400,
    body: jsonEncode({'error': 'Invalid JSON body'}), headers: _json);
