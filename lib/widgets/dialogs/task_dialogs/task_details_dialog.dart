import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../common/platform_utils.dart';
import '../../../models/task.dart';
import '../../../services/task_service.dart';
import '../../../common/utils.dart';
import '_helpers.dart';
import 'edit_task_dialog.dart';

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
                buildDetailRow('Priority', formatPriority(task.priority)),
                buildDetailRow('Status', formatStatus(task.status)),
                if (task.dueDate != null)
                  buildDetailRow('Due', formatDate(task.dueDate!)),
                if (task.recurrence != null)
                  buildDetailRow('Recurs', task.recurrence!),
                if (task.estimatedMinutes != null || task.trackedMinutes > 0)
                  buildDetailRow(
                    'Time',
                    task.estimatedMinutes != null
                        ? '${task.formattedTrackedTime} / ${formatMin(task.estimatedMinutes!)}'
                        : task.formattedTrackedTime,
                  ),
                buildDetailRow('Created', formatDate(task.createdAt)),
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
                        if (context.mounted) setDialogState(() {});
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
                        leading: const Icon(Icons.insert_drive_file, size: 18),
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
