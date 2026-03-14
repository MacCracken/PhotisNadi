import '../models/tag.dart';
import 'hive_repository.dart';

class TagRepository extends HiveRepository<Tag> {
  /// Secondary index: projectId -> set of tag IDs.
  final Map<String, Set<String>> _projectIndex = {};

  TagRepository() : super('tags', 'TagRepository');

  @override
  String getId(Tag entity) => entity.id;

  @override
  Future<void> init() async {
    await super.init();
    _rebuildProjectIndex();
  }

  void _rebuildProjectIndex() {
    _projectIndex.clear();
    for (final tag in all) {
      _projectIndex.putIfAbsent(tag.projectId, () => {}).add(tag.id);
    }
  }

  /// Find which project index currently holds this tag ID.
  String? _findCurrentProjectId(String tagId) {
    for (final entry in _projectIndex.entries) {
      if (entry.value.contains(tagId)) return entry.key;
    }
    return null;
  }

  @override
  Future<Tag> put(Tag entity) async {
    // Remove from old project index before storing (handles project changes)
    final oldPid = _findCurrentProjectId(entity.id);
    if (oldPid != null) {
      _projectIndex[oldPid]?.remove(entity.id);
    }

    final result = await super.put(entity);
    _projectIndex.putIfAbsent(entity.projectId, () => {}).add(entity.id);
    return result;
  }

  @override
  Future<void> delete(String id) async {
    final tag = get(id);
    if (tag != null) {
      _projectIndex[tag.projectId]?.remove(id);
    }
    await super.delete(id);
  }

  /// Get tags for a project, sorted by name.
  List<Tag> getByProject(String projectId) {
    final ids = _projectIndex[projectId];
    if (ids == null || ids.isEmpty) return [];
    return ids.map(get).whereType<Tag>().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Find tag by name within a project.
  Tag? getByName(String name, String projectId) {
    final ids = _projectIndex[projectId];
    if (ids == null) return null;
    for (final id in ids) {
      final tag = get(id);
      if (tag != null && tag.name == name) return tag;
    }
    return null;
  }
}
