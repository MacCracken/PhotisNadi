import 'package:hive/hive.dart';
import '../common/utils.dart';
import 'task.dart';

part 'board.g.dart';

/// Represents a Kanban board with columns.
@HiveType(typeId: 5)
class Board extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  List<String> columnIds;

  @HiveField(5)
  String color;

  Board({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.columnIds = const [],
    this.color = '#4A90E2',
    this.columns = const [],
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Board ID cannot be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Board title cannot be empty');
    }
    color = isValidHexColor(color) ? normalizeHexColor(color) : '#4A90E2';
  }

  @HiveField(6)
  List<BoardColumn> columns;

  Board copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    List<String>? columnIds,
    String? color,
    List<BoardColumn>? columns,
  }) {
    return Board(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      columnIds: columnIds ?? this.columnIds,
      color: color ?? this.color,
      columns: columns ?? this.columns,
    );
  }

  // ── Board Templates ──

  static Board defaultBoard(String id) => Board(
        id: id,
        title: 'Default',
        createdAt: DateTime.now(),
        columns: [
          BoardColumn(id: 'todo', title: 'To Do', order: 0, status: TaskStatus.todo),
          BoardColumn(id: 'in_progress', title: 'In Progress', order: 1, status: TaskStatus.inProgress),
          BoardColumn(id: 'in_review', title: 'In Review', order: 2, status: TaskStatus.inReview),
          BoardColumn(id: 'blocked', title: 'Blocked', order: 3, status: TaskStatus.blocked),
          BoardColumn(id: 'done', title: 'Done', order: 4, status: TaskStatus.done),
        ],
      );

  static Board bugTrackingBoard(String id) => Board(
        id: id,
        title: 'Bug Tracking',
        createdAt: DateTime.now(),
        color: '#EF4444',
        columns: [
          BoardColumn(id: '${id}_new', title: 'New', order: 0, status: TaskStatus.todo),
          BoardColumn(id: '${id}_triaged', title: 'Triaged', order: 1, status: TaskStatus.inReview),
          BoardColumn(id: '${id}_fixing', title: 'Fixing', order: 2, status: TaskStatus.inProgress),
          BoardColumn(id: '${id}_testing', title: 'Testing', order: 3, status: TaskStatus.blocked),
          BoardColumn(id: '${id}_closed', title: 'Closed', order: 4, status: TaskStatus.done),
        ],
      );

  static Board sprintBoard(String id) => Board(
        id: id,
        title: 'Sprint',
        createdAt: DateTime.now(),
        color: '#8B5CF6',
        columns: [
          BoardColumn(id: '${id}_backlog', title: 'Backlog', order: 0, status: TaskStatus.todo),
          BoardColumn(id: '${id}_sprint', title: 'Sprint', order: 1, status: TaskStatus.inReview),
          BoardColumn(id: '${id}_progress', title: 'In Progress', order: 2, status: TaskStatus.inProgress),
          BoardColumn(id: '${id}_review', title: 'Review', order: 3, status: TaskStatus.blocked),
          BoardColumn(id: '${id}_done', title: 'Done', order: 4, status: TaskStatus.done),
        ],
      );
}

/// Represents a column within a Kanban board.
@HiveType(typeId: 6)
class BoardColumn extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  List<String> taskIds;

  @HiveField(3)
  int order;

  @HiveField(4)
  String color;

  @HiveField(5)
  TaskStatus status;

  BoardColumn({
    required this.id,
    required this.title,
    this.taskIds = const [],
    this.order = 0,
    this.color = '#6B7280',
    required this.status,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('Column title cannot be empty');
    }
    color = isValidHexColor(color) ? normalizeHexColor(color) : '#6B7280';
  }

  BoardColumn copyWith({
    String? id,
    String? title,
    List<String>? taskIds,
    int? order,
    String? color,
    TaskStatus? status,
  }) {
    return BoardColumn(
      id: id ?? this.id,
      title: title ?? this.title,
      taskIds: taskIds ?? this.taskIds,
      order: order ?? this.order,
      color: color ?? this.color,
      status: status ?? this.status,
    );
  }
}
