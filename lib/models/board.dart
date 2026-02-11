import 'package:hive/hive.dart';

part 'board.g.dart';

/// Represents a Kanban board with columns.
@HiveType(typeId: 5)
class Board extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime createdAt;

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
  });

  Board copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    List<String>? columnIds,
    String? color,
  }) {
    return Board(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      columnIds: columnIds ?? this.columnIds,
      color: color ?? this.color,
    );
  }
}

/// Represents a column within a Kanban board.
@HiveType(typeId: 6)
class BoardColumn extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  List<String> taskIds;

  @HiveField(3)
  int order;

  BoardColumn({
    required this.id,
    required this.title,
    this.taskIds = const [],
    this.order = 0,
  });

  BoardColumn copyWith({
    String? id,
    String? title,
    List<String>? taskIds,
    int? order,
  }) {
    return BoardColumn(
      id: id ?? this.id,
      title: title ?? this.title,
      taskIds: taskIds ?? this.taskIds,
      order: order ?? this.order,
    );
  }
}
