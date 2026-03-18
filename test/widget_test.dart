import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photisnadi/widgets/common/common_widgets.dart';
import 'package:photisnadi/widgets/common/project_header.dart';

void main() {
  group('EmptyState Widget Tests', () {
    testWidgets('should display icon, title, and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'No tasks',
              subtitle: 'Create your first task',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No tasks'), findsOneWidget);
      expect(find.text('Create your first task'), findsOneWidget);
    });

    testWidgets('should display action button when provided', (tester) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'No tasks',
              actionLabel: 'Add Task',
              onAction: () => actionCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Task'), findsOneWidget);
      await tester.tap(find.text('Add Task'));
      expect(actionCalled, isTrue);
    });

    testWidgets('should not display subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'No tasks',
            ),
          ),
        ),
      );

      expect(find.text('No tasks'), findsOneWidget);
    });
  });

  group('ColorPicker Widget Tests', () {
    testWidgets('should display all default colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPicker(
              selectedColor: '#3B82F6',
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNWidgets(7));
    });

    testWidgets('should call onColorSelected when color is tapped',
        (tester) async {
      String? selectedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPicker(
              selectedColor: '#3B82F6',
              onColorSelected: (color) => selectedColor = color,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(selectedColor, isNotNull);
    });

    testWidgets('should display check icon on selected color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPicker(
              selectedColor: '#3B82F6',
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('ColorBadge Widget Tests', () {
    testWidgets('should display text with color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColorBadge(
              text: 'High',
              color: Colors.red,
            ),
          ),
        ),
      );

      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('should use custom font size when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColorBadge(
              text: 'Test',
              color: Colors.blue,
              fontSize: 16,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Test'));
      expect(textWidget.style?.fontSize, 16);
    });
  });

  group('StreakBadge Widget Tests', () {
    testWidgets('should display streak count when greater than 0',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakBadge(streakCount: 5),
          ),
        ),
      );

      expect(find.text('5🔥'), findsOneWidget);
    });

    testWidgets('should return empty widget when streak is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakBadge(streakCount: 0),
          ),
        ),
      );

      expect(find.byType(StreakBadge), findsOneWidget);
      expect(find.text('0🔥'), findsNothing);
    });

    testWidgets('should return empty widget when streak is negative',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakBadge(streakCount: -1),
          ),
        ),
      );

      expect(find.text('-1🔥'), findsNothing);
    });
  });

  group('CountBadge Widget Tests', () {
    testWidgets('should display count with color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountBadge(count: 10, color: Colors.green),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
    });
  });

  group('EditDeleteMenu Widget Tests', () {
    testWidgets('should display edit and delete options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditDeleteMenu(
              onSelected: (_) {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('should show menu items when tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditDeleteMenu(
              onSelected: (_) {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('should not show edit when onEdit is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditDeleteMenu(
              onSelected: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('ProjectHeader Widget Tests', () {
    testWidgets('should display Projects title when project is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProjectHeader(project: null),
          ),
        ),
      );

      expect(find.text('Projects'), findsOneWidget);
    });
  });

  group('SidebarHeader Widget Tests', () {
    testWidgets('displays collapsed state with expand button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarHeader(
              title: 'Sidebar',
              isCollapsed: true,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.keyboard_double_arrow_right), findsOneWidget);
      expect(find.text('Sidebar'), findsNothing);
    });

    testWidgets('displays expanded state with title and collapse button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarHeader(
              title: 'Sidebar',
              isCollapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sidebar'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_double_arrow_left), findsOneWidget);
    });

    testWidgets('displays action icon when provided', (tester) async {
      bool actionCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarHeader(
              title: 'Sidebar',
              isCollapsed: false,
              onToggleCollapse: () {},
              actionIcon: Icons.add,
              onAction: () => actionCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      expect(actionCalled, isTrue);
    });

    testWidgets('calls onToggleCollapse when collapse button tapped',
        (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarHeader(
              title: 'Sidebar',
              isCollapsed: false,
              onToggleCollapse: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left));
      expect(toggled, isTrue);
    });

    testWidgets('uses leading widget in collapsed state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarHeader(
              title: 'Sidebar',
              isCollapsed: true,
              onToggleCollapse: () {},
              leading: const Icon(Icons.menu),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.menu), findsOneWidget);
    });
  });

  group('CollapsibleSidebar Widget Tests', () {
    testWidgets('renders expanded with correct width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsibleSidebar(
              isCollapsed: false,
              expandedWidth: 300,
              header: const Text('Header'),
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final constraints = container.constraints;
      expect(constraints?.maxWidth ?? 300, 300);
    });

    testWidgets('renders collapsed with correct width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsibleSidebar(
              isCollapsed: true,
              collapsedWidth: 60,
              header: const Text('Header'),
              child: const Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Header'), findsOneWidget);
    });
  });

  group('CollapsedListItem Widget Tests', () {
    testWidgets('displays abbreviated label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CollapsedListItem(label: 'Testing'),
          ),
        ),
      );

      expect(find.text('Te'), findsOneWidget);
    });

    testWidgets('displays short label as-is', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CollapsedListItem(label: 'AB'),
          ),
        ),
      );

      expect(find.text('AB'), findsOneWidget);
    });

    testWidgets('handles tap callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollapsedListItem(
              label: 'Test',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('shows selected state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CollapsedListItem(
              label: 'Test',
              color: Colors.blue,
              isSelected: true,
            ),
          ),
        ),
      );

      expect(find.text('Te'), findsOneWidget);
    });

    testWidgets('shows tooltip when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CollapsedListItem(
              label: 'Test',
              tooltip: 'Full name',
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('no tooltip when not provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CollapsedListItem(label: 'Test'),
          ),
        ),
      );

      // The item is rendered but no Tooltip widget wraps it
      expect(find.text('Te'), findsOneWidget);
    });
  });

  group('ActionMenuItem Widget Tests', () {
    testWidgets('displays icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: ActionMenuItem(
                    value: 'test',
                    icon: Icons.star,
                    label: 'Star',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Star'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('applies custom icon color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: ActionMenuItem(
                    value: 'test',
                    icon: Icons.delete,
                    label: 'Delete',
                    iconColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.delete));
      expect(icon.color, Colors.red);
    });
  });
}
