import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/board.dart';
import '../../models/project.dart';
import '../../services/task_service.dart';

void showAddBoardDialog(BuildContext context, Project project) {
  final nameController = TextEditingController();
  String? selectedTemplate;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Board Name'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Template (optional)',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Default'),
                  selected: selectedTemplate == 'default',
                  onSelected: (v) =>
                      setState(() => selectedTemplate = v ? 'default' : null),
                ),
                ChoiceChip(
                  label: const Text('Bug Tracking'),
                  selected: selectedTemplate == 'bug',
                  onSelected: (v) =>
                      setState(() => selectedTemplate = v ? 'bug' : null),
                ),
                ChoiceChip(
                  label: const Text('Sprint'),
                  selected: selectedTemplate == 'sprint',
                  onSelected: (v) =>
                      setState(() => selectedTemplate = v ? 'sprint' : null),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              const uuid = Uuid();
              final id = uuid.v4();

              Board board;
              switch (selectedTemplate) {
                case 'bug':
                  board = Board.bugTrackingBoard(id);
                  board.title = nameController.text.trim();
                case 'sprint':
                  board = Board.sprintBoard(id);
                  board.title = nameController.text.trim();
                default:
                  board = Board.defaultBoard(id);
                  board.title = nameController.text.trim();
              }

              context.read<TaskService>().addBoard(project.id, board);
              Navigator.pop(dialogContext);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  ).then((_) => nameController.dispose());
}

void showEditBoardDialog(BuildContext context, Project project, Board board) {
  final nameController = TextEditingController(text: board.title);

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit Board'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Board Name'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.trim().isEmpty) return;
            final updated = board.copyWith(title: nameController.text.trim());
            context.read<TaskService>().updateBoard(project.id, updated);
            Navigator.pop(dialogContext);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  ).then((_) => nameController.dispose());
}

void showDeleteBoardDialog(BuildContext context, Project project, Board board) {
  if (project.boards.length <= 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot delete the only board')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Board'),
      content: Text('Delete "${board.title}"? Tasks will remain in the project.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            context.read<TaskService>().deleteBoard(project.id, board.id);
            Navigator.pop(dialogContext);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
