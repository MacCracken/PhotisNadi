import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../common/utils.dart';
import '../dialogs/task_dialogs.dart';
import '../dialogs/tag_dialogs.dart';
import '../dialogs/project_dialogs.dart';
import 'search_filter_bar.dart';
import 'column_widgets.dart';

class ProjectHeader extends StatelessWidget {
  final Project? project;
  final VoidCallback? onAddColumn;
  final VoidCallback? onAddTask;
  final VoidCallback? onSettings;

  const ProjectHeader({
    super.key,
    this.project,
    this.onAddColumn,
    this.onAddTask,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    Color? projectColor;
    if (project != null) {
      projectColor = parseColor(project!.color);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project!.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        project!.projectKey,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
                  onPressed: onAddColumn ??
                      () => showAddColumnDialog(context, project!),
                  icon: const Icon(Icons.view_column),
                  tooltip: 'Add Column',
                ),
                IconButton(
                  onPressed: onAddTask ?? () => showAddTaskDialog(context),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Task',
                ),
                IconButton(
                  onPressed: () => showTagManagementDialog(context),
                  icon: const Icon(Icons.label),
                  tooltip: 'Manage Tags',
                ),
                IconButton(
                  onPressed: onSettings ??
                      () => showProjectSettings(context, project!),
                  icon: const Icon(Icons.settings),
                  tooltip: 'Project Settings',
                ),
              ],
            ],
          ),
          if (project != null) ...[
            const SizedBox(height: 12),
            const SearchFilterBar(),
          ],
        ],
      ),
    );
  }
}
