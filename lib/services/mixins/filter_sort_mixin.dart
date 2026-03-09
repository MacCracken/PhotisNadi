import 'package:flutter/foundation.dart';
import '../../models/task.dart';
import '../../repositories/task_repository.dart';

enum TaskSortBy {
  createdAt,
  dueDate,
  priority,
  title,
}

mixin FilterSortMixin on ChangeNotifier {
  TaskRepository get taskRepo;

  String _searchQuery = '';
  TaskStatus? _filterStatus;
  TaskPriority? _filterPriority;
  Set<String> _filterTags = {};
  DateTime? _filterDueBefore;
  DateTime? _filterDueAfter;
  TaskSortBy _sortBy = TaskSortBy.createdAt;
  bool _sortAscending = false;

  String get searchQuery => _searchQuery;
  TaskStatus? get filterStatus => _filterStatus;
  TaskPriority? get filterPriority => _filterPriority;
  Set<String> get filterTags => Set.unmodifiable(_filterTags);
  DateTime? get filterDueBefore => _filterDueBefore;
  DateTime? get filterDueAfter => _filterDueAfter;
  TaskSortBy get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _filterStatus != null ||
      _filterPriority != null ||
      _filterTags.isNotEmpty ||
      _filterDueBefore != null ||
      _filterDueAfter != null;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  void setFilterStatus(TaskStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setFilterPriority(TaskPriority? priority) {
    _filterPriority = priority;
    notifyListeners();
  }

  void toggleFilterTag(String tag) {
    if (_filterTags.contains(tag)) {
      _filterTags.remove(tag);
    } else {
      _filterTags.add(tag);
    }
    notifyListeners();
  }

  void clearFilterTags() {
    _filterTags.clear();
    notifyListeners();
  }

  void setFilterDueBefore(DateTime? date) {
    _filterDueBefore = date;
    notifyListeners();
  }

  void setFilterDueAfter(DateTime? date) {
    _filterDueAfter = date;
    notifyListeners();
  }

  void setSortBy(TaskSortBy sortBy) {
    if (_sortBy == sortBy) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      _sortAscending = false;
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterStatus = null;
    _filterPriority = null;
    _filterTags = {};
    _filterDueBefore = null;
    _filterDueAfter = null;
    notifyListeners();
  }

  List<Task> getFilteredTasks(String projectId) {
    var filtered = taskRepo.getByProject(projectId);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(_searchQuery) ||
            (task.description?.toLowerCase().contains(_searchQuery) ?? false) ||
            (task.taskKey?.toLowerCase().contains(_searchQuery) ?? false) ||
            task.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    if (_filterStatus != null) {
      filtered =
          filtered.where((task) => task.status == _filterStatus).toList();
    }

    if (_filterPriority != null) {
      filtered =
          filtered.where((task) => task.priority == _filterPriority).toList();
    }

    if (_filterTags.isNotEmpty) {
      filtered = filtered
          .where((task) => _filterTags.every((tag) => task.tags.contains(tag)))
          .toList();
    }

    if (_filterDueBefore != null) {
      filtered = filtered
          .where((task) =>
              task.dueDate != null && task.dueDate!.isBefore(_filterDueBefore!))
          .toList();
    }

    if (_filterDueAfter != null) {
      filtered = filtered
          .where((task) =>
              task.dueDate != null && task.dueDate!.isAfter(_filterDueAfter!))
          .toList();
    }

    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case TaskSortBy.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
        case TaskSortBy.dueDate:
          if (a.dueDate == null && b.dueDate == null) {
            comparison = 0;
          } else if (a.dueDate == null) {
            comparison = 1;
          } else if (b.dueDate == null) {
            comparison = -1;
          } else {
            comparison = a.dueDate!.compareTo(b.dueDate!);
          }
        case TaskSortBy.priority:
          comparison = a.priority.index.compareTo(b.priority.index);
        case TaskSortBy.title:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }
}
