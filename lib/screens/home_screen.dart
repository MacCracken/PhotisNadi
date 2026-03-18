import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../services/theme_service.dart';
import '../services/sync_service.dart';
import '../services/keyboard_shortcuts.dart';
import '../widgets/dialogs/sync_dialogs.dart';
import '../widgets/dialogs/task_dialogs.dart';
import '../widgets/dialogs/ritual_dialogs.dart';
import '../widgets/kanban_board.dart';
import '../widgets/project_sidebar.dart';
import '../widgets/rituals_sidebar.dart';
import '../widgets/theme_toggle.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProjectsCollapsed = false;
  bool _isRitualsCollapsed = false;
  int _selectedNavIndex = 1;
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<KanbanBoardState> _kanbanKey = GlobalKey<KanbanBoardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskService>().init();
      context.read<ThemeService>().loadPreferences();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool get _isWideScreen => MediaQuery.of(context).size.width > 800;

  void _showQuickAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Quick Add',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.task),
            title: const Text('Add Task'),
            onTap: () {
              Navigator.pop(context);
              _showAddTaskDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Add Ritual'),
            onTap: () {
              Navigator.pop(context);
              _showAddRitualDialog();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAddTaskDialog() => showAddTaskDialog(context);

  void _showAddRitualDialog() => showAddRitualDialog(context);

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcutsWrapper(
      onAddTask: _showAddTaskDialog,
      onFocusSearch: () {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      },
      onEscape: () {
        FocusScope.of(context).unfocus();
      },
      onNextTask: () => _kanbanKey.currentState?.navigateNextTask(),
      onPrevTask: () => _kanbanKey.currentState?.navigatePrevTask(),
      onNextColumn: () => _kanbanKey.currentState?.navigateNextColumn(),
      onPrevColumn: () => _kanbanKey.currentState?.navigatePrevColumn(),
      child: Builder(
        builder: (context) => Selector<TaskService, bool>(
          selector: (_, service) => service.isLoading,
          builder: (context, isLoading, _) {
            if (isLoading) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading...'),
                    ],
                  ),
                ),
              );
            }

            return Selector<TaskService, String?>(
              selector: (_, service) => service.error,
              builder: (context, error, _) {
                if (error != null) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(error, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<TaskService>().clearError();
                              context.read<TaskService>().init();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_isWideScreen) {
                  return _buildWideLayout();
                }
                return _buildNarrowLayout();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSyncIcon() {
    return Consumer<SyncService>(
      builder: (context, syncService, _) {
        if (!syncService.isInitialized) return const SizedBox.shrink();

        IconData icon;
        Color? color;
        switch (syncService.syncState) {
          case SyncState.idle:
            icon = syncService.isAuthenticated
                ? Icons.cloud_queue
                : Icons.cloud_off;
            color = Colors.grey;
          case SyncState.syncing:
            icon = Icons.cloud_sync;
            color = Colors.blue;
          case SyncState.success:
            icon = Icons.cloud_done;
            color = Colors.green;
          case SyncState.error:
            icon = Icons.cloud_off;
            color = Colors.red;
        }

        return Stack(
          children: [
            IconButton(
              icon: Icon(icon, color: color),
              tooltip: 'Cloud Sync',
              onPressed: () => showSyncSettingsDialog(context),
            ),
            if (syncService.hasConflicts)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).appBarTheme.backgroundColor ??
                          Theme.of(context).colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photis Nadi'),
        actions: [
          _buildSyncIcon(),
          const ThemeToggle(),
        ],
      ),
      body: Row(
        children: [
          ProjectSidebar(
            isCollapsed: _isProjectsCollapsed,
            onToggleCollapse: () {
              setState(() {
                _isProjectsCollapsed = !_isProjectsCollapsed;
              });
            },
          ),
          Expanded(
            child: KanbanBoard(key: _kanbanKey),
          ),
          RitualsSidebar(
            isCollapsed: _isRitualsCollapsed,
            onToggleCollapse: () {
              setState(() {
                _isRitualsCollapsed = !_isRitualsCollapsed;
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddMenu,
        tooltip: 'Quick Add (Ctrl+N)',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photis Nadi'),
        actions: [
          _buildSyncIcon(),
          const ThemeToggle(),
        ],
      ),
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          ProjectSidebar(isCollapsed: false, onToggleCollapse: () {}),
          KanbanBoard(key: _kanbanKey),
          RitualsSidebar(isCollapsed: false, onToggleCollapse: () {}),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban),
            label: 'Board',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_outlined),
            selectedIcon: Icon(Icons.repeat),
            label: 'Rituals',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddMenu,
        tooltip: 'Quick Add (Ctrl+N)',
        child: const Icon(Icons.add),
      ),
    );
  }
}
