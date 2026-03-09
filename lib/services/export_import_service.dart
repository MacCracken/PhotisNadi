import 'dart:convert';
import 'dart:developer' as developer;
import 'sync_service.dart';
import 'task_service.dart';

class ImportSummary {
  final int projects;
  final int tasks;
  final int rituals;
  final int tags;

  const ImportSummary({
    this.projects = 0,
    this.tasks = 0,
    this.rituals = 0,
    this.tags = 0,
  });

  @override
  String toString() =>
      'Imported $projects projects, $tasks tasks, $rituals rituals, $tags tags';
}

/// Handles JSON and CSV export/import of app data.
class ExportImportService {
  ExportImportService._();

  // ── JSON Export ──

  /// Export all data as JSON string.
  static String exportAllJson(TaskService service) {
    try {
      final data = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'projects': service.projects.map((p) => p.toSyncMap('')).toList(),
        'tasks': service.tasks.map((t) => t.toSyncMap('')).toList(),
        'rituals': service.rituals.map((r) => r.toSyncMap('')).toList(),
        'tags': service.tags.map((t) => t.toSyncMap('')).toList(),
      };
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e, stackTrace) {
      developer.log('Failed to export all JSON',
          name: 'ExportImport', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Export a single project with its tasks and tags as JSON.
  static String exportProjectJson(TaskService service, String projectId) {
    try {
      final project = service.projects.firstWhere((p) => p.id == projectId);
      final tasks = service.getTasksForProject(projectId);
      final tags = service.getTagsForProject(projectId);

      final data = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'projects': [project.toSyncMap('')],
        'tasks': tasks.map((t) => t.toSyncMap('')).toList(),
        'tags': tags.map((t) => t.toSyncMap('')).toList(),
      };
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e, stackTrace) {
      developer.log('Failed to export project JSON',
          name: 'ExportImport', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ── CSV Export ──

  /// Export tasks as CSV string. If projectId is null, exports all tasks.
  static String exportTasksCsv(TaskService service, {String? projectId}) {
    try {
      final tasks = projectId != null
          ? service.getTasksForProject(projectId)
          : service.tasks;

      final projectMap = {for (var p in service.projects) p.id: p};
      final buffer = StringBuffer();

      // Header
      buffer.writeln(
        'Key,Title,Status,Priority,Due Date,Tags,Description,Estimated Minutes,Tracked Minutes,Created,Project',
      );

      for (final task in tasks) {
        final projectName = task.projectId != null
            ? projectMap[task.projectId]?.name ?? ''
            : '';
        buffer.writeln([
          _csvEscape(task.taskKey ?? ''),
          _csvEscape(task.title),
          task.status.toString().split('.').last,
          task.priority.toString().split('.').last,
          task.dueDate?.toIso8601String().split('T').first ?? '',
          _csvEscape(task.tags.join('; ')),
          _csvEscape(task.description ?? ''),
          task.estimatedMinutes?.toString() ?? '',
          task.trackedMinutes.toString(),
          task.createdAt.toIso8601String().split('T').first,
          _csvEscape(projectName),
        ].join(','));
      }

      return buffer.toString();
    } catch (e, stackTrace) {
      developer.log('Failed to export CSV',
          name: 'ExportImport', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── JSON Import ──

  /// Import data from a JSON string. Returns a summary of what was imported.
  static Future<ImportSummary> importJson(
    TaskService service,
    String jsonString,
  ) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      int projects = 0, tasks = 0, rituals = 0, tags = 0;

      // Import projects first
      if (data['projects'] != null) {
        for (final map in data['projects'] as List) {
          final project = ProjectParsing.fromMap(map as Map<String, dynamic>);
          await service.addProject(
            project.name,
            project.projectKey,
            description: project.description,
            color: project.color,
            iconName: project.iconName,
          );
          projects++;
        }
      }

      // Import tags
      if (data['tags'] != null) {
        for (final map in data['tags'] as List) {
          final tag = TagParsing.fromMap(map as Map<String, dynamic>);
          await service.addTag(tag.name, tag.color, tag.projectId);
          tags++;
        }
      }

      // Import tasks
      if (data['tasks'] != null) {
        for (final map in data['tasks'] as List) {
          final task = TaskParsing.fromMap(map as Map<String, dynamic>);
          await service.addTask(
            task.title,
            description: task.description,
            priority: task.priority,
            projectId: task.projectId,
            tags: task.tags,
            dueDate: task.dueDate,
          );
          tasks++;
        }
      }

      // Import rituals
      if (data['rituals'] != null) {
        for (final map in data['rituals'] as List) {
          final ritual = RitualParsing.fromMap(map as Map<String, dynamic>);
          await service.addRitual(ritual.title,
              description: ritual.description);
          rituals++;
        }
      }

      return ImportSummary(
        projects: projects,
        tasks: tasks,
        rituals: rituals,
        tags: tags,
      );
    } catch (e, stackTrace) {
      developer.log('Failed to import JSON',
          name: 'ExportImport', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
