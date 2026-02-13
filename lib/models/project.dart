import 'package:hive/hive.dart';
import 'board.dart';
import 'task.dart';

part 'project.g.dart';

/// Represents a project containing tasks with key-based numbering.
@HiveType(typeId: 7)
class Project extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String projectKey;

  @HiveField(3)
  String? description;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  String color;

  @HiveField(6)
  String? iconName;

  @HiveField(7)
  int taskCounter;

  @HiveField(8)
  bool isArchived;

  @HiveField(9)
  DateTime modifiedAt;

  @HiveField(10)
  List<BoardColumn> columns;

  static List<BoardColumn> defaultColumns() {
    return [
      BoardColumn(
          id: 'todo', title: 'To Do', order: 0, status: TaskStatus.todo),
      BoardColumn(
          id: 'in_progress',
          title: 'In Progress',
          order: 1,
          status: TaskStatus.inProgress),
      BoardColumn(
          id: 'in_review',
          title: 'In Review',
          order: 2,
          status: TaskStatus.inReview),
      BoardColumn(
          id: 'blocked',
          title: 'Blocked',
          order: 3,
          status: TaskStatus.blocked),
      BoardColumn(id: 'done', title: 'Done', order: 4, status: TaskStatus.done),
    ];
  }

  Project({
    required this.id,
    required this.name,
    required this.projectKey,
    this.description,
    required this.createdAt,
    this.color = '#4A90E2',
    this.iconName,
    this.taskCounter = 0,
    this.isArchived = false,
    DateTime? modifiedAt,
    List<BoardColumn>? columns,
  })  : modifiedAt = modifiedAt ?? createdAt,
        columns = columns ?? defaultColumns();

  String get nextTaskKey {
    taskCounter++;
    return '$projectKey-$taskCounter';
  }

  Project copyWith({
    String? id,
    String? name,
    String? projectKey,
    String? description,
    DateTime? createdAt,
    String? color,
    String? iconName,
    int? taskCounter,
    bool? isArchived,
    DateTime? modifiedAt,
    List<BoardColumn>? columns,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      projectKey: projectKey ?? this.projectKey,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      taskCounter: taskCounter ?? this.taskCounter,
      isArchived: isArchived ?? this.isArchived,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      columns: columns ?? this.columns,
    );
  }
}
