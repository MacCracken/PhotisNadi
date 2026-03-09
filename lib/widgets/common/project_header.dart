import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/project.dart';
import '../../common/utils.dart';
import '../../services/task_service.dart';
import '../../services/export_import_service.dart';
import '../dialogs/task_dialogs.dart';
import '../dialogs/tag_dialogs.dart';
import '../dialogs/project_dialogs.dart';
import '../dialogs/board_dialogs.dart';
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

  void _showExportDialog(BuildContext context) {
    final taskService = context.read<TaskService>();

    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Export'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _doExport(
                context,
                'project.json',
                ExportImportService.exportProjectJson(taskService, project!.id),
              );
            },
            child: const Text('Export Project as JSON'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _doExport(
                context,
                'tasks.csv',
                ExportImportService.exportTasksCsv(taskService, projectId: project!.id),
              );
            },
            child: const Text('Export Project Tasks as CSV'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _doExport(
                context,
                'photisnadi_export.json',
                ExportImportService.exportAllJson(taskService),
              );
            },
            child: const Text('Export All Data as JSON'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _doImport(context, taskService);
            },
            child: const Text('Import from JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(BuildContext context, String defaultName, String content) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Export',
        fileName: defaultName,
      );
      if (path != null && !kIsWeb) {
        await File(path).writeAsString(content);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $path')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _doImport(BuildContext context, TaskService service) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        final content = await File(result.files.single.path!).readAsString();
        final summary = await ExportImportService.importJson(service, content);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(summary.toString())),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
                  onPressed: () => _showExportDialog(context),
                  icon: const Icon(Icons.download),
                  tooltip: 'Export / Import',
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
            const SizedBox(height: 8),
            _BoardSelector(project: project!),
            const SizedBox(height: 8),
            const SearchFilterBar(),
          ],
        ],
      ),
    );
  }
}

class _BoardSelector extends StatelessWidget {
  final Project project;

  const _BoardSelector({required this.project});

  @override
  Widget build(BuildContext context) {
    final taskService = context.watch<TaskService>();
    final boards = project.boards;
    final activeBoard = project.activeBoard;

    if (boards.length <= 1 && boards.isNotEmpty) {
      // Single board — just show name with add button
      return Row(
        children: [
          Chip(
            label: Text(boards.first.title,
                style: const TextStyle(fontSize: 12)),
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => showAddBoardDialog(context, project),
            icon: const Icon(Icons.add, size: 16),
            tooltip: 'Add Board',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final board in boards)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onLongPress: () =>
                    showEditBoardDialog(context, project, board),
                child: ChoiceChip(
                  label: Text(board.title,
                      style: const TextStyle(fontSize: 12)),
                  selected: board.id == activeBoard?.id,
                  onSelected: (_) => taskService.selectBoard(board.id),
                ),
              ),
            ),
          IconButton(
            onPressed: () => showAddBoardDialog(context, project),
            icon: const Icon(Icons.add, size: 16),
            tooltip: 'Add Board',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
