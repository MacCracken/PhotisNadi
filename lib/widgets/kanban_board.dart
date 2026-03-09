import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../services/theme_service.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/board.dart';
import '../common/utils.dart';
import '../common/constants.dart';
import '../widgets/dialogs/task_dialogs.dart';
import '../widgets/common/common_widgets.dart';
import '../widgets/common/task_card.dart';
import '../widgets/common/column_widgets.dart';
import '../widgets/common/project_header.dart';

class PaginatedTaskColumn extends StatefulWidget {
  final BoardColumn column;
  final Project project;
  final Map<String, FocusNode>? taskFocusNodes;

  const PaginatedTaskColumn({
    super.key,
    required this.column,
    required this.project,
    this.taskFocusNodes,
  });

  @override
  State<PaginatedTaskColumn> createState() => _PaginatedTaskColumnState();
}

class _PaginatedTaskColumnState extends State<PaginatedTaskColumn> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final taskService = context.watch<TaskService>();
    final color = parseColor(widget.column.color);
    final totalCount = taskService.getTaskCountForColumn(
      widget.column.id,
      projectId: widget.project.id,
    );
    final tasks = taskService.getTasksForColumnPaginated(
      widget.column.id,
      projectId: widget.project.id,
      page: _currentPage,
    );
    final hasMore = taskService.hasMoreTasksForColumn(
      widget.column.id,
      projectId: widget.project.id,
      page: _currentPage,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildColumnHeader(color, totalCount),
          Expanded(
            child: DragTarget<Task>(
              onAcceptWithDetails: (details) {
                final task = details.data;
                final taskService = context.read<TaskService>();

                if (widget.column.status == TaskStatus.done &&
                    taskService.isTaskBlocked(task)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Cannot complete "${task.title}": dependencies not done'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                task.status = widget.column.status;
                taskService.updateTask(task);
              },
              builder: (context, candidateData, rejectedData) {
                final isDropTarget = candidateData.isNotEmpty;

                if (tasks.isEmpty && !isDropTarget) {
                  return _buildEmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.smallPadding,
                  ),
                  itemCount: tasks.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == tasks.length) {
                      return _buildLoadMoreButton(taskService);
                    }
                    final task = tasks[index];
                    return _buildDraggableTask(task);
                  },
                );
              },
            ),
          ),
          _buildAddTaskButton(),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(Color color, int totalCount) {
    return ColumnHeader(
      column: widget.column,
      color: color,
      totalCount: totalCount,
      onEdit: () =>
          showEditColumnDialog(context, widget.project, widget.column),
      onDelete: () =>
          showDeleteColumnDialog(context, widget.project, widget.column),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.inbox,
      title: 'No tasks',
    );
  }

  Widget _buildLoadMoreButton(TaskService taskService) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      child: TextButton(
        onPressed: () {
          setState(() {
            _currentPage++;
          });
        },
        child: const Text('Load more'),
      ),
    );
  }

  Widget _buildDraggableTask(Task task) {
    final focusNode = widget.taskFocusNodes?[task.id];
    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: AppConstants.elevationHigh,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        child: SizedBox(
          width: AppConstants.columnWidth - 20,
          child: TaskCard(
            task: task,
            isDragging: true,
            onTap: () => showTaskDetails(context, task),
            onLongPress: () => showTaskMenu(context, task),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: TaskCard(
          task: task,
          onTap: () => showTaskDetails(context, task),
          onLongPress: () => showTaskMenu(context, task),
        ),
      ),
      child: TaskCard(
        task: task,
        focusNode: focusNode,
        onTap: () => showTaskDetails(context, task),
        onLongPress: () => showTaskMenu(context, task),
      ),
    );
  }

  Widget _buildAddTaskButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      child: TextButton.icon(
        onPressed: () => showAddTaskDialog(context, columnId: widget.column.id),
        icon: const Icon(Icons.add, size: AppConstants.iconSizeMedium),
        label: const Text('Add Task'),
      ),
    );
  }
}

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({super.key});

  @override
  State<KanbanBoard> createState() => KanbanBoardState();
}

