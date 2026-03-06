import 'package:hive/hive.dart';
import '../common/utils.dart';

part 'tag.g.dart';

/// Represents a tag with a name and color, scoped to a project.
@HiveType(typeId: 8)
class Tag extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String color;

  @HiveField(3)
  String projectId;

  Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.projectId,
  }) {
    if (!isValidUuid(id)) {
      throw ArgumentError('Invalid tag ID: must be a valid UUID');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }
    if (!isValidHexColor(color)) {
      throw ArgumentError('Invalid tag color: must be a valid hex color');
    }
    if (!isValidUuid(projectId)) {
      throw ArgumentError('Invalid project ID: must be a valid UUID');
    }
  }

  Tag copyWith({
    String? id,
    String? name,
    String? color,
    String? projectId,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      projectId: projectId ?? this.projectId,
    );
  }
}
