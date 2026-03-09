import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../common/platform_utils.dart';
import '../../models/tag.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../common/utils.dart';

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
                _buildDueDatePicker(
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
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  taskService.addTask(
                    titleController.text,
                    description: descController.text.isNotEmpty
                        ? descController.text
                        : null,
                    priority: selectedPriority,
                    tags: selectedTags.toList(),
                    dueDate: selectedDueDate,
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
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final taskService = context.read<TaskService>();
        final subtasks = task.parsedSubtasks;

        return AlertDialog(
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description != null) ...[
                  MarkdownBody(
                    data: task.description!,
                    selectable: true,
                    shrinkWrap: true,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildDetailRow('Priority', formatPriority(task.priority)),
                _buildDetailRow('Status', formatStatus(task.status)),
                if (task.dueDate != null)
                  _buildDetailRow('Due', formatDate(task.dueDate!)),
                if (task.recurrence != null)
                  _buildDetailRow('Recurs', task.recurrence!),
                if (task.estimatedMinutes != null || task.trackedMinutes > 0)
                  _buildDetailRow(
                    'Time',
                    task.estimatedMinutes != null
                        ? '${task.formattedTrackedTime} / ${_formatMin(task.estimatedMinutes!)}'
                        : task.formattedTrackedTime,
                  ),
                _buildDetailRow('Created', formatDate(task.createdAt)),
                if (subtasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Subtasks (${task.subtasksDone}/${subtasks.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(subtasks.length, (i) {
                    final st = subtasks[i];
                    return CheckboxListTile(
                      value: st.done,
                      title: Text(
                        st.title,
                        style: TextStyle(
                          decoration:
                              st.done ? TextDecoration.lineThrough : null,
                          color: st.done ? Colors.grey : null,
                        ),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (_) async {
                        await taskService.toggleSubtask(task.id, i);
                        setDialogState(() {});
                      },
                    );
                  }),
                ],
                if (task.attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Attachments (${task.attachments.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ...task.attachments.map((path) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.insert_drive_file, size: 18),
                        title: Text(
                          p.basename(path),
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => openFile(path),
                      )),
                ],
              ],
            ),
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
        );
      },
    ),
  );
}

String _formatMin(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
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
                _buildDueDatePicker(
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
                        await taskService.removeTaskDependency(task.id, dep.id);
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
                onChanged: (value) async {
                  if (value != null) {
                    final added = await taskService.addTaskDependency(task.id, value);
                    if (!added && context.mounted) {
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
                          decoration: st.done ? TextDecoration.lineThrough : null,
                          color: st.done ? Colors.grey : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () async {
                        await taskService.removeSubtask(task.id, i);
                        setDialogState(() {});
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
                          setDialogState(() {});
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
                        setDialogState(() {});
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
                      if (result != null && result.files.single.path != null) {
                        await taskService.addAttachment(
                          task.id,
                          result.files.single.path!,
                        );
                        setDialogState(() {});
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
                        setDialogState(() {});
                      },
                    ),
                    onTap: () {
                      // Open file with system default
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
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                task.title = titleController.text;
                task.description =
                    descController.text.isNotEmpty ? descController.text : null;
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

Widget _buildDueDatePicker(
  BuildContext context,
  DateTime? selectedDate,
  ValueChanged<DateTime?> onChanged,
) {
  return Row(
    children: [
      Expanded(
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Due Date',
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              selectedDate != null
                  ? formatDate(selectedDate)
                  : 'No due date',
              style: TextStyle(
                color: selectedDate != null ? null : Colors.grey,
              ),
            ),
          ),
        ),
      ),
      if (selectedDate != null)
        IconButton(
          icon: const Icon(Icons.clear, size: 18),
          tooltip: 'Remove due date',
          onPressed: () => onChanged(null),
        ),
    ],
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
