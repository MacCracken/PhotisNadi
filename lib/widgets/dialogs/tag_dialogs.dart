import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tag.dart';
import '../../services/task_service.dart';
import '../../common/utils.dart';

const _tagColors = [
  '#E53935', // Red
  '#D81B60', // Pink
  '#8E24AA', // Purple
  '#5E35B1', // Deep Purple
  '#3949AB', // Indigo
  '#1E88E5', // Blue
  '#039BE5', // Light Blue
  '#00ACC1', // Cyan
  '#00897B', // Teal
  '#43A047', // Green
  '#7CB342', // Light Green
  '#F9A825', // Yellow
  '#FB8C00', // Orange
  '#6D4C41', // Brown
  '#546E7A', // Blue Grey
];

/// Shows a dialog to manage tags for the current project
void showTagManagementDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _TagManagementDialog(),
  );
}

class _TagManagementDialog extends StatefulWidget {
  const _TagManagementDialog();

  @override
  State<_TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends State<_TagManagementDialog> {
  @override
  Widget build(BuildContext context) {
    final taskService = context.watch<TaskService>();
    final projectId = taskService.selectedProjectId;
    if (projectId == null) {
      return AlertDialog(
        title: const Text('Manage Tags'),
        content: const Text('No project selected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final tags = taskService.getTagsForProject(projectId);

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Manage Tags')),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add tag',
            onPressed: () => _showAddTagDialog(context, projectId),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: tags.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No tags yet. Tap + to create one.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  final tagColor = parseColor(tag.color);
                  return ListTile(
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: tagColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(tag.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () =>
                              _showEditTagDialog(context, tag, projectId),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                          onPressed: () => _confirmDeleteTag(context, tag),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _showAddTagDialog(BuildContext context, String projectId) {
    final nameController = TextEditingController();
    var selectedColor = _tagColors[5]; // Default blue

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tag name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tagColors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedColor = color);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: parseColor(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: parseColor(color).withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final taskService = context.read<TaskService>();
                  final result = await taskService.addTag(
                    nameController.text.trim(),
                    selectedColor,
                    projectId,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  if (result == null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tag name already exists'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTagDialog(
    BuildContext context,
    Tag tag,
    String projectId,
  ) {
    final nameController = TextEditingController(text: tag.name);
    var selectedColor = tag.color;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tag name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tagColors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedColor = color);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: parseColor(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: parseColor(color).withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final taskService = context.read<TaskService>();
                  final updatedTag = tag.copyWith(
                    name: nameController.text.trim(),
                    color: selectedColor,
                  );
                  await taskService.updateTag(updatedTag);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTag(BuildContext context, Tag tag) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text(
          'Delete "${tag.name}"? It will be removed from all tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskService>().deleteTag(tag.id);
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
