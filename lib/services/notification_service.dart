import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _checkTimer;
  bool _isInitialized = false;
  bool _notificationsEnabled = true;

  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();

      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        linux: linuxSettings,
        macOS: darwinSettings,
        iOS: darwinSettings,
      );

      await _notifications.initialize(initSettings);

      // Load preferences
      final settingsBox = await Hive.openBox('settings');
      _notificationsEnabled =
          settingsBox.get('notifications_enabled', defaultValue: true);

      _isInitialized = true;

      if (_notificationsEnabled) {
        _startPeriodicCheck();
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize notification service',
        name: 'NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final settingsBox = Hive.box('settings');
    await settingsBox.put('notifications_enabled', enabled);

    if (enabled) {
      _startPeriodicCheck();
    } else {
      _stopPeriodicCheck();
      await _notifications.cancelAll();
    }
    notifyListeners();
  }

  void _startPeriodicCheck() {
    _stopPeriodicCheck();
    // Check every 15 minutes for upcoming/overdue tasks
    _checkTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => checkDueDates(),
    );
    // Also check immediately on start
    checkDueDates();
  }

  void _stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> checkDueDates() async {
    if (!_isInitialized || !_notificationsEnabled) return;

    try {
      final taskBox = Hive.box<Task>('tasks');
      final tasks = taskBox.values.toList();
      final now = DateTime.now();

      for (final task in tasks) {
        if (task.dueDate == null) continue;
        if (task.status == TaskStatus.done) continue;

        final dueDate = task.dueDate!;
        final difference = dueDate.difference(now);

        if (_isOverdue(dueDate, now)) {
          await _showNotification(
            id: task.id.hashCode,
            title: 'Task Overdue',
            body: '${task.taskKey != null ? "[${task.taskKey}] " : ""}'
                '${task.title} was due ${formatDueDistance(difference)}',
          );
        } else if (difference.inHours <= 1 && difference.inMinutes > 0) {
          await _showNotification(
            id: task.id.hashCode,
            title: 'Task Due Soon',
            body: '${task.taskKey != null ? "[${task.taskKey}] " : ""}'
                '${task.title} is due in ${difference.inMinutes} minutes',
          );
        } else if (_isDueToday(dueDate, now) && now.hour >= 9) {
          // Notify once in the morning for tasks due today
          await _showNotification(
            id: task.id.hashCode + 1,
            title: 'Task Due Today',
            body: '${task.taskKey != null ? "[${task.taskKey}] " : ""}'
                '${task.title}',
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to check due dates',
        name: 'NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (!_isInitialized || !_notificationsEnabled) return;
    if (task.dueDate == null) return;

    // Schedule notification for the due date
    final scheduledDate = tz.TZDateTime.from(task.dueDate!, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (scheduledDate.isBefore(now)) return;

    try {
      await _notifications.zonedSchedule(
        task.id.hashCode,
        'Task Due',
        '${task.taskKey != null ? "[${task.taskKey}] " : ""}${task.title}',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to schedule reminder for task: ${task.id}',
        name: 'NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!_isInitialized) return;
    await _notifications.cancel(taskId.hashCode);
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _notifications.show(id, title, body, _notificationDetails());
    } catch (e, stackTrace) {
      developer.log(
        'Failed to show notification',
        name: 'NotificationService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  NotificationDetails _notificationDetails() {
    const linux = LinuxNotificationDetails();
    const darwin = DarwinNotificationDetails();

    return const NotificationDetails(
      linux: linux,
      macOS: darwin,
      iOS: darwin,
    );
  }

  bool _isOverdue(DateTime dueDate, DateTime now) {
    return dueDate.isBefore(now);
  }

  bool _isDueToday(DateTime dueDate, DateTime now) {
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  @override
  void dispose() {
    _stopPeriodicCheck();
    super.dispose();
  }
}

String formatDueDistance(Duration difference) {
  final absDiff = difference.abs();
  if (absDiff.inDays > 0) {
    return '${absDiff.inDays} day${absDiff.inDays == 1 ? '' : 's'} ago';
  } else if (absDiff.inHours > 0) {
    return '${absDiff.inHours} hour${absDiff.inHours == 1 ? '' : 's'} ago';
  }
  return '${absDiff.inMinutes} minute${absDiff.inMinutes == 1 ? '' : 's'} ago';
}
