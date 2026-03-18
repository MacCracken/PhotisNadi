import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/tag.dart';
import '../../../models/task.dart';
import '../../../services/task_service.dart';
import '../../../common/utils.dart';
import '_helpers.dart';

/// Shows a dialog to add a new task
void showAddTaskDialog(BuildContext context, {String? columnId}) {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  TaskPriority selectedPriority = TaskPriority.medium;
  DateTime? selectedDueDate;
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
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Supports Markdown',
                  ),
                  maxLines: 5,
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
                const SizedBox(height: 16),
                buildDueDatePicker(
                  context,
                  selectedDueDate,
                  (date) => setDialogState(() => selectedDueDate = date),
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
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final result = await taskService.addTask(
                    titleController.text,
                    description: descController.text.isNotEmpty
                        ? descController.text
                        : null,
                    priority: selectedPriority,
                    tags: selectedTags.toList(),
                    dueDate: selectedDueDate,
                  );
                  if (context.mounted) {
                    if (result != null) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to add task'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ),
  ).then((_) {
    titleController.dispose();
    descController.dispose();
  });
}
