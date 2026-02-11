import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../models/ritual.dart';
import 'dialogs/ritual_dialogs.dart';

class RitualsSidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const RitualsSidebar({
    super.key,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<RitualsSidebar> createState() => _RitualsSidebarState();
}

class _RitualsSidebarState extends State<RitualsSidebar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskService>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskService>(
      builder: (context, taskService, child) {
        final rituals = taskService.rituals;
        final completedCount = rituals.where((r) => r.isCompleted).length;
        final totalCount = rituals.length;
        final completionPercentage = totalCount > 0 ? (completedCount / totalCount) * 100 : 0.0;

        return Container(
          width: widget.isCollapsed ? 60 : 320,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(completedCount, totalCount, completionPercentage),
              Expanded(
                child: widget.isCollapsed
                    ? _buildCollapsedView(rituals)
                    : _buildExpandedView(rituals, taskService),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(int completedCount, int totalCount, double completionPercentage) {
    if (widget.isCollapsed) {
      return Container(
        height: 60,
        child: Stack(
          children: [
            Center(
              child: IconButton(
                onPressed: widget.onToggleCollapse,
                icon: const Icon(Icons.keyboard_double_arrow_right),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 8,
              right: 8,
              child: LinearProgressIndicator(
                value: totalCount > 0 ? completedCount / totalCount : 0,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  completionPercentage == 100 ? Colors.green : Colors.blue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onToggleCollapse,
                icon: const Icon(Icons.keyboard_double_arrow_left),
              ),
              const Expanded(
                child: Text(
                  'Daily Rituals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => showAddRitualDialog(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$completedCount/$totalCount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: totalCount > 0 ? completedCount / totalCount : 0,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completionPercentage == 100 ? Colors.green : Colors.blue,
                  ),
                ),
              ),
              Text(
                '${completionPercentage.toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedView(List<Ritual> rituals) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rituals.length,
      itemBuilder: (context, index) {
        final ritual = rituals[index];
        return Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: GestureDetector(
            onTap: () => context.read<TaskService>().toggleRitualCompletion(ritual.id),
            child: Container(
              decoration: BoxDecoration(
                color: ritual.isCompleted ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ritual.isCompleted ? Colors.green : Colors.grey,
                  width: 1,
                ),
              ),
              child: Icon(
                ritual.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: ritual.isCompleted ? Colors.green : Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedView(List<Ritual> rituals, TaskService taskService) {
    if (rituals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mood,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No rituals yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => showAddRitualDialog(context),
              child: const Text('Add your first ritual'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: rituals.length,
      itemBuilder: (context, index) {
        final ritual = rituals[index];
        return _buildRitualCard(ritual, taskService);
      },
    );
  }

  Widget _buildRitualCard(Ritual ritual, TaskService taskService) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => taskService.toggleRitualCompletion(ritual.id),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ritual.isCompleted ? Colors.green : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: ritual.isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : null,
          ),
        ),
        title: Text(
          ritual.title,
          style: TextStyle(
            decoration: ritual.isCompleted ? TextDecoration.lineThrough : null,
            color: ritual.isCompleted ? Colors.grey : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: ritual.description != null
            ? Text(
                ritual.description!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ritual.streakCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${ritual.streakCount}🔥',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    showEditRitualDialog(context, ritual);
                    break;
                  case 'delete':
                    taskService.deleteRitual(ritual.id);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
