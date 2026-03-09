import 'package:flutter/material.dart';
import '../models/task.dart';

// Re-export pure Dart validators so existing imports keep working.
export 'validators.dart';

/// Parses a hex color string to a Color object
Color parseColor(String colorHex) {
  try {
    String normalized = colorHex.trim().toUpperCase();
    if (!normalized.startsWith('#')) {
      normalized = '#$normalized';
    }
    return Color(int.parse(normalized.replaceFirst('#', '0x')));
  } on FormatException {
    return Colors.blue;
  }
}

/// Formats a DateTime to a string (DD/MM/YYYY)
String formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// Formats a TaskPriority to a display string
String formatPriority(TaskPriority priority) {
  final name = priority.name;
  if (name.isEmpty) return name;
  return name[0].toUpperCase() + name.substring(1);
}

/// Formats a TaskStatus to a display string
String formatStatus(TaskStatus status) {
  final name = status.name.replaceAll('_', ' ');
  if (name.isEmpty) return name;
  return name[0].toUpperCase() + name.substring(1);
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
