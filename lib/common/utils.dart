import 'package:flutter/material.dart';
import '../models/task.dart';

/// Parses a hex color string to a Color object
Color parseColor(String colorHex) {
  try {
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.blue;
  }
}

/// Formats a DateTime to a string (DD/MM/YYYY)
String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

/// Capitalizes the first letter of a string
String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

/// Formats a TaskPriority to a display string
String formatPriority(TaskPriority priority) {
  return capitalizeFirst(priority.name);
}

/// Formats a TaskStatus to a display string
String formatStatus(TaskStatus status) {
  return capitalizeFirst(status.name.replaceAll('_', ' '));
}

/// Gets the color for a task priority
Color getPriorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return Colors.red;
    case TaskPriority.medium:
      return Colors.orange;
    case TaskPriority.low:
      return Colors.green;
  }
}

/// Generates a project key from a project name
String generateProjectKey(String name) {
  if (name.isEmpty) return '';
  final words = name.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    return words[0].substring(0, words[0].length.clamp(0, 3)).toUpperCase();
  }
  return words.map((w) => w[0]).take(3).join().toUpperCase();
}
