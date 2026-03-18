import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:provider/provider.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/services/task_service.dart';
import 'package:photisnadi/services/theme_service.dart';
import 'package:photisnadi/widgets/common/column_widgets.dart';
import 'package:photisnadi/widgets/common/search_filter_bar.dart';
import 'package:photisnadi/widgets/common/task_card.dart';
import 'package:photisnadi/widgets/common/project_header.dart';
import 'package:photisnadi/widgets/dialogs/task_dialogs.dart';
import 'package:photisnadi/widgets/dialogs/project_dialogs.dart';
import 'package:photisnadi/widgets/dialogs/ritual_dialogs.dart';
import 'package:photisnadi/widgets/dialogs/board_dialogs.dart';
import 'package:photisnadi/widgets/dialogs/tag_dialogs.dart';

bool _adaptersRegistered = false;

void _registerAdapters() {
  if (_adaptersRegistered) return;
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(TaskPriorityAdapter());
  Hive.registerAdapter(RitualAdapter());
  Hive.registerAdapter(RitualFrequencyAdapter());
  Hive.registerAdapter(BoardAdapter());
  Hive.registerAdapter(BoardColumnAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(TagAdapter());
  _adaptersRegistered = true;
}

/// Flush debounced notifyListeners timers so pumpAndSettle doesn't loop.
Future<void> flushDebounce() async {
  await Future.delayed(Duration.zero);
}

/// Pump multiple frames to allow debounced timers, animations, and rebuilds.
/// Uses pump() which advances the clock and processes microtasks/timers.
Future<void> pumpSettled(WidgetTester tester) async {
  // First pump fires the debounce timer, second pump processes the rebuild
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300)); // dialog animation
}

/// Wraps a widget with the required providers for testing.
Widget wrapWithProviders(Widget child, TaskService taskService) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TaskService>.value(value: taskService),
      ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// Wraps a callback that shows a dialog with the required providers.
