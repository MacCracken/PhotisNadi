import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardShortcuts {
  static final Map<ShortcutActivator, Intent> shortcuts = {
    const SingleActivator(LogicalKeyboardKey.keyN, control: true):
        const AddTaskIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true):
        const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
    // Task navigation
    const SingleActivator(LogicalKeyboardKey.keyJ): const NextTaskIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK): const PrevTaskIntent(),
    const SingleActivator(LogicalKeyboardKey.keyH): const PrevColumnIntent(),
    const SingleActivator(LogicalKeyboardKey.keyL): const NextColumnIntent(),
  };
}

class AddTaskIntent extends Intent {
  const AddTaskIntent();
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class NextTaskIntent extends Intent {
  const NextTaskIntent();
}

class PrevTaskIntent extends Intent {
  const PrevTaskIntent();
}

class NextColumnIntent extends Intent {
  const NextColumnIntent();
}

class PrevColumnIntent extends Intent {
  const PrevColumnIntent();
}

class KeyboardShortcutsWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onAddTask;
  final VoidCallback? onFocusSearch;
  final VoidCallback? onEscape;
  final VoidCallback? onNextTask;
  final VoidCallback? onPrevTask;
  final VoidCallback? onNextColumn;
  final VoidCallback? onPrevColumn;

  const KeyboardShortcutsWrapper({
    super.key,
    required this.child,
    this.onAddTask,
    this.onFocusSearch,
    this.onEscape,
    this.onNextTask,
    this.onPrevTask,
    this.onNextColumn,
    this.onPrevColumn,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: KeyboardShortcuts.shortcuts,
      child: Actions(
        actions: {
          AddTaskIntent: CallbackAction<AddTaskIntent>(
            onInvoke: (_) {
              onAddTask?.call();
              return null;
            },
          ),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (_) {
              onFocusSearch?.call();
              return null;
            },
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (_) {
              onEscape?.call();
              return null;
            },
          ),
          NextTaskIntent: CallbackAction<NextTaskIntent>(
            onInvoke: (_) {
              onNextTask?.call();
              return null;
            },
          ),
          PrevTaskIntent: CallbackAction<PrevTaskIntent>(
            onInvoke: (_) {
              onPrevTask?.call();
              return null;
            },
          ),
          NextColumnIntent: CallbackAction<NextColumnIntent>(
            onInvoke: (_) {
              onNextColumn?.call();
              return null;
            },
          ),
          PrevColumnIntent: CallbackAction<PrevColumnIntent>(
            onInvoke: (_) {
              onPrevColumn?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
