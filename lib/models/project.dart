import 'package:hive/hive.dart';
import '../common/validators.dart';
import 'board.dart';
import 'task.dart';

part 'project.g.dart';

/// Represents a project containing tasks with key-based numbering.
@HiveType(typeId: 7)
class Project extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String projectKey;

  @HiveField(3)
  String? description;

  @HiveField(4)
  final DateTime createdAt;

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

  /// User IDs this project is shared with (for team collaboration).
  @HiveField(11)
  List<String> sharedWith;

  /// Owner user ID.
  @HiveField(12)
  String? ownerId;

  /// Multiple boards per project.
  @HiveField(13)
  List<Board> boards;

  /// Currently active board ID.
  @HiveField(14)
  String? activeBoardId;

  /// Get the active board, or the first board if none selected.
  Board? get activeBoard {
    if (boards.isEmpty) return null;
    if (activeBoardId != null) {
      try {
        return boards.firstWhere((b) => b.id == activeBoardId);
      } catch (_) {}
    }
    return boards.first;
  }

  /// Get columns from the active board, falling back to project columns.
  List<BoardColumn> get activeColumns {
    final board = activeBoard;
    if (board != null && board.columns.isNotEmpty) return board.columns;
    return columns;
  }

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
    this.sharedWith = const [],
    this.ownerId,
    List<Board>? boards,
    this.activeBoardId,
  })  : modifiedAt = modifiedAt ?? createdAt,
        columns = columns ?? defaultColumns(),
        boards = boards ?? [] {
    if (!isValidUuid(id)) {
      throw ArgumentError('Invalid project ID: must be a valid UUID');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Project name cannot be empty');
    }
    final normalizedKey = projectKey.toUpperCase().trim();
    if (!isValidProjectKey(normalizedKey)) {
      throw ArgumentError(
          'Invalid project key: must be 2-5 uppercase alphanumeric characters');
    }
    projectKey = normalizedKey;
    color = isValidHexColor(color) ? normalizeHexColor(color) : '#4A90E2';

    // Migration: if no boards exist, create one from existing columns
    if (this.boards.isEmpty && this.columns.isNotEmpty) {
      final defaultBoard = Board(
        id: '${id}_default',
        title: 'Default',
        createdAt: createdAt,
        columns: List.from(this.columns),
      );
      this.boards = [defaultBoard];
      activeBoardId = defaultBoard.id;
    }
  }

  String generateNextTaskKey() {
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
    List<String>? sharedWith,
    String? ownerId,
    List<Board>? boards,
    String? activeBoardId,
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
      sharedWith: sharedWith ?? this.sharedWith,
      ownerId: ownerId ?? this.ownerId,
      boards: boards ?? this.boards,
      activeBoardId: activeBoardId ?? this.activeBoardId,
    );
  }
}
