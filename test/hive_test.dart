import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/services/task_service.dart';

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

void main() {
  // ── Pagination Tests ──

  group('Pagination Tests', () {
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

    test('getTasksForColumnPaginated returns correct page', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      for (int i = 0; i < 25; i++) {
        await taskService.addTask('Task $i');
      }

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final page0 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 0,
        pageSize: 10,
      );
      expect(page0.length, 10);

      final page1 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 1,
        pageSize: 10,
      );
      expect(page1.length, 10);

      final page2 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 2,
        pageSize: 10,
      );
      expect(page2.length, 5);
    });

    test('getTaskCountForColumn returns correct count', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Task 1');
      await taskService.addTask('Task 2');
      await taskService.addTask('Task 3');

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final count = taskService.getTaskCountForColumn(
        todoColumn.id,
        projectId: project.id,
      );
      expect(count, 3);
    });

    test('hasMoreTasksForColumn correctly identifies more pages', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      for (int i = 0; i < 15; i++) {
        await taskService.addTask('Task $i');
      }

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(
        taskService.hasMoreTasksForColumn(
          todoColumn.id,
          projectId: project.id,
          page: 0,
          pageSize: 10,
        ),
        isTrue,
      );
      expect(
        taskService.hasMoreTasksForColumn(
          todoColumn.id,
          projectId: project.id,
          page: 1,
          pageSize: 10,
        ),
        isFalse,
      );
    });

    test('hasMoreTasksForColumn returns false when on last page', () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Task 1');
      await taskService.addTask('Task 2');

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      expect(
        taskService.hasMoreTasksForColumn(
          todoColumn.id,
          projectId: project.id,
          page: 0,
          pageSize: 10,
        ),
        isFalse,
      );
    });

    test('getTasksForColumnPaginated returns empty when page exceeds data',
        () async {
      final project = await taskService.addProject('Test', 'TST');
      expect(project, isNotNull);
      taskService.selectProject(project!.id);

      await taskService.addTask('Task 1');

      final todoColumn = project.columns.firstWhere(
        (c) => c.status == TaskStatus.todo,
      );
      final page1 = taskService.getTasksForColumnPaginated(
        todoColumn.id,
        projectId: project.id,
        page: 1,
        pageSize: 10,
      );
      expect(page1.length, 0);
    });
  });

  // ── Tag Service Tests ──

  group('Tag Service Tests', () {
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

    test('should add tag to project', () async {
      final project = await taskService.addProject('Test', 'TST');
      final tag = await taskService.addTag('Bug', '#E53935', project!.id);

      expect(tag, isNotNull);
      expect(tag!.name, 'Bug');
      expect(taskService.tags.length, 1);
    });

    test('should not add duplicate tag name', () async {
      final project = await taskService.addProject('Test', 'TST');
      await taskService.addTag('Bug', '#E53935', project!.id);
      final dup = await taskService.addTag('Bug', '#1E88E5', project.id);

      expect(dup, isNull);
      expect(taskService.tags.length, 1);
    });

    test('should get tags for project', () async {
      final p1 = await taskService.addProject('P1', 'PA');
      final p2 = await taskService.addProject('P2', 'PB');
      await taskService.addTag('Bug', '#E53935', p1!.id);
      await taskService.addTag('Feature', '#1E88E5', p1.id);
      await taskService.addTag('Docs', '#43A047', p2!.id);

      final p1Tags = taskService.getTagsForProject(p1.id);
      final p2Tags = taskService.getTagsForProject(p2.id);

      expect(p1Tags.length, 2);
      expect(p2Tags.length, 1);
    });

    test('should delete tag and remove from tasks', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      final tag = await taskService.addTag('Bug', '#E53935', project.id);
      final task = await taskService.addTask('Fix bug', tags: ['Bug']);

      expect(task!.tags.contains('Bug'), isTrue);

      await taskService.deleteTag(tag!.id);

      expect(taskService.tags.length, 0);
      final updatedTask = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(updatedTask.tags.contains('Bug'), isFalse);
    });

    test('should update tag and rename in tasks', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      final tag = await taskService.addTag('Bug', '#E53935', project.id);
      await taskService.addTask('Fix bug', tags: ['Bug']);

      final updated = tag!.copyWith(name: 'Defect');
      await taskService.updateTag(updated);

      final updatedTask = taskService.tasks.first;
      expect(updatedTask.tags.contains('Defect'), isTrue);
      expect(updatedTask.tags.contains('Bug'), isFalse);
    });

    test('should get tag by name', () async {
      final project = await taskService.addProject('Test', 'TST');
      await taskService.addTag('Bug', '#E53935', project!.id);

      final found = taskService.getTagByName('Bug', project.id);
      final notFound = taskService.getTagByName('Feature', project.id);

      expect(found, isNotNull);
      expect(found!.name, 'Bug');
      expect(notFound, isNull);
    });

    test('should filter tasks by multiple tags', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      await taskService.addTag('Bug', '#E53935', project.id);
      await taskService.addTag('UI', '#1E88E5', project.id);

      await taskService.addTask('Bug only', tags: ['Bug']);
      await taskService.addTask('UI only', tags: ['UI']);
      await taskService.addTask('Both', tags: ['Bug', 'UI']);

      taskService.toggleFilterTag('Bug');
      var filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 2);

      taskService.toggleFilterTag('UI');
      filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 3);

      taskService.clearFilterTags();
      filtered = taskService.getFilteredTasks(project.id);
      expect(filtered.length, 3);
    });

    test('should add task with tags', () async {
      final project = await taskService.addProject('Test', 'TST');
      taskService.selectProject(project!.id);
      final task = await taskService.addTask(
        'Tagged task',
        tags: ['Bug', 'UI'],
      );

      expect(task!.tags, ['Bug', 'UI']);
    });
  });

  // ── Tag Mixin CRUD Tests ──

  group('Tag Mixin CRUD Tests', () {
    late TaskService taskService;
    late String projectId;

    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
      taskService = TaskService();
      await taskService.init();
      final project = await taskService.addProject('Tag Project', 'TP');
      projectId = project!.id;
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('addTag creates tag', () async {
      final tag = await taskService.addTag('new-tag', '#FF0000', projectId);
      expect(tag, isNotNull);
      expect(tag!.name, 'new-tag');
      expect(taskService.tags.any((t) => t.name == 'new-tag'), true);
    });

    test('addTag prevents duplicates', () async {
      await taskService.addTag('dup', '#00FF00', projectId);
      final result = await taskService.addTag('dup', '#00FF00', projectId);
      expect(result, isNull);
    });

    test('deleteTag removes tag', () async {
      final tag = await taskService.addTag('remove-me', '#0000FF', projectId);
      expect(tag, isNotNull);
      final result = await taskService.deleteTag(tag!.id);
      expect(result, true);
      expect(taskService.tags.any((t) => t.name == 'remove-me'), false);
    });

    test('updateTag changes name and updates tasks', () async {
      final tag = await taskService.addTag('old-name', '#FF0000', projectId);
      expect(tag, isNotNull);
      await taskService
          .addTask('Tagged', projectId: projectId, tags: ['old-name']);

      final updatedTag = tag!.copyWith(name: 'new-name');
      final result = await taskService.updateTag(updatedTag);
      expect(result, true);

      expect(taskService.tags.any((t) => t.name == 'new-name'), true);
    });

    test('getTagsForProject returns project tags', () async {
      await taskService.addTag('tag-a', '#FF0000', projectId);
      await taskService.addTag('tag-b', '#00FF00', projectId);

      final tags = taskService.getTagsForProject(projectId);
      expect(tags.length, 2);
    });

    test('getTagByName returns matching tag', () async {
      await taskService.addTag('find-me', '#AABBCC', projectId);
      final found = taskService.getTagByName('find-me', projectId);
      expect(found, isNotNull);
      expect(found!.name, 'find-me');
    });

    test('getAllTagsForProject returns tags from tasks', () async {
      await taskService
          .addTask('T1', projectId: projectId, tags: ['alpha', 'beta']);
      await taskService
          .addTask('T2', projectId: projectId, tags: ['beta', 'gamma']);

      final allTags = taskService.getAllTagsForProject(projectId);
      expect(allTags, containsAll(['alpha', 'beta', 'gamma']));
    });

    test('deleteTag removes tag name from tasks', () async {
      final tag = await taskService.addTag('cleanup', '#FF0000', projectId);
      await taskService
          .addTask('Tagged Task', projectId: projectId, tags: ['cleanup']);

      await taskService.deleteTag(tag!.id);

      final task =
          taskService.tasks.firstWhere((t) => t.title == 'Tagged Task');
      expect(task.tags, isNot(contains('cleanup')));
    });
  });

  // ── Hive Serialization Round-Trip Tests ──

  group('Hive Serialization Round-Trip Tests', () {
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

    test('Task round-trips through Hive with all fields', () async {
      final task = await taskService.addTask(
        'Full Task',
        description: 'Detailed description',
        priority: TaskPriority.high,
        tags: ['urgent', 'review'],
        dueDate: DateTime(2026, 6, 15),
      );
      expect(task, isNotNull);

      task!.status = TaskStatus.inReview;
      task.addSubtask('Check code');
      task.addSubtask('Write docs');
      task.toggleSubtask(1);
      task.trackedMinutes = 90;
      task.estimatedMinutes = 180;
      task.recurrence = 'weekly';
      task.attachments = ['/doc.pdf', '/img.png'];
      await taskService.updateTask(task);

      final loaded = taskService.tasks.firstWhere((t) => t.id == task.id);
      expect(loaded.title, 'Full Task');
      expect(loaded.description, 'Detailed description');
      expect(loaded.status, TaskStatus.inReview);
      expect(loaded.priority, TaskPriority.high);
      expect(loaded.tags, ['urgent', 'review']);
      expect(loaded.dueDate, DateTime(2026, 6, 15));
      expect(loaded.subtasks.length, 2);
      expect(loaded.subtasksDone, 1);
      expect(loaded.trackedMinutes, 90);
      expect(loaded.estimatedMinutes, 180);
      expect(loaded.recurrence, 'weekly');
      expect(loaded.attachments, ['/doc.pdf', '/img.png']);
    });

    test('Task with dependencies round-trips through Hive', () async {
      final t1 = await taskService.addTask('First');
      final t2 = await taskService.addTask('Second');
      await taskService.addTaskDependency(t2!.id, t1!.id);

      final loaded = taskService.tasks.firstWhere((t) => t.id == t2.id);
      expect(loaded.dependsOn, contains(t1.id));
    });

    test('Project round-trips through Hive with all fields', () async {
      final project = await taskService.addProject(
        'Full Project',
        'FP',
        description: 'A test project',
        color: '#FF5500',
        iconName: 'star',
      );
      expect(project, isNotNull);

      final loaded =
          taskService.projects.firstWhere((p) => p.id == project!.id);
      expect(loaded.name, 'Full Project');
      expect(loaded.projectKey, 'FP');
      expect(loaded.description, 'A test project');
      expect(loaded.color, '#FF5500');
      expect(loaded.iconName, 'star');
      expect(loaded.isArchived, false);
      expect(loaded.boards, isNotEmpty);
    });

    test('Project with boards round-trips through Hive', () async {
      final project = await taskService.addProject('Board Test', 'BT');
      expect(project, isNotNull);

      final board = Board(
        id: 'custom-board',
        title: 'Sprint 1',
        createdAt: DateTime.now(),
        columns: [
          BoardColumn(
              id: 'c1', title: 'New', order: 0, status: TaskStatus.todo),
          BoardColumn(
              id: 'c2',
              title: 'Active',
              order: 1,
              status: TaskStatus.inProgress),
          BoardColumn(
              id: 'c3', title: 'Complete', order: 2, status: TaskStatus.done),
        ],
      );
      await taskService.addBoard(project!.id, board);

      final loaded = taskService.projects.firstWhere((p) => p.id == project.id);
      final loadedBoard =
          loaded.boards.firstWhere((b) => b.id == 'custom-board');
      expect(loadedBoard.title, 'Sprint 1');
      expect(loadedBoard.columns.length, 3);
      expect(loadedBoard.columns[0].title, 'New');
      expect(loadedBoard.columns[1].status, TaskStatus.inProgress);
    });

    test('Ritual round-trips through Hive with all fields', () async {
      final ritual = await taskService.addRitual('Morning Meditation',
          description: '10 minutes of mindfulness');
      expect(ritual, isNotNull);

      ritual!.frequency = RitualFrequency.weekly;
      ritual.streakCount = 10;
      ritual.isCompleted = true;
      ritual.lastCompleted = DateTime(2026, 3, 9);
      ritual.resetTime = DateTime(2026, 3, 8);
      await taskService.updateRitual(ritual);

      final loaded = taskService.rituals.firstWhere((r) => r.id == ritual.id);
      expect(loaded.title, 'Morning Meditation');
      expect(loaded.description, '10 minutes of mindfulness');
      expect(loaded.frequency, RitualFrequency.weekly);
      expect(loaded.streakCount, 10);
      expect(loaded.isCompleted, true);
      expect(loaded.lastCompleted, DateTime(2026, 3, 9));
      expect(loaded.resetTime, DateTime(2026, 3, 8));
    });

    test('Tag round-trips through Hive', () async {
      final project = await taskService.addProject('Tag Test', 'TT');
      await taskService.addTag('important', '#FF0000', project!.id);
      await taskService.addTag('review', '#00FF00', project.id);

      final tags = taskService.tags;
      expect(tags.any((t) => t.name == 'important'), true);
      expect(tags.any((t) => t.name == 'review'), true);
    });

    test('All TaskStatus values serialize correctly', () async {
      for (final status in TaskStatus.values) {
        final task = await taskService.addTask('Status: ${status.name}');
        task!.status = status;
        await taskService.updateTask(task);

        final loaded = taskService.tasks.firstWhere((t) => t.id == task.id);
        expect(loaded.status, status);
      }
    });

    test('All TaskPriority values serialize correctly', () async {
      for (final priority in TaskPriority.values) {
        final task = await taskService.addTask('Priority: ${priority.name}',
            priority: priority);
        expect(task, isNotNull);

        final loaded = taskService.tasks.firstWhere((t) => t.id == task!.id);
        expect(loaded.priority, priority);
      }
    });

    test('All RitualFrequency values serialize correctly', () async {
      for (final freq in RitualFrequency.values) {
        final ritual = await taskService.addRitual('Freq: ${freq.name}');
        ritual!.frequency = freq;
        await taskService.updateRitual(ritual);

        final loaded = taskService.rituals.firstWhere((r) => r.id == ritual.id);
        expect(loaded.frequency, freq);
      }
    });

    test('Project with sharing round-trips through Hive', () async {
      final project = await taskService.addProject('Shared', 'SHR');
      await taskService.shareProject(project!.id, 'user-a');
      await taskService.shareProject(project.id, 'user-b');

      final loaded = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(loaded.sharedWith, containsAll(['user-a', 'user-b']));
    });

    test('Project archived state round-trips', () async {
      final project = await taskService.addProject('Archive', 'ARC');
      await taskService.archiveProject(project!.id);

      final loaded = taskService.projects.firstWhere((p) => p.id == project.id);
      expect(loaded.isArchived, true);
    });
  });

  // ── Hive Disk Persistence Tests ──

  group('Hive Disk Persistence Tests', () {
    test('Tasks persist and reload through Hive binary serialization',
        () async {
      await setUpTestHive();
      _registerAdapters();

      final service = TaskService();
      await service.init();
      final project = await service.addProject('Persist Test', 'PT');
      final task = await service.addTask(
        'Persisted Task',
        projectId: project!.id,
        description: 'desc',
        priority: TaskPriority.high,
        tags: ['tag1'],
        dueDate: DateTime(2026, 6, 15),
      );
      task!.status = TaskStatus.inProgress;
      task.addSubtask('Sub1');
      task.trackedMinutes = 30;
      task.estimatedMinutes = 60;
      task.recurrence = 'daily';
      task.attachments = ['/file.txt'];
      task.dependsOn = [];
      await service.updateTask(task);

      final ritual = await service.addRitual('Persisted Ritual',
          description: 'ritual desc');
      ritual!.frequency = RitualFrequency.weekly;
      ritual.isCompleted = true;
      ritual.lastCompleted = DateTime(2026, 3, 1);
      ritual.streakCount = 5;
      ritual.resetTime = DateTime(2026, 3, 8);
      await service.updateRitual(ritual);

      await service.addTag('persist-tag', '#AABB00', project.id);

      final board = Board(
        id: 'persist-board',
        title: 'Persist Board',
        createdAt: DateTime.now(),
        columns: [
          BoardColumn(
              id: 'pb-c1', title: 'New', order: 0, status: TaskStatus.todo),
          BoardColumn(
              id: 'pb-c2', title: 'Done', order: 1, status: TaskStatus.done),
        ],
      );
      await service.addBoard(project.id, board);

      await Hive.close();

      final service2 = TaskService();
      await service2.init();

      final loadedTasks =
          service2.tasks.where((t) => t.title == 'Persisted Task');
      expect(loadedTasks, isNotEmpty);
      final lt = loadedTasks.first;
      expect(lt.description, 'desc');
      expect(lt.status, TaskStatus.inProgress);
      expect(lt.priority, TaskPriority.high);
      expect(lt.tags, ['tag1']);
      expect(lt.dueDate, DateTime(2026, 6, 15));
      expect(lt.subtasks, isNotEmpty);
      expect(lt.trackedMinutes, 30);
      expect(lt.estimatedMinutes, 60);
      expect(lt.recurrence, 'daily');
      expect(lt.attachments, ['/file.txt']);

      final loadedRituals =
          service2.rituals.where((r) => r.title == 'Persisted Ritual');
      expect(loadedRituals, isNotEmpty);
      final lr = loadedRituals.first;
      expect(lr.description, 'ritual desc');
      expect(lr.frequency, RitualFrequency.weekly);
      expect(lr.streakCount, 5);

      final loadedProjects =
          service2.projects.where((p) => p.name == 'Persist Test');
      expect(loadedProjects, isNotEmpty);
      final lp = loadedProjects.first;
      expect(lp.projectKey, 'PT');
      expect(lp.boards.any((b) => b.id == 'persist-board'), true);
      final lb = lp.boards.firstWhere((b) => b.id == 'persist-board');
      expect(lb.columns.length, 2);
      expect(lb.columns[0].title, 'New');
      expect(lb.columns[1].status, TaskStatus.done);

      final loadedTags = service2.tags.where((t) => t.name == 'persist-tag');
      expect(loadedTags, isNotEmpty);
      expect(loadedTags.first.color, '#AABB00');

      await tearDownTestHive();
    });
  });

  // ── Hive Adapter Extended Tests ──

  group('Hive Adapter Extended Tests', () {
    setUp(() async {
      await setUpTestHive();
      _registerAdapters();
    });

    tearDown(() async {
      await tearDownTestHive();
    });

    test('TaskAdapter hashCode and equality', () {
      final a1 = TaskAdapter();
      final a2 = TaskAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
      expect(a1 == Object(), isFalse);
    });

    test('TaskStatusAdapter hashCode and equality', () {
      final a1 = TaskStatusAdapter();
      final a2 = TaskStatusAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('TaskPriorityAdapter hashCode and equality', () {
      final a1 = TaskPriorityAdapter();
      final a2 = TaskPriorityAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('RitualAdapter hashCode and equality', () {
      final a1 = RitualAdapter();
      final a2 = RitualAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('RitualFrequencyAdapter hashCode and equality', () {
      final a1 = RitualFrequencyAdapter();
      final a2 = RitualFrequencyAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('BoardAdapter hashCode and equality', () {
      final a1 = BoardAdapter();
      final a2 = BoardAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('BoardColumnAdapter hashCode and equality', () {
      final a1 = BoardColumnAdapter();
      final a2 = BoardColumnAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('ProjectAdapter hashCode and equality', () {
      final a1 = ProjectAdapter();
      final a2 = ProjectAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('TagAdapter hashCode and equality', () {
      final a1 = TagAdapter();
      final a2 = TagAdapter();
      expect(a1.hashCode, a2.hashCode);
      expect(a1 == a2, isTrue);
    });

    test('Task full round-trip through Hive box', () async {
      final box = await Hive.openBox<Task>('test_tasks_rt');
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440400',
        title: 'RT Task',
        description: 'desc',
        status: TaskStatus.inReview,
        priority: TaskPriority.low,
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 6, 1),
        projectId: '550e8400-e29b-41d4-a716-446655440099',
        tags: ['bug', 'ui'],
        taskKey: 'RT-1',
        dependsOn: ['550e8400-e29b-41d4-a716-446655440051'],
        subtasks: ['0:Sub1', '1:Sub2'],
        estimatedMinutes: 60,
        trackedMinutes: 30,
        recurrence: 'weekly',
        attachments: ['/tmp/file.txt'],
      );
      await box.put(task.id, task);
      await box.close();

      final box2 = await Hive.openBox<Task>('test_tasks_rt');
      final read = box2.get(task.id)!;
      expect(read.title, 'RT Task');
      expect(read.description, 'desc');
      expect(read.status, TaskStatus.inReview);
      expect(read.priority, TaskPriority.low);
      expect(read.tags, ['bug', 'ui']);
      expect(read.taskKey, 'RT-1');
      expect(read.dependsOn.length, 1);
      expect(read.subtasks.length, 2);
      expect(read.estimatedMinutes, 60);
      expect(read.trackedMinutes, 30);
      expect(read.recurrence, 'weekly');
      expect(read.attachments, ['/tmp/file.txt']);
      await box2.close();
    });

    test('Ritual full round-trip through Hive box', () async {
      final box = await Hive.openBox<Ritual>('test_rituals_rt');
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440401',
        title: 'RT Ritual',
        description: 'ritual desc',
        isCompleted: true,
        createdAt: DateTime(2026, 1, 1),
        lastCompleted: DateTime(2026, 1, 5),
        resetTime: DateTime(2026, 1, 5),
        streakCount: 5,
        frequency: RitualFrequency.weekly,
      );
      await box.put(ritual.id, ritual);
      await box.close();

      final box2 = await Hive.openBox<Ritual>('test_rituals_rt');
      final read = box2.get(ritual.id)!;
      expect(read.title, 'RT Ritual');
      expect(read.isCompleted, true);
      expect(read.streakCount, 5);
      expect(read.frequency, RitualFrequency.weekly);
      expect(read.lastCompleted, isNotNull);
      expect(read.resetTime, isNotNull);
      await box2.close();
    });

    test('Board full round-trip through Hive box', () async {
      final box = await Hive.openBox<Board>('test_boards_rt');
      final board = Board(
        id: 'board-rt',
        title: 'RT Board',
        description: 'board desc',
        createdAt: DateTime(2026, 1, 1),
        columnIds: ['c1', 'c2'],
        color: '#FF0000',
        columns: [
          BoardColumn(
              id: 'c1', title: 'Todo', order: 0, status: TaskStatus.todo),
          BoardColumn(
              id: 'c2', title: 'Done', order: 1, status: TaskStatus.done),
        ],
      );
      await box.put(board.id, board);
      await box.close();

      final box2 = await Hive.openBox<Board>('test_boards_rt');
      final read = box2.get(board.id)!;
      expect(read.title, 'RT Board');
      expect(read.description, 'board desc');
      expect(read.columnIds, ['c1', 'c2']);
      expect(read.columns.length, 2);
      expect(read.columns.first.title, 'Todo');
      expect(read.columns.last.status, TaskStatus.done);
      await box2.close();
    });

    test('Project full round-trip through Hive box', () async {
      final box = await Hive.openBox<Project>('test_projects_rt');
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440402',
        name: 'RT Project',
        projectKey: 'RT',
        description: 'proj desc',
        createdAt: DateTime(2026, 1, 1),
        color: '#00FF00',
        iconName: 'star',
        taskCounter: 10,
        isArchived: true,
        sharedWith: ['user1'],
        ownerId: 'owner1',
      );
      await box.put(project.id, project);
      await box.close();

      final box2 = await Hive.openBox<Project>('test_projects_rt');
      final read = box2.get(project.id)!;
      expect(read.name, 'RT Project');
      expect(read.projectKey, 'RT');
      expect(read.description, 'proj desc');
      expect(read.color, '#00FF00');
      expect(read.iconName, 'star');
      expect(read.taskCounter, 10);
      expect(read.isArchived, true);
      expect(read.sharedWith, ['user1']);
      expect(read.ownerId, 'owner1');
      expect(read.boards, isNotEmpty);
      await box2.close();
    });

    test('Tag full round-trip through Hive box', () async {
      final box = await Hive.openBox<Tag>('test_tags_rt');
      final tag = Tag(
        id: '550e8400-e29b-41d4-a716-446655440403',
        name: 'Bug',
        color: '#E53935',
        projectId: '550e8400-e29b-41d4-a716-446655440099',
      );
      await box.put(tag.id, tag);
      await box.close();

      final box2 = await Hive.openBox<Tag>('test_tags_rt');
      final read = box2.get(tag.id)!;
      expect(read.name, 'Bug');
      expect(read.color, '#E53935');
      expect(read.projectId, tag.projectId);
      await box2.close();
    });

    test('All TaskStatus values round-trip through Hive', () async {
      final box = await Hive.openBox<Task>('test_task_status_rt');
      for (final status in TaskStatus.values) {
        final t = Task(
          id: '550e8400-e29b-41d4-a716-44665544050${status.index}',
          title: 'Status ${status.name}',
          createdAt: DateTime(2026, 1, 1),
          status: status,
        );
        await box.put(t.id, t);
      }
      await box.close();

      final box2 = await Hive.openBox<Task>('test_task_status_rt');
      for (final status in TaskStatus.values) {
        final read =
            box2.get('550e8400-e29b-41d4-a716-44665544050${status.index}')!;
        expect(read.status, status);
      }
      await box2.close();
    });

    test('All TaskPriority values round-trip through Hive', () async {
      final box = await Hive.openBox<Task>('test_task_priority_rt');
      for (final priority in TaskPriority.values) {
        final t = Task(
          id: '550e8400-e29b-41d4-a716-44665544060${priority.index}',
          title: 'Priority ${priority.name}',
          createdAt: DateTime(2026, 1, 1),
          priority: priority,
        );
        await box.put(t.id, t);
      }
      await box.close();

      final box2 = await Hive.openBox<Task>('test_task_priority_rt');
      for (final priority in TaskPriority.values) {
        final read =
            box2.get('550e8400-e29b-41d4-a716-44665544060${priority.index}')!;
        expect(read.priority, priority);
      }
      await box2.close();
    });

    test('TaskAdapter is not equal to other types', () {
      expect(TaskAdapter() == RitualAdapter(), isFalse);
      expect(BoardAdapter() == ProjectAdapter(), isFalse);
      expect(TaskStatusAdapter() == TaskPriorityAdapter(), isFalse);
    });

    test('BoardColumn full round-trip through Hive box', () async {
      final box = await Hive.openBox<BoardColumn>('test_columns_rt');
      for (final status in TaskStatus.values) {
        final col = BoardColumn(
          id: 'col-${status.name}',
          title: 'Status ${status.name}',
          taskIds: ['t1', 't2'],
          order: status.index,
          color: '#AABBCC',
          status: status,
        );
        await box.put(col.id, col);
      }
      await box.close();

      final box2 = await Hive.openBox<BoardColumn>('test_columns_rt');
      for (final status in TaskStatus.values) {
        final read = box2.get('col-${status.name}')!;
        expect(read.status, status);
        expect(read.taskIds, ['t1', 't2']);
        expect(read.color, '#AABBCC');
      }
      await box2.close();
    });

    test('All RitualFrequency values round-trip through Hive', () async {
      final box = await Hive.openBox<Ritual>('test_freq_rt');
      for (final freq in RitualFrequency.values) {
        final r = Ritual(
          id: '550e8400-e29b-41d4-a716-44665544070${freq.index}',
          title: 'Freq ${freq.name}',
          createdAt: DateTime(2026, 1, 1),
          frequency: freq,
        );
        await box.put(r.id, r);
      }
      await box.close();

      final box2 = await Hive.openBox<Ritual>('test_freq_rt');
      for (final freq in RitualFrequency.values) {
        final read =
            box2.get('550e8400-e29b-41d4-a716-44665544070${freq.index}')!;
        expect(read.frequency, freq);
      }
      await box2.close();
    });
  });
}
