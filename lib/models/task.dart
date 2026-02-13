import 'package:hive/hive.dart';

part 'task.g.dart';

/// Represents a task with title, description, status, and metadata.
@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  TaskStatus status;

  @HiveField(4)
  TaskPriority priority;

  @HiveField(5)
  DateTime createdAt;

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
  }) : modifiedAt = modifiedAt ?? createdAt;

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
