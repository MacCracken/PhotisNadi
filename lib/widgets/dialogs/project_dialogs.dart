import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/project.dart';
import '../../services/task_service.dart';
import '../../common/utils.dart';

/// Shows a dialog to add a new project
void showAddProjectDialog(BuildContext context) {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController keyController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  String selectedColor = '#4A90E2';

  final colors = [
    '#4A90E2',
    '#50C878',
    '#FF6B6B',
    '#FFB347',
    '#9B59B6',
    '#3498DB',
    '#1ABC9C',
    '#E74C3C',
    '#F39C12',
    '#8E44AD',
  ];

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('New Project'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'e.g., Mobile App',
                ),
                autofocus: true,
                onChanged: (value) {
                  // Auto-generate key from name
                  if (keyController.text.isEmpty ||
                      keyController.text ==
                          generateProjectKey(
                            nameController.text.substring(
                              0,
                              nameController.text.length > 1
                                  ? nameController.text.length - 1
                                  : 0,
                            ),
                          )) {
                    keyController.text = generateProjectKey(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Project Key',
                  hintText: 'e.g., MA',
                  helperText: 'Used for task IDs (e.g., MA-1, MA-2)',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 5,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                'Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((colorHex) {
                  final color = parseColor(colorHex);
                  final isSelected = selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = colorHex;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
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
              if (nameController.text.isNotEmpty &&
                  keyController.text.isNotEmpty) {
                context.read<TaskService>().addProject(
                      nameController.text,
                      keyController.text,
                      description: descController.text.isNotEmpty
                          ? descController.text
                          : null,
                      color: selectedColor,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

/// Shows a project menu with edit, archive/unarchive, and delete options
void showProjectMenu(BuildContext context, Project project) {
  final taskService = context.read<TaskService>();

  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Project'),
          onTap: () {
            Navigator.pop(context);
            showEditProjectDialog(context, project);
          },
        ),
        if (project.isArchived)
          ListTile(
            leading: const Icon(Icons.unarchive),
            title: const Text('Restore Project'),
            onTap: () {
              Navigator.pop(context);
              project.isArchived = false;
              taskService.updateProject(project);
            },
          )
        else
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Archive Project'),
            onTap: () {
              Navigator.pop(context);
              taskService.archiveProject(project.id);
            },
          ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text(
            'Delete Project',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () {
            Navigator.pop(context);
            confirmDeleteProject(context, project);
          },
        ),
      ],
    ),
  );
}

/// Shows project settings menu
void showProjectSettings(BuildContext context, Project project) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Project'),
          onTap: () {
            Navigator.pop(context);
            showEditProjectDialog(context, project);
          },
        ),
        ListTile(
          leading: const Icon(Icons.archive),
          title: const Text('Archive Project'),
          onTap: () {
            Navigator.pop(context);
            context.read<TaskService>().archiveProject(project.id);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text(
            'Delete Project',
            style: TextStyle(color: Colors.red),
          ),
          subtitle: const Text('This will delete all tasks in this project'),
          onTap: () {
            Navigator.pop(context);
            confirmDeleteProject(context, project);
          },
        ),
      ],
    ),
  );
}

/// Shows a dialog to edit an existing project
void showEditProjectDialog(BuildContext context, Project project) {
  final TextEditingController nameController =
      TextEditingController(text: project.name);
  final TextEditingController keyController =
      TextEditingController(text: project.key);
  final TextEditingController descController =
      TextEditingController(text: project.description ?? '');
  String selectedColor = project.color;

  final colors = [
    '#4A90E2',
    '#50C878',
    '#FF6B6B',
    '#FFB347',
    '#9B59B6',
    '#3498DB',
    '#1ABC9C',
    '#E74C3C',
    '#F39C12',
    '#8E44AD',
  ];

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Project'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Project Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Project Key',
                  helperText: 'Changing the key affects new task IDs only',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 5,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text(
                'Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((colorHex) {
                  final color = parseColor(colorHex);
                  final isSelected = selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = colorHex;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
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
              if (nameController.text.isNotEmpty &&
                  keyController.text.isNotEmpty) {
                project.name = nameController.text;
                project.key = keyController.text.toUpperCase();
                project.description = descController.text.isNotEmpty
                    ? descController.text
                    : null;
                project.color = selectedColor;
                context.read<TaskService>().updateProject(project);
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

/// Shows a confirmation dialog before deleting a project
void confirmDeleteProject(BuildContext context, Project project) {
  final taskCount =
      context.read<TaskService>().getTasksForProject(project.id).length;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Project?'),
      content: Text(
        'Are you sure you want to delete "${project.name}"? '
        '${taskCount > 0 ? 'This will also delete $taskCount task${taskCount > 1 ? 's' : ''} in this project. ' : ''}'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<TaskService>().deleteProject(project.id);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