class KanbanBoardState extends State<KanbanBoard> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, FocusNode> _taskFocusNodes = {};
  int _focusedColumnIndex = 0;
  int _focusedTaskIndex = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _taskFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _getOrCreateFocusNode(String taskId) {
    return _taskFocusNodes.putIfAbsent(taskId, FocusNode.new);
  }

  void _navigateTask(int delta) {
    final taskService = context.read<TaskService>();
    final project = taskService.selectedProject;
    if (project == null) return;

    final columns = project.activeColumns;
    if (columns.isEmpty) return;

    _focusedColumnIndex = _focusedColumnIndex.clamp(0, columns.length - 1);
    final column = columns[_focusedColumnIndex];
    final tasks = taskService.getTasksForColumnPaginated(
      column.id,
      projectId: project.id,
      page: 0,
    );
    if (tasks.isEmpty) return;

    _focusedTaskIndex = (_focusedTaskIndex + delta).clamp(0, tasks.length - 1);
    final task = tasks[_focusedTaskIndex];
    final node = _getOrCreateFocusNode(task.id);
    node.requestFocus();
  }

  void _navigateColumn(int delta) {
    final taskService = context.read<TaskService>();
    final project = taskService.selectedProject;
    if (project == null) return;

    final columns = project.activeColumns;
    if (columns.isEmpty) return;

    _focusedColumnIndex =
        (_focusedColumnIndex + delta).clamp(0, columns.length - 1);
    _focusedTaskIndex = 0;
    _navigateTask(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Selector<TaskService, Project?>(
          selector: (_, service) => service.selectedProject,
          builder: (context, selectedProject, _) =>
              _buildHeader(selectedProject),
        ),
        Expanded(
          child: Selector<TaskService, String?>(
            selector: (_, service) => service.selectedProjectId,
            builder: (context, selectedProjectId, _) {
              if (selectedProjectId == null) {
                return _buildNoProjectSelected();
              }
              return _buildColumns(selectedProjectId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColumns(String selectedProjectId) {
    final themeService = context.watch<ThemeService>();
    final compact = themeService.isCompact;
    final colWidth =
        compact ? AppConstants.columnWidthCompact : AppConstants.columnWidth;
    final colMargin =
        compact ? AppConstants.columnMarginCompact : AppConstants.columnMargin;

    return Selector<TaskService, List<BoardColumn>>(
      selector: (_, service) => service.selectedProject?.activeColumns ?? [],
      builder: (context, columns, _) {
        // Build focus nodes for all visible tasks
        final taskService = context.read<TaskService>();
        for (final column in columns) {
          final tasks = taskService.getTasksForColumnPaginated(
            column.id,
            projectId: selectedProjectId,
            page: 0,
          );
          for (final task in tasks) {
            _getOrCreateFocusNode(task.id);
          }
        }

        return ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          buildDefaultDragHandles: false,
          itemCount: columns.length,
          onReorder: (oldIndex, newIndex) {
            final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
            final columnIds = columns.map((c) => c.id).toList();
            final id = columnIds.removeAt(oldIndex);
            columnIds.insert(adjustedIndex, id);
            context
                .read<TaskService>()
                .reorderColumns(selectedProjectId, columnIds);
          },
          itemBuilder: (context, index) {
            final column = columns[index];
            return Selector<TaskService, Project?>(
              selector: (_, service) => service.selectedProject,
              builder: (context, project, _) {
                if (project == null) return const SizedBox.shrink();
                return Container(
                  key: ValueKey(column.id),
                  width: colWidth,
                  margin: EdgeInsets.only(right: colMargin),
                  child: PaginatedTaskColumn(
                    column: column,
                    project: project,
                    taskFocusNodes: _taskFocusNodes,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNoProjectSelected() {
    return const EmptyState(
      icon: Icons.folder_open,
      title: 'No project selected',
      subtitle: 'Select a project from the sidebar or create a new one',
    );
  }

  Widget _buildHeader(Project? project) {
    return ProjectHeader(project: project);
  }

  void navigateNextTask() => _navigateTask(1);
  void navigatePrevTask() => _navigateTask(-1);
  void navigateNextColumn() => _navigateColumn(1);
  void navigatePrevColumn() => _navigateColumn(-1);
}
