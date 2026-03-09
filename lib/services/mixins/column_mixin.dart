import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../../models/board.dart';
import '../../models/task.dart';
import '../../repositories/project_repository.dart';

mixin ColumnMixin on ChangeNotifier {
  ProjectRepository get projectRepo;

  // ── Column Management ──

  Future<bool> addColumn(String projectId, BoardColumn column) async {
    try {
      final project = projectRepo.get(projectId);
      if (project == null) return false;

      final columns = List<BoardColumn>.from(project.activeColumns);
      columns.add(column.copyWith(order: columns.length));

      final board = project.activeBoard;
      if (board != null) {
        board.columns = columns;
        project.modifiedAt = DateTime.now();
        await projectRepo.put(project);
      } else {
        final updated = project.copyWith(columns: columns);
        await projectRepo.put(updated);
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to add column', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> updateColumn(String projectId, BoardColumn column) async {
    try {
      final project = projectRepo.get(projectId);
      if (project == null) return false;

      final updatedColumns = project.activeColumns.map((c) {
        return c.id == column.id ? column : c;
      }).toList();

      final board = project.activeBoard;
      if (board != null) {
        board.columns = updatedColumns;
        project.modifiedAt = DateTime.now();
        await projectRepo.put(project);
      } else {
        final updated = project.copyWith(columns: updatedColumns);
        await projectRepo.put(updated);
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to update column', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> deleteColumn(String projectId, String columnId) async {
    try {
      final project = projectRepo.get(projectId);
      if (project == null) return false;

      final updatedColumns =
          project.activeColumns.where((c) => c.id != columnId).toList();
      for (var i = 0; i < updatedColumns.length; i++) {
        updatedColumns[i] = updatedColumns[i].copyWith(order: i);
      }

      final board = project.activeBoard;
      if (board != null) {
        board.columns = updatedColumns;
        project.modifiedAt = DateTime.now();
        await projectRepo.put(project);
      } else {
        final updated = project.copyWith(columns: updatedColumns);
        await projectRepo.put(updated);
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to delete column', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> reorderColumns(String projectId, List<String> columnIds) async {
    try {
      final project = projectRepo.get(projectId);
      if (project == null) return false;

      final columnMap = {for (var c in project.activeColumns) c.id: c};
      final updatedColumns = <BoardColumn>[];
      for (var i = 0; i < columnIds.length; i++) {
        final column = columnMap[columnIds[i]];
        if (column != null) {
          updatedColumns.add(column.copyWith(order: i));
        }
      }

      final board = project.activeBoard;
      if (board != null) {
        board.columns = updatedColumns;
        project.modifiedAt = DateTime.now();
        await projectRepo.put(project);
      } else {
        final updated = project.copyWith(columns: updatedColumns);
        await projectRepo.put(updated);
      }

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log('Failed to reorder columns', name: 'TaskService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  TaskStatus getColumnStatus(String columnId) {
    for (final project in projectRepo.all) {
      for (final column in project.activeColumns) {
        if (column.id == columnId) {
          return column.status;
        }
      }
    }
    return TaskStatus.todo;
  }
}
