import 'package:hive/hive.dart';

part 'project.g.dart';

/// Represents a project containing tasks with key-based numbering.
@HiveType(typeId: 7)
class Project extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String key;
  
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

  Project({
    required this.id,
    required this.name,
    required this.key,
    this.description,
    required this.createdAt,
    this.color = '#4A90E2',
    this.iconName,
    this.taskCounter = 0,
    this.isArchived = false,
    DateTime? modifiedAt,
  }) : modifiedAt = modifiedAt ?? createdAt;

  String get nextTaskKey {
    taskCounter++;
    return '$key-$taskCounter';
  }

  Project copyWith({
    String? id,
    String? name,
    String? key,
    String? description,
    DateTime? createdAt,
    String? color,
    String? iconName,
    int? taskCounter,
    bool? isArchived,
    DateTime? modifiedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      taskCounter: taskCounter ?? this.taskCounter,
      isArchived: isArchived ?? this.isArchived,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }
}
