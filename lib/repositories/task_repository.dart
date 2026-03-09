import '../models/task.dart';
import 'hive_repository.dart';

class TaskRepository extends HiveRepository<Task> {
  /// Secondary index: projectId -> set of task IDs for O(1) project lookups.
  final Map<String, Set<String>> _projectIndex = {};

  TaskRepository() : super('tasks', 'TaskRepository');

  @override
  String getId(Task entity) => entity.id;

  @override
  Future<void> init() async {
    await super.init();
    _rebuildProjectIndex();
  }

  void _rebuildProjectIndex() {
    _projectIndex.clear();
    for (final task in all) {
      final pid = task.projectId ?? '';
      _projectIndex.putIfAbsent(pid, () => {}).add(task.id);
    }
  }

  /// Find which project index currently holds this task ID.
  String? _findCurrentProjectId(String taskId) {
    for (final entry in _projectIndex.entries) {
      if (entry.value.contains(taskId)) return entry.key;
    }
    return null;
  }

  @override
  Future<Task> put(Task entity) async {
    // Capture old project ID before put (entity may be same object reference)
    final oldPid = _findCurrentProjectId(entity.id);

    if (oldPid != null) {
      _projectIndex[oldPid]?.remove(entity.id);
    }

    final result = await super.put(entity);

    // Add to new project index
    final pid = entity.projectId ?? '';
    _projectIndex.putIfAbsent(pid, () => {}).add(entity.id);

    return result;
  }

  @override
  Future<void> delete(String id) async {
    final task = get(id);
    if (task != null) {
      final pid = task.projectId ?? '';
      _projectIndex[pid]?.remove(id);
    }
    await super.delete(id);
  }

  @override
  Future<void> deleteWhere(bool Function(Task) predicate) async {
    final toDelete = index.entries
        .where((e) => predicate(e.value))
        .map((e) => e.key)
        .toList();
    for (final id in toDelete) {
      final task = get(id);
      if (task != null) {
        final pid = task.projectId ?? '';
        _projectIndex[pid]?.remove(id);
      }
    }
    await super.deleteWhere(predicate);
  }

  /// Get tasks for a project using the secondary index. O(n) in project tasks, not all tasks.
  List<Task> getByProject(String? projectId) {
    final pid = projectId ?? '';
    final ids = _projectIndex[pid];
    if (ids == null || ids.isEmpty) return [];
    return ids.map(get).whereType<Task>().toList();
  }

  /// Remove all dependency references to a deleted task.
  void removeDependencyReferences(String taskId) {
    for (final task in all) {
      if (task.dependsOn.contains(taskId)) {
        task.dependsOn = task.dependsOn.where((id) => id != taskId).toList();
      }
    }
  }
}
