import '../models/task.dart';
import '../models/project.dart';
import '../models/ritual.dart';
import '../models/board.dart';

/// Convert a Task to a JSON-serializable map (snake_case keys).
Map<String, dynamic> taskToJson(Task task) => {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'status': task.status.name,
      'priority': task.priority.name,
      'created_at': task.createdAt.toUtc().toIso8601String(),
      'modified_at': task.modifiedAt.toUtc().toIso8601String(),
      'due_date': task.dueDate?.toUtc().toIso8601String(),
      'project_id': task.projectId,
      'tags': task.tags,
      'task_key': task.taskKey,
      'depends_on': task.dependsOn,
      'subtasks': task.parsedSubtasks
          .map((s) => {'title': s.title, 'done': s.done})
          .toList(),
      'estimated_minutes': task.estimatedMinutes,
      'tracked_minutes': task.trackedMinutes,
      'recurrence': task.recurrence,
      'attachments': task.attachments,
    };

/// Convert a BoardColumn to a JSON-serializable map.
Map<String, dynamic> boardColumnToJson(BoardColumn column) => {
      'id': column.id,
      'title': column.title,
      'task_ids': column.taskIds,
      'order': column.order,
      'color': column.color,
      'status': column.status.name,
    };

/// Convert a Board to a JSON-serializable map.
Map<String, dynamic> boardToJson(Board board) => {
      'id': board.id,
      'title': board.title,
      'description': board.description,
      'created_at': board.createdAt.toUtc().toIso8601String(),
      'column_ids': board.columnIds,
      'color': board.color,
      'columns': board.columns.map(boardColumnToJson).toList(),
    };

/// Convert a Project to a JSON-serializable map.
Map<String, dynamic> projectToJson(Project project) => {
      'id': project.id,
      'name': project.name,
      'project_key': project.projectKey,
      'description': project.description,
      'created_at': project.createdAt.toUtc().toIso8601String(),
      'modified_at': project.modifiedAt.toUtc().toIso8601String(),
      'color': project.color,
      'icon_name': project.iconName,
      'task_counter': project.taskCounter,
      'is_archived': project.isArchived,
      'boards': project.boards.map(boardToJson).toList(),
      'active_board_id': project.activeBoardId,
    };

/// Convert a Ritual to a JSON-serializable map.
Map<String, dynamic> ritualToJson(Ritual ritual) => {
      'id': ritual.id,
      'title': ritual.title,
      'description': ritual.description,
      'is_completed': ritual.isCompleted,
      'created_at': ritual.createdAt.toUtc().toIso8601String(),
      'last_completed': ritual.lastCompleted?.toUtc().toIso8601String(),
      'streak_count': ritual.streakCount,
      'frequency': ritual.frequency.name,
    };