Widget wrapDialogTrigger(
  TaskService taskService, {
  required void Function(BuildContext) onTap,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TaskService>.value(value: taskService),
      ChangeNotifierProvider<ThemeService>(create: (_) => ThemeService()),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // ── TaskCard Widget Tests ──

  group('TaskCard Widget Tests', () {
    late TaskService taskService;
    late Task testTask;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
      testTask = (await taskService.addTask(
        'Test Task',
        description: 'A description',
        priority: TaskPriority.high,
      ))!;
      await flushDebounce();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('displays task title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        TaskCard(task: testTask, onTap: () {}),
        taskService,
      ));
      await tester.pump();

      expect(find.text('Test Task'), findsOneWidget);
    });

    testWidgets('displays priority dot', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        TaskCard(task: testTask, onTap: () {}),
        taskService,
      ));
      await tester.pump();

      // ExcludeSemantics wraps the priority dot (at least one exists)
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets('displays description when present', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        TaskCard(task: testTask, onTap: () {}),
        taskService,
      ));
      await tester.pump();

      expect(find.text('A description'), findsOneWidget);
    });

    testWidgets('calls onTap callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithProviders(
        TaskCard(task: testTask, onTap: () => tapped = true),
        taskService,
      ));
      await tester.pump();

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('displays task key when present', (tester) async {
      // testTask should have a taskKey from the default project
      if (testTask.taskKey != null) {
        await tester.pumpWidget(wrapWithProviders(
          TaskCard(task: testTask, onTap: () {}),
          taskService,
        ));
        await tester.pump();

        expect(find.text(testTask.taskKey!), findsOneWidget);
      }
    });

    testWidgets('shows due date when set', (tester) async {
      // Set due date directly on the task object (testing card display, not service)
      testTask.dueDate = DateTime.now().add(const Duration(days: 1));

      await tester.pumpWidget(wrapWithProviders(
        TaskCard(task: testTask, onTap: () {}),
        taskService,
      ));
      await tester.pump();

      expect(find.text('Due tomorrow'), findsOneWidget);
    });

    testWidgets('shows subtask progress when subtasks exist', (tester) async {
      testTask.addSubtask('Sub 1');
      testTask.addSubtask('Sub 2');

      await tester.pumpWidget(wrapWithProviders(
        TaskCard(task: testTask, onTap: () {}),
        taskService,
      ));
      await tester.pump();

      expect(find.text('0/2'), findsOneWidget);
    });

    testWidgets('has Semantics label', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        TaskCard(task: testTask, onTap: () {}),
        taskService,
      ));
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp('Test Task.*high.*todo')),
          findsOneWidget);
    });
  });

  // ── ColumnHeader Widget Tests ──

  group('ColumnHeader Widget Tests', () {
    testWidgets('displays column title and count', (tester) async {
      final column = BoardColumn(
        id: '550e8400-e29b-41d4-a716-446655440000',
        title: 'To Do',
        status: TaskStatus.todo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReorderableListView(
              onReorder: (_, __) {},
              children: [
                SizedBox(
                  key: const ValueKey('col'),
                  child: ColumnHeader(
                    column: column,
                    color: Colors.blue,
                    totalCount: 5,
                    onEdit: () {},
                    onDelete: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await pumpSettled(tester);

      expect(find.text('To Do'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });

  // ── SearchFilterBar Widget Tests ──

  group('SearchFilterBar Widget Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('displays search field', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SearchFilterBar(),
        taskService,
      ));
      await pumpSettled(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search tasks... (Ctrl+K)'), findsOneWidget);
    });

    testWidgets('typing updates search query', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SearchFilterBar(),
        taskService,
      ));
      await pumpSettled(tester);

      await tester.enterText(find.byType(TextField), 'hello');
      await pumpSettled(tester);

      expect(taskService.searchQuery, 'hello');
    });

    testWidgets('filter button toggles filter panel', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SearchFilterBar(),
        taskService,
      ));
      await pumpSettled(tester);

      // Filter panel not visible initially
      expect(find.text('Filters'), findsNothing);

      // Tap filter icon
      await tester.tap(find.byIcon(Icons.filter_list));
      await pumpSettled(tester);

      expect(find.text('Filters'), findsOneWidget);
    });

    testWidgets('clear button appears when text entered', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SearchFilterBar(),
        taskService,
      ));
      await pumpSettled(tester);

      await tester.enterText(find.byType(TextField), 'search');
      await pumpSettled(tester);

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('due date filter chips shown in filter panel', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SearchFilterBar(),
        taskService,
      ));
      await pumpSettled(tester);

      await tester.tap(find.byIcon(Icons.filter_list));
      await pumpSettled(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });
  });

  // ── Add Task Dialog Tests ──

  group('Add Task Dialog Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('shows dialog with title and add button', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: showAddTaskDialog,
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Add Task'), findsOneWidget); // Dialog title
      expect(find.text('Add'), findsOneWidget); // Button
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shows priority dropdown', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: showAddTaskDialog,
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Due Date'), findsOneWidget);
    });
  });

  // ── Add Project Dialog Tests ──

  group('Add Project Dialog Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('shows dialog with fields and create button', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: showAddProjectDialog,
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('New Project'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Project Name'), findsOneWidget);
    });
  });

  // ── Add Ritual Dialog Tests ──

  group('Add Ritual Dialog Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('shows dialog with add button', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: showAddRitualDialog,
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Add Ritual'), findsOneWidget); // Dialog title
      expect(find.text('Add'), findsOneWidget); // Button
    });

    testWidgets('shows title and description fields', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: showAddRitualDialog,
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description (optional)'), findsOneWidget);
    });
  });

  // ── Tag Management Dialog Tests ──

  group('Tag Management Dialog Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('shows empty state when no tags', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: showTagManagementDialog,
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Manage Tags'), findsOneWidget);
      expect(find.text('No tags yet. Tap + to create one.'), findsOneWidget);
    });

    testWidgets('shows add tag button', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: showTagManagementDialog,
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      // Add button (IconButton with Icons.add)
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });

  // ── Board Dialog Tests ──

  group('Board Dialog Tests', () {
    late TaskService taskService;
    late Project project;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
      project = taskService.selectedProject!;
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('add board dialog shows templates', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showAddBoardDialog(ctx, project),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Add Board'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Bug Tracking'), findsOneWidget);
      expect(find.text('Sprint'), findsOneWidget);
    });

    testWidgets('shows board name field', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showAddBoardDialog(ctx, project),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Board Name'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('delete single board shows snackbar', (tester) async {
      // Project has only one board, so delete should show snackbar
      final boardToDelete = project.boards.first;

      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showDeleteBoardDialog(ctx, project, boardToDelete),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      // Should show "Cannot delete the only board" snackbar
      expect(find.text('Cannot delete the only board'), findsOneWidget);
    });
  });

  // ── ProjectHeader Widget Tests ──

  group('ProjectHeader Extended Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('displays project name and key', (tester) async {
      final project = taskService.selectedProject!;

      await tester.pumpWidget(wrapWithProviders(
        ProjectHeader(project: project),
        taskService,
      ));
      await pumpSettled(tester);

      expect(find.text(project.name), findsOneWidget);
      expect(find.text(project.projectKey), findsOneWidget);
    });

    testWidgets('shows action buttons when project selected', (tester) async {
      final project = taskService.selectedProject!;

      await tester.pumpWidget(wrapWithProviders(
        ProjectHeader(project: project),
        taskService,
      ));
      await pumpSettled(tester);

      expect(find.byIcon(Icons.view_column), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets); // Add task + add board
      expect(find.byIcon(Icons.label), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows search bar when project selected', (tester) async {
      final project = taskService.selectedProject!;

      await tester.pumpWidget(wrapWithProviders(
        ProjectHeader(project: project),
        taskService,
      ));
      await pumpSettled(tester);

      expect(find.byType(SearchFilterBar), findsOneWidget);
    });

    testWidgets('shows "Projects" when no project', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const ProjectHeader(project: null),
        taskService,
      ));
      await pumpSettled(tester);

      expect(find.text('Projects'), findsOneWidget);
    });
  });

  // ── Edit/Delete Column Dialog Tests ──

  group('Column Dialog Tests', () {
    late TaskService taskService;
    late Project project;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
      project = taskService.selectedProject!;
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('edit column dialog shows current title', (tester) async {
      final column = project.activeColumns.first;

      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showEditColumnDialog(ctx, project, column),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Edit Column'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // Current column name should be pre-filled
      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, column.title),
      );
      expect(textField.controller?.text, column.title);
    });

    testWidgets('add column dialog shows fields', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showAddColumnDialog(ctx, project),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Add Column'), findsOneWidget);
      expect(find.text('Column Name'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('delete column dialog shows warning', (tester) async {
      final column = project.activeColumns.first;

      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showDeleteColumnDialog(ctx, project, column),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Delete Column'), findsOneWidget);
      expect(find.textContaining(column.title), findsOneWidget);
    });
  });

  // ── Task Details Dialog Tests ──

  group('Task Details Dialog Tests', () {
    late TaskService taskService;
    late Task testTask;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
      testTask = (await taskService.addTask(
        'Detail Task',
        description: 'Some description',
        priority: TaskPriority.high,
      ))!;
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('shows task details', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showTaskDetails(ctx, testTask),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Detail Task'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows subtask checkboxes', (tester) async {
      // Add subtasks directly to task object to avoid debounce issues
      testTask.addSubtask('Subtask 1');
      testTask.addSubtask('Subtask 2');

      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showTaskDetails(ctx, testTask),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Subtasks (0/2)'), findsOneWidget);
      expect(find.text('Subtask 1'), findsOneWidget);
      expect(find.text('Subtask 2'), findsOneWidget);
    });
  });

  // ── Task Menu Dialog Tests ──

  group('Task Menu Dialog Tests', () {
    late TaskService taskService;
    late Task testTask;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
      testTask = (await taskService.addTask('Menu Task'))!;
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('shows edit, move, delete options', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showTaskMenu(ctx, testTask),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Move to Project'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('shows move to project option', (tester) async {
      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showTaskMenu(ctx, testTask),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Move to Project'), findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move), findsOneWidget);
    });
  });

  // ── Edit Project Dialog Tests ──

  group('Edit Project Dialog Tests', () {
    late TaskService taskService;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    testWidgets('shows dialog with current values', (tester) async {
      final project = taskService.selectedProject!;

      await tester.pumpWidget(wrapDialogTrigger(
        taskService,
        onTap: (ctx) => showEditProjectDialog(ctx, project),
      ));
      await pumpSettled(tester);

      await tester.tap(find.text('Open'));
      await pumpSettled(tester);

      expect(find.text('Edit Project'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // Name should be pre-filled
      final nameField = tester.widget<TextField>(
        find.widgetWithText(TextField, project.name),
      );
      expect(nameField.controller?.text, project.name);
    });
  });

  // ── DueDatePicker Helper Tests ──

  group('DueDatePicker Helper Tests', () {
    testWidgets('shows "No due date" when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => buildDueDatePicker(context, null, (_) {}),
            ),
          ),
        ),
      );
      await pumpSettled(tester);

      expect(find.text('No due date'), findsOneWidget);
    });

    testWidgets('shows clear button when date set', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => buildDueDatePicker(
                context,
                DateTime(2026, 6, 15),
                (_) {},
              ),
            ),
          ),
        ),
      );
      await pumpSettled(tester);

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });
}
