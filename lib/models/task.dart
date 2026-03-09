import 'package:hive/hive.dart';
import '../common/validators.dart';

part 'task.g.dart';

/// Represents a task with title, description, status, and metadata.
@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  TaskStatus status;

  @HiveField(4)
  TaskPriority priority;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  DateTime? dueDate;

  @HiveField(7)
  String? projectId;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  String? taskKey;

  @HiveField(10)
  DateTime modifiedAt;

  @HiveField(11)
  List<String> dependsOn;

  /// Subtasks stored as encoded strings: "0:title" (incomplete) or "1:title" (complete).
  @HiveField(12)
  List<String> subtasks;

  /// Estimated minutes for time tracking.
  @HiveField(13)
  int? estimatedMinutes;

  /// Actual tracked minutes.
  @HiveField(14)
  int trackedMinutes;

  /// Recurrence rule: 'daily', 'weekly', 'monthly', or null for one-off tasks.
  @HiveField(15)
  String? recurrence;

  /// File attachment paths (local).
  @HiveField(16)
  List<String> attachments;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    this.dueDate,
    this.projectId,
    this.tags = const [],
    this.taskKey,
    DateTime? modifiedAt,
    this.dependsOn = const [],
    this.subtasks = const [],
    this.estimatedMinutes,
    this.trackedMinutes = 0,
    this.recurrence,
    this.attachments = const [],
  }) : modifiedAt = modifiedAt ?? createdAt {
    if (!isValidUuid(id)) {
      throw ArgumentError('Invalid task ID: must be a valid UUID');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Task title cannot be empty');
    }
    if (projectId != null && !isValidUuid(projectId!)) {
      throw ArgumentError('Invalid project ID: must be a valid UUID');
    }
  }

  // ── Subtask helpers ──

  List<({String title, bool done})> get parsedSubtasks {
    return subtasks.map((s) {
      final done = s.startsWith('1:');
      final title = s.length > 2 ? s.substring(2) : '';
      return (title: title, done: done);
    }).toList();
  }

  void addSubtask(String title) {
    subtasks = [...subtasks, '0:$title'];
  }

  void toggleSubtask(int index) {
    if (index < 0 || index >= subtasks.length) return;
    final s = subtasks[index];
    final done = s.startsWith('1:');
    final title = s.length > 2 ? s.substring(2) : '';
    subtasks = List.of(subtasks)..[index] = '${done ? '0' : '1'}:$title';
  }

  void removeSubtask(int index) {
    if (index < 0 || index >= subtasks.length) return;
    subtasks = List.of(subtasks)..removeAt(index);
  }

  int get subtasksDone => subtasks.where((s) => s.startsWith('1:')).length;

  // ── Time tracking helpers ──

  String get formattedTrackedTime {
    if (trackedMinutes == 0) return '0m';
    final h = trackedMinutes ~/ 60;
    final m = trackedMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? dueDate,
    String? projectId,
    List<String>? tags,
    String? taskKey,
    DateTime? modifiedAt,
    List<String>? dependsOn,
    List<String>? subtasks,
    int? estimatedMinutes,
    int? trackedMinutes,
    String? recurrence,
    List<String>? attachments,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      projectId: projectId ?? this.projectId,
      tags: tags ?? this.tags,
      taskKey: taskKey ?? this.taskKey,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      dependsOn: dependsOn ?? this.dependsOn,
      subtasks: subtasks ?? this.subtasks,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      trackedMinutes: trackedMinutes ?? this.trackedMinutes,
      recurrence: recurrence ?? this.recurrence,
      attachments: attachments ?? this.attachments,
    );
  }
}

@HiveType(typeId: 1)
enum TaskStatus {
  @HiveField(0)
  todo,
  @HiveField(1)
  inProgress,
  @HiveField(2)
  inReview,
  @HiveField(3)
  blocked,
  @HiveField(4)
  done,
}

@HiveType(typeId: 2)
enum TaskPriority {
  @HiveField(0)
  low,
  @HiveField(1)
  medium,
  @HiveField(2)
  high,
}
