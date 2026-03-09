import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/tag.dart';
import '../../repositories/tag_repository.dart';
import '../../repositories/task_repository.dart';

mixin TagMixin on ChangeNotifier {
  TagRepository get tagRepo;
  TaskRepository get taskRepo;
  Set<String> get filterTags;

  List<Tag> getTagsForProject(String projectId) {
    return tagRepo.getByProject(projectId);
  }

  Tag? getTagByName(String name, String projectId) {
    return tagRepo.getByName(name, projectId);
  }

  List<String> getAllTagsForProject(String projectId) {
    final tags = <String>{};
    for (final task in taskRepo.getByProject(projectId)) {
      tags.addAll(task.tags);
    }
    return tags.toList()..sort();
  }

  Future<Tag?> addTag(String name, String color, String projectId) async {
    try {
      final existing = tagRepo.getByName(name, projectId);
      if (existing != null) return null;

      const uuid = Uuid();
      final tag = Tag(
        id: uuid.v4(),
        name: name.trim(),
        color: color,
        projectId: projectId,
      );

      await tagRepo.put(tag);
      notifyListeners();
      return tag;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to add tag: $name',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> updateTag(Tag tag) async {
    try {
      final existing = tagRepo.get(tag.id);
      final oldName = existing?.name;

      await tagRepo.put(tag);

      if (oldName != null && oldName != tag.name) {
        for (final task in taskRepo.getByProject(tag.projectId)) {
          if (task.tags.contains(oldName)) {
            task.tags = task.tags.map((t) => t == oldName ? tag.name : t).toList();
            await taskRepo.put(task);
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update tag: ${tag.id}',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteTag(String tagId) async {
    try {
      final tag = tagRepo.get(tagId);
      if (tag == null) return false;

      for (final task in taskRepo.getByProject(tag.projectId)) {
        if (task.tags.contains(tag.name)) {
          task.tags = task.tags.where((t) => t != tag.name).toList();
          await taskRepo.put(task);
        }
      }

      removeFilterTagOnDelete(tag.name);
      await tagRepo.delete(tagId);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete tag: $tagId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Hook for FilterSortMixin to remove from filter tags.
  void removeFilterTagOnDelete(String tagName);
}
