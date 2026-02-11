import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../common/utils.dart';
import 'dialogs/task_dialogs.dart';
import 'dialogs/project_dialogs.dart';

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({super.key});

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskService>(
      builder: (context, taskService, child) {
        final selectedProject = taskService.selectedProject;
        final columns = [
          {'id': 'todo', 'title': 'To Do', 'color': Colors.grey.shade400},
          {
            'id': 'in_progress',
            'title': 'In Progress',
            'color': Colors.blue.shade400
          },
          {'id': 'done', 'title': 'Done', 'color': Colors.green.shade400},
        ];

        return Column(
          children: [
            _buildHeader(selectedProject),
            Expanded(
              child: selectedProject == null
                  ? _buildNoProjectSelected()
                  : ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(16),
                      itemCount: columns.length,
                      itemBuilder: (context, index) {
                        final column = columns[index];
                        final tasks = taskService.getTasksForColumn(
                          column['id'] as String,
                        );

                        return Container(
                          width: 300,
                          margin: const EdgeInsets.only(right: 16),
                          child: _buildColumn(
                            column['id'] as String,
                            column['title'] as String,
                            column['color'] as Color,
                            tasks,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoProjectSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No project selected',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a project from the sidebar or create a new one',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Project? project) {
    Color? projectColor;
    if (project != null) {
      projectColor = parseColor(project.color);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (project != null) ...[
            Container(
              width: 8,
              height: 24,
              decoration: BoxDecoration(
                color: projectColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  project.key,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ] else
            const Text(
              'Projects',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          const Spacer(),
          if (project != null) ...[
            IconButton(
              onPressed: () => showAddTaskDialog(context),
              icon: const Icon(Icons.add),
              tooltip: 'Add Task',
            ),
            IconButton(
              onPressed: () => showProjectSettings(context, project),
              icon: const Icon(Icons.settings),
              tooltip: 'Project Settings',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColumn(
    String columnId,
    String title,
    Color color,
    List<Task> tasks,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<Task>(
              onAcceptWithDetails: (details) {
                _moveTaskToColumn(details.data, columnId);
              },
              builder: (context, candidateData, rejectedData) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 280,
                          child: _buildTaskCard(task, isDragging: true),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: _buildTaskCard(task),
                      ),
                      child: _buildTaskCard(task),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => showAddTaskDialog(context, columnId: columnId),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Task'),
            ),
          ),
        ],
      ),
    );
  }

  void _moveTaskToColumn(Task task, String columnId) {
    TaskStatus newStatus;
    switch (columnId) {
      case 'todo':
        newStatus = TaskStatus.todo;
        break;
      case 'in_progress':
        newStatus = TaskStatus.inProgress;
        break;
      case 'done':
        newStatus = TaskStatus.done;
        break;
      default:
        return;
    }

    task.status = newStatus;
    context.read<TaskService>().updateTask(task);
  }

  Widget _buildTaskCard(Task task, {bool isDragging = false}) {
    final priorityColor = getPriorityColor(task.priority);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isDragging ? 8 : 1,
      child: InkWell(
        onTap: () => showTaskDetails(context, task),
        onLongPress: () => showTaskMenu(context, task),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (task.taskKey != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.taskKey!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (task.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: task.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (task.dueDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(task.dueDate!),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
