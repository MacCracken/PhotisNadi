import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tag.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../common/utils.dart';

/// Shows a dialog to add a new task
void showAddTaskDialog(BuildContext context, {String? columnId}) {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  TaskPriority selectedPriority = TaskPriority.medium;
  final selectedTags = <String>{};

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final taskService = context.read<TaskService>();
        final projectId = taskService.selectedProjectId;
        final projectTags = projectId != null
            ? taskService.getTagsForProject(projectId)
            : <Tag>[];

        return AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: getPriorityColor(priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(capitalizeFirst(priority.name)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPriority = value!;
                    });
                  },
                ),
                if (projectTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tags',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: projectTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      final tagColor = parseColor(tag.color);
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        selectedColor: tagColor.withValues(alpha: 0.3),
                        checkmarkColor: tagColor,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedTags.add(tag.name);
                            } else {
                              selectedTags.remove(tag.name);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  taskService.addTask(
                    titleController.text,
                    description: descController.text.isNotEmpty
                        ? descController.text
                        : null,
                    priority: selectedPriority,
                    tags: selectedTags.toList(),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  );
}

/// Shows a dialog with task details
void showTaskDetails(BuildContext context, Task task) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          if (task.taskKey != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                task.taskKey!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(task.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description != null) ...[
            Text(task.description!),
            const SizedBox(height: 16),
          ],
          _buildDetailRow('Priority', formatPriority(task.priority)),
          _buildDetailRow('Status', formatStatus(task.status)),
          if (task.dueDate != null)
            _buildDetailRow('Due', formatDate(task.dueDate!)),
          _buildDetailRow('Created', formatDate(task.createdAt)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            showEditTaskDialog(context, task);
          },
          child: const Text('Edit'),
        ),
      ],
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(value),
      ],
    ),
  );
}

/// Shows a dialog to edit an existing task
void showEditTaskDialog(BuildContext context, Task task) {
  final TextEditingController titleController =
      TextEditingController(text: task.title);
  final TextEditingController descController =
      TextEditingController(text: task.description ?? '');
  TaskPriority selectedPriority = task.priority;
  TaskStatus selectedStatus = task.status;
  final selectedTags = Set<String>.from(task.tags);
  final taskService = context.read<TaskService>();
  final projectTasks = taskService
      .getTasksForProject(task.projectId)
      .where((t) => t.id != task.id)
      .toList();
  final currentDeps = taskService.getTaskDependencies(task.id);

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final projectTagDefs = task.projectId != null
            ? taskService.getTagsForProject(task.projectId!)
            : <Tag>[];

        return AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: TaskPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(capitalizeFirst(priority.name)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPriority = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: TaskStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(formatStatus(status)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value!;
                    });
                  },
                ),
                if (projectTagDefs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tags',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: projectTagDefs.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      final tagColor = parseColor(tag.color);
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        selectedColor: tagColor.withValues(alpha: 0.3),
                        checkmarkColor: tagColor,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedTags.add(tag.name);
                            } else {
                              selectedTags.remove(tag.name);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Dependencies (Blocked by)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              if (currentDeps.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: currentDeps.map((dep) {
                    return Chip(
                      label: Text(dep.taskKey ?? dep.title),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        taskService.removeTaskDependency(task.id, dep.id);
                        setDialogState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String?>(
                decoration: const InputDecoration(
                  labelText: 'Add dependency',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Select task...'),
                  ),
                  ...projectTasks
                      .where((t) => !task.dependsOn.contains(t.id))
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.taskKey ?? t.title),
                          )),
                ],
                onChanged: (value) {
                  if (value != null) {
                    final added = taskService.addTaskDependency(task.id, value);
                    if (!added) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Cannot add: would create circular dependency'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    setDialogState(() {});
                  }
                },
              ),
              if (taskService.isTaskBlocked(task)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Task is blocked by incomplete dependencies',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                task.title = titleController.text;
                task.description =
                    descController.text.isNotEmpty ? descController.text : null;
                task.priority = selectedPriority;
                task.status = selectedStatus;
                task.tags = selectedTags.toList();
                context.read<TaskService>().updateTask(task);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
      },
    ),
  );
}

/// Shows a task menu with edit, move, and delete options
void showTaskMenu(BuildContext context, Task task) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit'),
          onTap: () {
            Navigator.pop(context);
            showEditTaskDialog(context, task);
          },
        ),
        ListTile(
          leading: const Icon(Icons.drive_file_move),
          title: const Text('Move to Project'),
          onTap: () {
            Navigator.pop(context);
            showMoveToProjectDialog(context, task);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text('Delete', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            context.read<TaskService>().deleteTask(task.id);
          },
        ),
      ],
    ),
  );
}

/// Shows a dialog to move a task to a different project
void showMoveToProjectDialog(BuildContext context, Task task) {
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
            final isCurrentProject = project.id == task.projectId;

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
              trailing: isCurrentProject
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: isCurrentProject
                  ? null
                  : () {
                      taskService.moveTaskToProject(task.id, project.id);
                      Navigator.pop(context);
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
