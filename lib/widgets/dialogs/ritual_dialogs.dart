import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ritual.dart';
import '../../services/task_service.dart';

/// Shows a dialog to add a new ritual
void showAddRitualDialog(BuildContext context) {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Ritual'),
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
            decoration:
                const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (titleController.text.isNotEmpty) {
              final result = await context.read<TaskService>().addRitual(
                    titleController.text,
                    description: descController.text.isNotEmpty
                        ? descController.text
                        : null,
                  );
              if (context.mounted) {
                if (result != null) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to add ritual'),
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
    ),
  ).then((_) {
    titleController.dispose();
    descController.dispose();
  });
}

/// Shows a dialog to edit an existing ritual
void showEditRitualDialog(BuildContext context, Ritual ritual) {
  final TextEditingController titleController =
      TextEditingController(text: ritual.title);
  final TextEditingController descController =
      TextEditingController(text: ritual.description ?? '');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Ritual'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descController,
            decoration:
                const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (titleController.text.isNotEmpty) {
              final updatedRitual = ritual.copyWith(
                title: titleController.text,
                description:
                    descController.text.isNotEmpty ? descController.text : null,
              );
              final success = await context
                  .read<TaskService>()
                  .updateRitual(updatedRitual);
              if (context.mounted) {
                if (success) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to save ritual'),
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
    ),
  ).then((_) {
    titleController.dispose();
    descController.dispose();
  });
}
