import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isMultiSelectMode;
  final Set<String> selectedTaskIds;
  final ValueChanged<String>? onTaskToggleSelect;
  final ValueChanged<String>? onTaskLongPress;

  const PaginatedTaskColumn({
    super.key,
    required this.column,
    required this.project,
    this.taskFocusNodes,
    this.isMultiSelectMode = false,
    this.selectedTaskIds = const {},
    this.onTaskToggleSelect,
    this.onTaskLongPress,
  });

  @override
  State<PaginatedTaskColumn> createState() => _PaginatedTaskColumnState();
}

class _PaginatedTaskColumnState extends State<PaginatedTaskColumn> {
  int _currentPage = 0;
  final ScrollController _columnScrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _columnScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _columnScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    final maxScroll = _columnScrollController.position.maxScrollExtent;
    final currentScroll = _columnScrollController.position.pixels;
    if (maxScroll - currentScroll <= 100) {
      final taskService = context.read<TaskService>();
      final hasMore = taskService.hasMoreTasksForColumn(
        widget.column.id,
        projectId: widget.project.id,
        page: _currentPage,
      );
      if (hasMore) {
        setState(() {
          _isLoadingMore = true;
          _currentPage++;
        });
        // Reset loading flag after frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isLoadingMore = false);
        });
      }
    }
  }

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

    return Semantics(
      label: '${widget.column.title} column, $totalCount tasks',
      container: true,
      child: Container(
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
                    controller: _columnScrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.smallPadding,
                    ),
                    itemCount: tasks.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == tasks.length) {
                        return _buildLoadingIndicator();
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

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(AppConstants.smallPadding),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildDraggableTask(Task task) {
    final focusNode = widget.taskFocusNodes?[task.id];
    final isSelected = widget.selectedTaskIds.contains(task.id);

    if (widget.isMultiSelectMode) {
      return Stack(
        children: [
          TaskCard(
            task: task,
            focusNode: focusNode,
            onTap: () => widget.onTaskToggleSelect?.call(task.id),
          ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      );
    }

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
        onLongPress: () {
          widget.onTaskLongPress?.call(task.id);
        },
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
  bool _isMultiSelectMode = false;
  final Set<String> _selectedTaskIds = {};

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

  void _enterMultiSelect(String taskId) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedTaskIds.add(taskId);
    });
  }

  void _toggleTaskSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedTaskIds.clear();
    });
  }

  Widget _buildBulkActionBar() {
    final taskService = context.read<TaskService>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            '${_selectedTaskIds.length} selected',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          PopupMenuButton<TaskStatus>(
            tooltip: 'Move status',
            icon: const Icon(Icons.swap_horiz, size: 20),
            itemBuilder: (context) => TaskStatus.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Text(formatStatus(s)),
                    ))
                .toList(),
            onSelected: (status) {
              taskService.bulkUpdateStatus(_selectedTaskIds.toList(), status);
              _exitMultiSelect();
            },
          ),
          PopupMenuButton<TaskPriority>(
            tooltip: 'Change priority',
            icon: const Icon(Icons.flag, size: 20),
            itemBuilder: (context) => TaskPriority.values
                .map((p) => PopupMenuItem(
                      value: p,
                      child: Text(capitalizeFirst(p.name)),
                    ))
                .toList(),
            onSelected: (priority) {
              taskService.bulkUpdatePriority(
                  _selectedTaskIds.toList(), priority);
              _exitMultiSelect();
            },
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move, size: 20),
            tooltip: 'Move to project',
            onPressed: () {
              _showBulkMoveDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete tasks?'),
                  content: Text(
                    'Delete ${_selectedTaskIds.length} selected tasks? '
                    'This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm ?? false) {
                taskService.bulkDelete(_selectedTaskIds.toList());
                _exitMultiSelect();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Cancel',
            onPressed: _exitMultiSelect,
          ),
        ],
      ),
    );
  }

  void _showBulkMoveDialog(BuildContext context) {
    final taskService = context.read<TaskService>();
    final projects = taskService.activeProjects;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Project'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: parseColor(project.color),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(project.name),
                subtitle: Text(project.projectKey),
                onTap: () {
                  taskService.bulkMoveToProject(
                    _selectedTaskIds.toList(),
                    project.id,
                  );
                  Navigator.pop(context);
                  _exitMultiSelect();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _isMultiSelectMode) {
          _exitMultiSelect();
        }
      },
      child: Column(
        children: [
          if (_isMultiSelectMode) _buildBulkActionBar(),
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
      ),
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
        // Build focus nodes for visible tasks and clean up stale ones
        final taskService = context.read<TaskService>();
        final activeTaskIds = <String>{};
        for (final column in columns) {
          final tasks = taskService.getTasksForColumnPaginated(
            column.id,
            projectId: selectedProjectId,
            page: 0,
          );
          for (final task in tasks) {
            _getOrCreateFocusNode(task.id);
            activeTaskIds.add(task.id);
          }
        }
        // Dispose focus nodes for tasks no longer visible
        _taskFocusNodes.keys
            .where((id) => !activeTaskIds.contains(id))
            .toList()
            .forEach((id) {
          _taskFocusNodes[id]!.dispose();
          _taskFocusNodes.remove(id);
        });

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
                    isMultiSelectMode: _isMultiSelectMode,
                    selectedTaskIds: _selectedTaskIds,
                    onTaskToggleSelect: _toggleTaskSelection,
                    onTaskLongPress: _enterMultiSelect,
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
