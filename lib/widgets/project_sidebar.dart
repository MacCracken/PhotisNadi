import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../models/project.dart';
import '../common/utils.dart';
import 'dialogs/project_dialogs.dart';

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

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskService>(
      builder: (context, taskService, child) {
        final activeProjects = taskService.activeProjects;
        final archivedProjects = taskService.archivedProjects;
        final selectedProjectId = taskService.selectedProjectId;

        return Container(
          width: widget.isCollapsed ? 60 : 240,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: widget.isCollapsed
                    ? _buildCollapsedView(activeProjects, selectedProjectId)
                    : _buildExpandedView(
                        activeProjects,
                        archivedProjects,
                        selectedProjectId,
                        taskService,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    if (widget.isCollapsed) {
      return Container(
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

  Widget _buildCollapsedView(
    List<Project> projects,
    String? selectedProjectId,
  ) {
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
                  color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    project.key.length > 2
                        ? project.key.substring(0, 2)
                        : project.key,
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

  Widget _buildExpandedView(
    List<Project> activeProjects,
    List<Project> archivedProjects,
    String? selectedProjectId,
    TaskService taskService,
  ) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (activeProjects.isEmpty)
          _buildEmptyState()
        else
          ...activeProjects.map((project) => _buildProjectTile(
                project,
                selectedProjectId,
                taskService,
              )),
        if (archivedProjects.isNotEmpty) ...[
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
                    'Archived (${archivedProjects.length})',
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
            ...archivedProjects.map((project) => _buildProjectTile(
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No projects yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showAddProjectDialog(context),
            child: const Text('Create your first project'),
          ),
        ],
      ),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: isSelected ? color.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isArchived
            ? null
            : () => taskService.selectProject(project.id),
        onLongPress: () => showProjectMenu(context, project),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    project.key.length > 2
                        ? project.key.substring(0, 2)
                        : project.key,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
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
    );
  }
}
