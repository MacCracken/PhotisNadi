import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../common/platform_utils.dart';
import '../../../models/tag.dart';
import '../../../models/task.dart';
import '../../../services/task_service.dart';
import '../../../common/utils.dart';
import '_helpers.dart';

/// Shows a dialog to edit an existing task
void showEditTaskDialog(BuildContext context, Task task) {
  final TextEditingController titleController =
      TextEditingController(text: task.title);
  final TextEditingController descController =
      TextEditingController(text: task.description ?? '');
  final TextEditingController subtaskController = TextEditingController();
  final TextEditingController estimateController =
      TextEditingController(text: task.estimatedMinutes?.toString() ?? '');
  final TextEditingController logTimeController = TextEditingController();
  TaskPriority selectedPriority = task.priority;
  TaskStatus selectedStatus = task.status;
  DateTime? selectedDueDate = task.dueDate;
  String? selectedRecurrence = task.recurrence;
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
                const SizedBox(height: 16),
                buildDueDatePicker(
                  context,
                  selectedDueDate,
                  (date) => setDialogState(() => selectedDueDate = date),
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
                        onDeleted: () async {
                          await taskService.removeTaskDependency(
                              task.id, dep.id);
                          if (context.mounted) setDialogState(() {});
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
                  onChanged: (value) async {
                    if (value != null) {
                      final added =
                          await taskService.addTaskDependency(task.id, value);
                      if (!added && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Cannot add: would create circular dependency'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      if (context.mounted) setDialogState(() {});
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
                        Icon(Icons.warning,
                            color: Colors.red.shade700, size: 18),
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
                // ── Subtasks ──
                const SizedBox(height: 16),
                const Text(
                  'Subtasks',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...List.generate(task.subtasks.length, (i) {
                  final st = task.parsedSubtasks[i];
                  return Row(
                    children: [
                      Checkbox(
                        value: st.done,
                        onChanged: (_) async {
                          await taskService.toggleSubtask(task.id, i);
                          setDialogState(() {});
                        },
                      ),
                      Expanded(
                        child: Text(
                          st.title,
                          style: TextStyle(
                            decoration:
                                st.done ? TextDecoration.lineThrough : null,
                            color: st.done ? Colors.grey : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          await taskService.removeSubtask(task.id, i);
                          if (context.mounted) setDialogState(() {});
                        },
                      ),
                    ],
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: subtaskController,
                        decoration: const InputDecoration(
                          hintText: 'Add subtask',
                          isDense: true,
                        ),
                        onSubmitted: (value) async {
                          if (value.trim().isNotEmpty) {
                            await taskService.addSubtask(task.id, value.trim());
                            subtaskController.clear();
                            if (context.mounted) setDialogState(() {});
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () async {
                        if (subtaskController.text.trim().isNotEmpty) {
                          await taskService.addSubtask(
                              task.id, subtaskController.text.trim());
                          subtaskController.clear();
                          if (context.mounted) setDialogState(() {});
                        }
                      },
                    ),
                  ],
                ),
                // ── Time Tracking ──
                const SizedBox(height: 16),
                const Text(
                  'Time Tracking',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: estimateController,
                        decoration: const InputDecoration(
                          labelText: 'Estimate (minutes)',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: logTimeController,
                        decoration: InputDecoration(
                          labelText: 'Log time (min)',
                          isDense: true,
                          hintText: 'Tracked: ${task.formattedTrackedTime}',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                // ── Recurrence ──
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: selectedRecurrence,
                  decoration: const InputDecoration(
                    labelText: 'Recurrence',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedRecurrence = value);
                  },
                ),
                // ── Attachments ──
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Attachments',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: const Text('Add'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles();
                        if (result != null &&
                            result.files.single.path != null) {
                          await taskService.addAttachment(
                            task.id,
                            result.files.single.path!,
                          );
                          if (context.mounted) setDialogState(() {});
                        }
                      },
                    ),
                  ],
                ),
                if (task.attachments.isNotEmpty)
                  ...List.generate(task.attachments.length, (i) {
                    final path = task.attachments[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file, size: 18),
                      title: Text(
                        p.basename(path),
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          await taskService.removeAttachment(task.id, i);
                          if (context.mounted) setDialogState(() {});
                        },
                      ),
                      onTap: () {
                        openFile(path);
                      },
                    );
                  }),
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
                  task.title = titleController.text;
                  task.description = descController.text.isNotEmpty
                      ? descController.text
                      : null;
                  task.priority = selectedPriority;
                  task.status = selectedStatus;
                  task.dueDate = selectedDueDate;
                  task.tags = selectedTags.toList();
                  task.recurrence = selectedRecurrence;
                  // Update estimate
                  final est = int.tryParse(estimateController.text);
                  task.estimatedMinutes = est != null && est > 0 ? est : null;
                  // Log additional time
                  final logMin = int.tryParse(logTimeController.text);
                  if (logMin != null && logMin > 0) {
                    task.trackedMinutes += logMin;
                  }
                  final success =
                      await context.read<TaskService>().updateTask(task);
                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to save task'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  ).then((_) {
    titleController.dispose();
    descController.dispose();
    subtaskController.dispose();
    estimateController.dispose();
    logTimeController.dispose();
  });
}
