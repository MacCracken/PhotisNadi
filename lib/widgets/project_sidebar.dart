import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../models/project.dart';
import '../common/utils.dart';
import 'dialogs/project_dialogs.dart';
import 'common/common_widgets.dart';

class ProjectSidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const ProjectSidebar({
    super.key,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<ProjectSidebar> createState() => _ProjectSidebarState();
}

class _ProjectSidebarState extends State<ProjectSidebar> {
  bool _showArchived = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleSidebar(
      isCollapsed: widget.isCollapsed,
      collapsedWidth: 60,
      expandedWidth: 240,
      header: _buildHeader(),
      child: widget.isCollapsed
          ? Selector<TaskService, List<Project>>(
              selector: (_, service) => service.activeProjects,
              builder: (context, projects, _) => _buildCollapsedView(projects),
            )
          : Selector<TaskService, (List<Project>, List<Project>, String?)>(
              selector: (_, service) => (
                service.activeProjects,
                service.archivedProjects,
                service.selectedProjectId
              ),
              builder: (context, data, _) => _buildExpandedView(
                data.$1,
                data.$2,
                data.$3,
              ),
            ),
    );
  }

  Widget _buildHeader() {
    if (widget.isCollapsed) {
      return SizedBox(
        height: 60,
        child: Center(
          child: IconButton(
            onPressed: widget.onToggleCollapse,
            icon: const Icon(Icons.keyboard_double_arrow_right),
            tooltip: 'Expand',
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onToggleCollapse,
            icon: const Icon(Icons.keyboard_double_arrow_left),
            tooltip: 'Collapse',
          ),
          const Expanded(
            child: Text(
              'Projects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => showAddProjectDialog(context),
            icon: const Icon(Icons.add),
            tooltip: 'New Project',
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedView(List<Project> projects) {
    final selectedProjectId = context.read<TaskService>().selectedProjectId;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final isSelected = project.id == selectedProjectId;
        final color = parseColor(project.color);

        return Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Tooltip(
            message: project.name,
            child: GestureDetector(
              onTap: () =>
                  context.read<TaskService>().selectProject(project.id),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    project.projectKey.length > 2
                        ? project.projectKey.substring(0, 2)
                        : project.projectKey,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Project> _filterProjects(List<Project> projects) {
    if (_searchQuery.isEmpty) return projects;
    final query = _searchQuery.toLowerCase();
    return projects.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search projects...',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildExpandedView(
    List<Project> activeProjects,
    List<Project> archivedProjects,
    String? selectedProjectId,
  ) {
    final taskService = context.read<TaskService>();
    final filteredActive = _filterProjects(activeProjects);
    final filteredArchived = _filterProjects(archivedProjects);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildSearchField(),
        if (filteredActive.isEmpty && _searchQuery.isEmpty)
          _buildEmptyState()
        else if (filteredActive.isEmpty && _searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No projects match "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...filteredActive.map((project) => _buildProjectTile(
                project,
                selectedProjectId,
                taskService,
              )),
        if (filteredArchived.isNotEmpty) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Icon(
                    _showArchived
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Archived (${filteredArchived.length})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showArchived)
            ...filteredArchived.map((project) => _buildProjectTile(
                  project,
                  selectedProjectId,
                  taskService,
                  isArchived: true,
                )),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.folder_open,
      title: 'No projects yet',
      actionLabel: 'Create your first project',
      onAction: () => showAddProjectDialog(context),
    );
  }

  Widget _buildProjectTile(
    Project project,
    String? selectedProjectId,
    TaskService taskService, {
    bool isArchived = false,
  }) {
    final isSelected = project.id == selectedProjectId;
    final color = parseColor(project.color);
    final taskCount = taskService.getTasksForProject(project.id).length;

    return Semantics(
      label: '${project.name}, $taskCount tasks',
      selected: isSelected,
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        color: isSelected ? color.withValues(alpha: 0.1) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side:
              isSelected ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap:
              isArchived ? null : () => taskService.selectProject(project.id),
          onLongPress: () => showProjectMenu(context, project),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        project.projectKey.length > 2
                            ? project.projectKey.substring(0, 2)
                            : project.projectKey,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isArchived ? Colors.grey : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$taskCount tasks',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isArchived)
                  Icon(
                    Icons.archive,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
