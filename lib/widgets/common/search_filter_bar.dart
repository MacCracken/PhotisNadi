import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/task_service.dart';
import '../../models/task.dart';
import '../../common/utils.dart';

class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({super.key});

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = context.watch<TaskService>();
    final hasFilters = taskService.hasActiveFilters;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search tasks... (Ctrl+K)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            taskService.setSearchQuery('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: taskService.setSearchQuery,
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: hasFilters,
              child: IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_list_off : Icons.filter_list,
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                tooltip: 'Filters',
              ),
            ),
          ],
        ),
        if (_showFilters) ...[
          const SizedBox(height: 12),
          _buildFilters(taskService),
        ],
      ],
    );
  }

  Widget _buildFilters(TaskService taskService) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (taskService.hasActiveFilters)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    taskService.clearFilters();
                  },
                  child: const Text('Clear all'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusFilter(taskService),
              _buildPriorityFilter(taskService),
              _buildSortByDropdown(taskService),
            ],
          ),
          const SizedBox(height: 12),
          _buildTagFilters(taskService),
          const SizedBox(height: 12),
          _buildDueDateFilters(taskService),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(TaskService taskService) {
    return DropdownButton<TaskStatus?>(
      value: taskService.filterStatus,
      hint: const Text('Status'),
      underline: const SizedBox(),
      items: [
        const DropdownMenuItem<TaskStatus?>(
          value: null,
          child: Text('All Statuses'),
        ),
        ...TaskStatus.values.map((status) => DropdownMenuItem(
              value: status,
              child: Text(_statusLabel(status)),
            )),
      ],
      onChanged: (value) => taskService.setFilterStatus(value),
    );
  }

  Widget _buildPriorityFilter(TaskService taskService) {
    return DropdownButton<TaskPriority?>(
      value: taskService.filterPriority,
      hint: const Text('Priority'),
      underline: const SizedBox(),
      items: [
        const DropdownMenuItem<TaskPriority?>(
          value: null,
          child: Text('All Priorities'),
        ),
        ...TaskPriority.values.map((priority) => DropdownMenuItem(
              value: priority,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_priorityLabel(priority)),
                ],
              ),
            )),
      ],
      onChanged: (value) => taskService.setFilterPriority(value),
    );
  }

  Widget _buildSortByDropdown(TaskService taskService) {
    return DropdownButton<TaskSortBy>(
      value: taskService.sortBy,
      hint: const Text('Sort by'),
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(
          value: TaskSortBy.createdAt,
          child: Text('Created Date'),
        ),
        DropdownMenuItem(
          value: TaskSortBy.dueDate,
          child: Text('Due Date'),
        ),
        DropdownMenuItem(
          value: TaskSortBy.priority,
          child: Text('Priority'),
        ),
        DropdownMenuItem(
          value: TaskSortBy.title,
          child: Text('Title'),
        ),
      ],
      onChanged: (value) {
        if (value != null) taskService.setSortBy(value);
      },
    );
  }

  Widget _buildTagFilters(TaskService taskService) {
    final projectId = taskService.selectedProjectId;
    if (projectId == null) return const SizedBox.shrink();

    final projectTags = taskService.getTagsForProject(projectId);
    if (projectTags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Tags: ', style: TextStyle(fontSize: 12)),
            if (taskService.filterTags.isNotEmpty)
              TextButton(
                onPressed: () => taskService.clearFilterTags(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: projectTags.map((tag) {
            final isSelected = taskService.filterTags.contains(tag.name);
            final tagColor = parseColor(tag.color);
            return FilterChip(
              label: Text(tag.name, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              selectedColor: tagColor.withValues(alpha: 0.3),
              checkmarkColor: tagColor,
              onSelected: (_) => taskService.toggleFilterTag(tag.name),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDueDateFilters(TaskService taskService) {
    return Row(
      children: [
        const Text('Due: ', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        _buildDateChip(
          'Today',
          taskService.filterDueAfter != null &&
              _isSameDay(taskService.filterDueAfter!, DateTime.now()) &&
              taskService.filterDueBefore != null &&
              _isSameDay(taskService.filterDueBefore!, DateTime.now()),
          () => taskService.setFilterDueAfter(DateTime.now()),
        ),
        const SizedBox(width: 4),
        _buildDateChip(
          'This Week',
          false,
          () {
            final now = DateTime.now();
            final weekEnd = now.add(Duration(days: 7 - now.weekday));
            taskService.setFilterDueAfter(now);
            taskService.setFilterDueBefore(weekEnd);
          },
        ),
        const SizedBox(width: 4),
        _buildDateChip(
          'Overdue',
          taskService.filterDueBefore != null &&
              taskService.filterDueBefore!.isBefore(DateTime.now()),
          () => taskService.setFilterDueBefore(DateTime.now()),
        ),
      ],
    );
  }

  Widget _buildDateChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _statusLabel(TaskStatus status) {
    return switch (status) {
      TaskStatus.todo => 'To Do',
      TaskStatus.inProgress => 'In Progress',
      TaskStatus.inReview => 'In Review',
      TaskStatus.blocked => 'Blocked',
      TaskStatus.done => 'Done',
    };
  }

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };
  }

  Color _getPriorityColor(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.low => Colors.green,
      TaskPriority.medium => Colors.orange,
      TaskPriority.high => Colors.red,
    };
  }
}
