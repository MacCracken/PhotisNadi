import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../services/theme_service.dart';
import '../../common/utils.dart';
import '../../common/constants.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isDragging;
  final FocusNode? focusNode;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onLongPress,
    this.isDragging = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = getPriorityColor(task.priority);
    final taskService = context.watch<TaskService>();
    final themeService = context.watch<ThemeService>();
    final isBlocked = taskService.isTaskBlocked(task);
    final hasDependencies = task.dependsOn.isNotEmpty;
    final compact = themeService.isCompact;

    final marginH = compact
        ? AppConstants.cardMarginHorizontalCompact
        : AppConstants.cardMarginHorizontal;
    final marginV = compact
        ? AppConstants.cardMarginVerticalCompact
        : AppConstants.cardMarginVertical;
    final padding =
        compact ? AppConstants.cardPaddingCompact : AppConstants.cardPadding;
    final descMaxLines = compact
        ? AppConstants.descriptionMaxLinesCompact
        : AppConstants.descriptionMaxLines;
    final titleMaxLines = compact
        ? AppConstants.titleMaxLinesCompact
        : AppConstants.titleMaxLines;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return Card(
            margin: EdgeInsets.symmetric(
              horizontal: marginH,
              vertical: marginV,
            ),
            elevation: isDragging
                ? AppConstants.elevationHigh
                : AppConstants.elevationLow,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.cardBorderRadius),
              side: isBlocked
                  ? BorderSide(color: Colors.red.shade300, width: 2)
                  : isFocused
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : BorderSide.none,
            ),
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius:
                  BorderRadius.circular(AppConstants.cardBorderRadius),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(
                        task, priorityColor, isBlocked, hasDependencies),
                    SizedBox(
                        height: compact
                            ? AppConstants.tinyPadding
                            : AppConstants.smallPadding),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: compact ? 13 : 14,
                      ),
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (task.description != null) ...[
                      const SizedBox(height: AppConstants.tinyPadding),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: descMaxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (task.subtasks.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.tinyPadding),
                      _buildSubtaskProgress(task, compact),
                    ],
                    if (task.trackedMinutes > 0 ||
                        task.estimatedMinutes != null) ...[
                      const SizedBox(height: AppConstants.tinyPadding),
                      _buildTimeIndicator(task, compact),
                    ],
                    if (task.recurrence != null) ...[
                      const SizedBox(height: AppConstants.tinyPadding),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat,
                              size: compact ? 10 : 12,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            task.recurrence!,
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (task.attachments.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.tinyPadding),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file,
                              size: compact ? 10 : 12,
                              color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            '${task.attachments.length}',
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (task.tags.isNotEmpty && !compact) ...[
                      const SizedBox(height: AppConstants.smallPadding),
                      _buildTags(task.tags, taskService),
                    ],
                    if (task.dueDate != null) ...[
                      SizedBox(
                          height: compact
                              ? AppConstants.tinyPadding
                              : AppConstants.smallPadding),
                      _buildDueDate(task.dueDate!),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
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

  Widget _buildSubtaskProgress(Task task, bool compact) {
    final done = task.subtasksDone;
    final total = task.subtasks.length;
    final progress = total > 0 ? done / total : 0.0;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: compact ? 3 : 4,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$done/$total',
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeIndicator(Task task, bool compact) {
    final hasEstimate = task.estimatedMinutes != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined,
            size: compact ? 10 : 12, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(
          hasEstimate
              ? '${task.formattedTrackedTime} / ${_formatMinutes(task.estimatedMinutes!)}'
              : task.formattedTrackedTime,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
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
      label =
          days == 0 ? 'Overdue' : 'Overdue by $days day${days == 1 ? '' : 's'}';
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
