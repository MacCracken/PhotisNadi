import '../models/task.dart';
import 'hive_repository.dart';

class TaskRepository extends HiveRepository<Task> {
  /// Secondary index: projectId -> set of task IDs for O(1) project lookups.
  final Map<String, Set<String>> _projectIndex = {};

  /// Reverse index: taskId -> projectId for O(1) lookups.
  final Map<String, String> _taskProjectIndex = {};

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
    _taskProjectIndex.clear();
    for (final task in all) {
      final pid = task.projectId ?? '';
      _projectIndex.putIfAbsent(pid, () => {}).add(task.id);
      _taskProjectIndex[task.id] = pid;
    }
  }

  /// Find which project index currently holds this task ID. O(1).
  String? _findCurrentProjectId(String taskId) {
    return _taskProjectIndex[taskId];
  }

  @override
  Future<Task> put(Task entity) async {
    // Capture old project ID before put (entity may be same object reference)
    final oldPid = _findCurrentProjectId(entity.id);

    if (oldPid != null) {
      _projectIndex[oldPid]?.remove(entity.id);
    }

    try {
      final result = await super.put(entity);

      // Add to new project index and update reverse index
      final pid = entity.projectId ?? '';
      _projectIndex.putIfAbsent(pid, () => {}).add(entity.id);
      _taskProjectIndex[entity.id] = pid;

      return result;
    } catch (e) {
      // Restore old index entries on failure to keep indices consistent
      if (oldPid != null) {
        _projectIndex.putIfAbsent(oldPid, () => {}).add(entity.id);
        _taskProjectIndex[entity.id] = oldPid;
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    final task = get(id);
    if (task != null) {
      final pid = task.projectId ?? '';
      _projectIndex[pid]?.remove(id);
    }
    _taskProjectIndex.remove(id);
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
      _taskProjectIndex.remove(id);
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
  Future<void> removeDependencyReferences(String taskId) async {
    for (final task in all) {
      if (task.dependsOn.contains(taskId)) {
        task.dependsOn = task.dependsOn.where((id) => id != taskId).toList();
        await put(task);
      }
    }
  }
}
