import 'dart:developer' as developer;
import 'package:hive/hive.dart';

/// Generic Hive-backed repository with indexed lookups.
abstract class HiveRepository<T extends HiveObject> {
  late final Box<T> _box;
  final Map<String, T> _index = {};
  final String _boxName;
  final String _logName;

  HiveRepository(this._boxName, this._logName);

  Map<String, T> get index => Map.unmodifiable(_index);
  List<T> get all => _index.values.toList();
  int get count => _index.length;

  /// Extract the ID from an entity.
  String getId(T entity);

  Future<void> init() async {
    _box = await Hive.openBox<T>(_boxName);
    _rebuildIndex();
  }

  void _rebuildIndex() {
    _index.clear();
    for (final entity in _box.values) {
      _index[getId(entity)] = entity;
    }
  }

  T? get(String id) => _index[id];

  Future<T> put(T entity) async {
    final id = getId(entity);
    try {
      await _box.put(id, entity);
      _index[id] = entity;
      return entity;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to put $id',
        name: _logName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _box.delete(id);
      _index.remove(id);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete $id',
        name: _logName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteWhere(bool Function(T entity) predicate) async {
    final toDelete = _index.entries
        .where((e) => predicate(e.value))
        .map((e) => e.key)
        .toList();
    for (final id in toDelete) {
      await _box.delete(id);
      _index.remove(id);
    }
  }

  List<T> where(bool Function(T entity) predicate) {
    return _index.values.where(predicate).toList();
  }

  T? firstWhere(bool Function(T entity) predicate) {
    try {
      return _index.values.firstWhere(predicate);
    } catch (_) {
      return null;
    }
  }
}
