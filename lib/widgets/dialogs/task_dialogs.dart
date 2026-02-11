import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../models/project.dart';
import '../../services/task_service.dart';
import '../../common/utils.dart';

/// Shows a dialog to add a new task
void showAddTaskDialog(BuildContext context, {String? columnId}) {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  TaskPriority selectedPriority = TaskPriority.medium;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
              value: selectedPriority,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                final taskService = context.read<TaskService>();
                taskService.addTask(
                  titleController.text,
                  description: descController.text.isNotEmpty
                      ? descController.text
                      : null,
                  priority: selectedPriority,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
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

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                value: selectedPriority,
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
                value: selectedStatus,
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
                task.description = descController.text.isNotEmpty
                    ? descController.text
                    : null;
                task.priority = selectedPriority;
                task.status = selectedStatus;
                context.read<TaskService>().updateTask(task);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
              subtitle: Text(project.key),
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
