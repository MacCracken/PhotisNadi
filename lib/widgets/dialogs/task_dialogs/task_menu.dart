import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/task.dart';
import '../../../services/task_service.dart';
import '../../../common/utils.dart';
import 'edit_task_dialog.dart';

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
            final messenger = ScaffoldMessenger.of(context);
            final taskService = context.read<TaskService>();
            Navigator.pop(context);
            taskService.deleteTask(task.id);
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Task deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => taskService.restoreTask(task),
                ),
              ),
            );
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
