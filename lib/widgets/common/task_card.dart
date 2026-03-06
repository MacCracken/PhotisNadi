import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../common/utils.dart';
import '../../common/constants.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isDragging;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onLongPress,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = getPriorityColor(task.priority);
    final taskService = context.watch<TaskService>();
    final isBlocked = taskService.isTaskBlocked(task);
    final hasDependencies = task.dependsOn.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.cardMarginHorizontal,
        vertical: AppConstants.cardMarginVertical,
      ),
      elevation:
          isDragging ? AppConstants.elevationHigh : AppConstants.elevationLow,
      shape: isBlocked
          ? RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.cardBorderRadius),
              side: BorderSide(color: Colors.red.shade300, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(task, priorityColor, isBlocked, hasDependencies),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              if (task.description != null) ...[
                const SizedBox(height: AppConstants.tinyPadding),
                Text(
                  task.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: AppConstants.descriptionMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (task.tags.isNotEmpty) ...[
                const SizedBox(height: AppConstants.smallPadding),
                _buildTags(task.tags, taskService),
              ],
              if (task.dueDate != null) ...[
                const SizedBox(height: AppConstants.smallPadding),
                _buildDueDate(task.dueDate!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      Task task, Color priorityColor, bool isBlocked, bool hasDependencies) {
    return Row(
      children: [
        if (task.taskKey != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: AppConstants.tinyPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
            ),
            child: Text(
              task.taskKey!,
              style: TextStyle(
                fontSize: AppConstants.taskKeyFontSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.smallPadding),
        ],
        if (hasDependencies) ...[
          Icon(
            isBlocked ? Icons.block : Icons.link,
            size: 14,
            color: isBlocked ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 4),
        ],
        const Spacer(),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: priorityColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildTags(List<String> tags, TaskService taskService) {
    return Wrap(
      spacing: AppConstants.tinyPadding,
      runSpacing: AppConstants.tinyPadding,
      children: tags.map((tagName) {
        final tagDef = task.projectId != null
            ? taskService.getTagByName(tagName, task.projectId!)
            : null;
        final tagColor =
            tagDef != null ? parseColor(tagDef.color) : Colors.blue;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: AppConstants.tinyPadding,
          ),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          ),
          child: Text(
            tagName,
            style: TextStyle(
              fontSize: 10,
              color: tagColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final isOverdue = dueDate.isBefore(now) && task.status != TaskStatus.done;
    final isDueToday = dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day &&
        task.status != TaskStatus.done;
    final isDueTomorrow = !isDueToday &&
        dueDate.difference(DateTime(now.year, now.month, now.day)).inDays ==
            1 &&
        task.status != TaskStatus.done;

    Color dateColor;
    IconData dateIcon;
    String label;

    if (isOverdue) {
      dateColor = Colors.red;
      dateIcon = Icons.warning_amber;
      final days = now.difference(dueDate).inDays;
      label = days == 0
          ? 'Overdue'
          : 'Overdue by $days day${days == 1 ? '' : 's'}';
    } else if (isDueToday) {
      dateColor = Colors.orange;
      dateIcon = Icons.schedule;
      label = 'Due today';
    } else if (isDueTomorrow) {
      dateColor = Colors.amber.shade700;
      dateIcon = Icons.calendar_today;
      label = 'Due tomorrow';
    } else {
      dateColor = Colors.grey.shade500;
      dateIcon = Icons.calendar_today;
      label = formatDate(dueDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: (isOverdue || isDueToday)
          ? BoxDecoration(
              color: dateColor.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(dateIcon, size: AppConstants.iconSizeSmall, color: dateColor),
          const SizedBox(width: AppConstants.tinyPadding),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: dateColor,
              fontWeight: (isOverdue || isDueToday)
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
