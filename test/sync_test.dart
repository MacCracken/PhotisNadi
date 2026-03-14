import 'package:flutter_test/flutter_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/services/sync_service.dart';
import 'package:photisnadi/server/serializers.dart';

void main() {
  group('Sync Serialization Tests', () {
    test('Task toSyncMap produces correct map', () {
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440050',
        title: 'Sync Task',
        description: 'A test task',
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 2, 1),
        projectId: '550e8400-e29b-41d4-a716-446655440099',
        tags: ['bug', 'ui'],
        taskKey: 'TST-1',
        dependsOn: ['550e8400-e29b-41d4-a716-446655440051'],
      );

      final map = task.toSyncMap('user-123');

      expect(map['id'], task.id);
      expect(map['user_id'], 'user-123');
      expect(map['title'], 'Sync Task');
      expect(map['description'], 'A test task');
      expect(map['status'], 'inProgress');
      expect(map['priority'], 'high');
      expect(map['project_id'], task.projectId);
      expect(map['tags'], ['bug', 'ui']);
      expect(map['task_key'], 'TST-1');
      expect(map['depends_on'], ['550e8400-e29b-41d4-a716-446655440051']);
      expect(map['due_date'], isNotNull);
      expect(map['created_at'], isNotNull);
      expect(map['modified_at'], isNotNull);
    });

    test('Task fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440050',
        'title': 'Parsed Task',
        'description': 'Desc',
        'status': 'inProgress',
        'priority': 'high',
        'created_at': '2026-01-01T00:00:00.000',
        'modified_at': '2026-01-02T00:00:00.000',
        'due_date': '2026-02-01T00:00:00.000',
        'project_id': '550e8400-e29b-41d4-a716-446655440099',
        'tags': ['bug'],
        'task_key': 'TST-1',
        'depends_on': ['550e8400-e29b-41d4-a716-446655440051'],
      };

      final task = TaskParsing.fromMap(map);

      expect(task.id, map['id']);
      expect(task.title, 'Parsed Task');
      expect(task.description, 'Desc');
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.high);
      expect(task.dueDate, isNotNull);
      expect(task.tags, ['bug']);
      expect(task.taskKey, 'TST-1');
      expect(task.dependsOn, ['550e8400-e29b-41d4-a716-446655440051']);
    });

    test('Task fromMap handles missing optional fields', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440050',
        'title': 'Minimal Task',
        'status': 'todo',
        'priority': 'medium',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final task = TaskParsing.fromMap(map);

      expect(task.title, 'Minimal Task');
      expect(task.description, isNull);
      expect(task.dueDate, isNull);
      expect(task.projectId, isNull);
      expect(task.tags, isEmpty);
      expect(task.taskKey, isNull);
      expect(task.dependsOn, isEmpty);
    });

    test('Task fromMap handles invalid status gracefully', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440050',
        'title': 'Bad Status',
        'status': 'nonexistent',
        'priority': 'nonexistent',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final task = TaskParsing.fromMap(map);

      expect(task.status, TaskStatus.todo);
      expect(task.priority, TaskPriority.medium);
    });

    test('Project toSyncMap produces correct map', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440060',
        name: 'Sync Project',
        projectKey: 'SP',
        description: 'A project',
        createdAt: DateTime(2026, 1, 1),
        color: '#FF0000',
        iconName: 'star',
        taskCounter: 5,
        isArchived: true,
      );

      final map = project.toSyncMap('user-123');

      expect(map['id'], project.id);
      expect(map['user_id'], 'user-123');
      expect(map['name'], 'Sync Project');
      expect(map['key'], 'SP');
      expect(map['description'], 'A project');
      expect(map['color'], '#FF0000');
      expect(map['icon_name'], 'star');
      expect(map['task_counter'], 5);
      expect(map['is_archived'], true);
    });

    test('Project fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440060',
        'name': 'Parsed Project',
        'key': 'PP',
        'description': 'Desc',
        'created_at': '2026-01-01T00:00:00.000',
        'modified_at': '2026-01-02T00:00:00.000',
        'color': '#00FF00',
        'icon_name': 'folder',
        'task_counter': 10,
        'is_archived': false,
      };

      final project = ProjectParsing.fromMap(map);

      expect(project.id, map['id']);
      expect(project.name, 'Parsed Project');
      expect(project.projectKey, 'PP');
      expect(project.color, '#00FF00');
      expect(project.iconName, 'folder');
      expect(project.taskCounter, 10);
      expect(project.isArchived, false);
    });

    test('Ritual toSyncMap produces correct map', () {
      final ritual = Ritual(
        id: '550e8400-e29b-41d4-a716-446655440070',
        title: 'Sync Ritual',
        description: 'A ritual',
        createdAt: DateTime(2026, 1, 1),
        streakCount: 7,
        frequency: RitualFrequency.weekly,
      );

      final map = ritual.toSyncMap('user-123');

      expect(map['id'], ritual.id);
      expect(map['user_id'], 'user-123');
      expect(map['title'], 'Sync Ritual');
      expect(map['frequency'], 'weekly');
      expect(map['streak_count'], 7);
    });

    test('Ritual fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440070',
        'title': 'Parsed Ritual',
        'description': 'Desc',
        'is_completed': true,
        'created_at': '2026-01-01T00:00:00.000',
        'last_completed': '2026-01-05T00:00:00.000',
        'reset_time': null,
        'streak_count': 3,
        'frequency': 'daily',
      };

      final ritual = RitualParsing.fromMap(map);

      expect(ritual.id, map['id']);
      expect(ritual.title, 'Parsed Ritual');
      expect(ritual.isCompleted, true);
      expect(ritual.streakCount, 3);
      expect(ritual.frequency, RitualFrequency.daily);
    });

    test('Tag toSyncMap produces correct map', () {
      final tag = Tag(
        id: '550e8400-e29b-41d4-a716-446655440080',
        name: 'Bug',
        color: '#E53935',
        projectId: '550e8400-e29b-41d4-a716-446655440099',
      );

      final map = tag.toSyncMap('user-123');

      expect(map['id'], tag.id);
      expect(map['user_id'], 'user-123');
      expect(map['name'], 'Bug');
      expect(map['color'], '#E53935');
      expect(map['project_id'], tag.projectId);
    });

    test('Tag fromMap parses correctly', () {
      final map = {
        'id': '550e8400-e29b-41d4-a716-446655440080',
        'name': 'Feature',
        'color': '#1E88E5',
        'project_id': '550e8400-e29b-41d4-a716-446655440099',
      };

      final tag = TagParsing.fromMap(map);

      expect(tag.id, map['id']);
      expect(tag.name, 'Feature');
      expect(tag.color, '#1E88E5');
      expect(tag.projectId, map['project_id']);
    });

    test('Task roundtrip: toSyncMap -> fromMap preserves data', () {
      final original = Task(
        id: '550e8400-e29b-41d4-a716-446655440050',
        title: 'Roundtrip Task',
        description: 'Test desc',
        status: TaskStatus.inReview,
        priority: TaskPriority.low,
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 3, 15),
        projectId: '550e8400-e29b-41d4-a716-446655440099',
        tags: ['ui', 'bug'],
        taskKey: 'RT-1',
        dependsOn: ['550e8400-e29b-41d4-a716-446655440051'],
      );

      final map = original.toSyncMap('user-123');
      final parsed = TaskParsing.fromMap(map);

      expect(parsed.id, original.id);
      expect(parsed.title, original.title);
      expect(parsed.description, original.description);
      expect(parsed.status, original.status);
      expect(parsed.priority, original.priority);
      expect(parsed.tags, original.tags);
      expect(parsed.taskKey, original.taskKey);
      expect(parsed.dependsOn, original.dependsOn);
    });
  });

  group('SyncConflict Tests', () {
    test('SyncConflict stores all fields correctly', () {
      final now = DateTime.now();
      final earlier = now.subtract(const Duration(seconds: 3));

      final conflict = SyncConflict(
        entityType: 'task',
        entityId: '550e8400-e29b-41d4-a716-446655440050',
        entityTitle: 'Conflict Task',
        localModifiedAt: earlier,
        remoteModifiedAt: now,
        localData: {'title': 'Local version'},
        remoteData: {'title': 'Remote version'},
      );

      expect(conflict.entityType, 'task');
      expect(conflict.entityTitle, 'Conflict Task');
      expect(conflict.localModifiedAt, earlier);
      expect(conflict.remoteModifiedAt, now);
      expect(conflict.localData['title'], 'Local version');
      expect(conflict.remoteData['title'], 'Remote version');
    });
  });

  // ── Extended Sync Serialization Tests ──

  group('Extended Sync Serialization Tests', () {
    test('Task toSyncMap includes subtasks and time tracking', () {
      final now = DateTime.now();
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440002',
        title: 'Full Task',
        createdAt: now,
        subtasks: ['0:Design', '1:Code'],
        estimatedMinutes: 120,
        trackedMinutes: 45,
        recurrence: 'weekly',
      );

      final map = task.toSyncMap('user1');
      expect(map['subtasks'], ['0:Design', '1:Code']);
      expect(map['estimated_minutes'], 120);
      expect(map['tracked_minutes'], 45);
      expect(map['recurrence'], 'weekly');
    });

    test('Task fromMap handles new fields', () {
      final data = {
        'id': '550e8400-e29b-41d4-a716-446655440003',
        'title': 'From Map',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'todo',
        'priority': 'medium',
        'subtasks': ['0:Item1', '1:Item2'],
        'estimated_minutes': 60,
        'tracked_minutes': 30,
        'recurrence': 'daily',
      };

      final task = TaskParsing.fromMap(data);
      expect(task.subtasks.length, 2);
      expect(task.estimatedMinutes, 60);
      expect(task.trackedMinutes, 30);
      expect(task.recurrence, 'daily');
    });

    test('Task fromMap handles missing new fields gracefully', () {
      final data = {
        'id': '550e8400-e29b-41d4-a716-446655440004',
        'title': 'Old Task',
        'created_at': DateTime.now().toIso8601String(),
        'status': 'todo',
        'priority': 'low',
      };

      final task = TaskParsing.fromMap(data);
      expect(task.subtasks, isEmpty);
      expect(task.estimatedMinutes, null);
      expect(task.trackedMinutes, 0);
      expect(task.recurrence, null);
    });
  });

  // ── SyncService Models Tests ──

  group('SyncService Models Tests', () {
    test('SyncConflict creates correctly', () {
      final conflict = SyncConflict(
        entityType: 'task',
        entityId: 'test-id',
        entityTitle: 'Test Task',
        localModifiedAt: DateTime(2026, 1, 1),
        remoteModifiedAt: DateTime(2026, 1, 2),
        localData: {'title': 'local'},
        remoteData: {'title': 'remote'},
      );
      expect(conflict.entityType, 'task');
      expect(conflict.entityTitle, 'Test Task');
    });

    test('SyncException toString formats correctly', () {
      final ex = SyncException('test error', cause: 'root cause');
      expect(ex.toString(), 'SyncException: test error');
    });

    test('RetryConfig has expected defaults', () {
      expect(RetryConfig.maxRetries, 3);
      expect(RetryConfig.initialDelay, const Duration(seconds: 1));
    });

    test('NetworkConfig has expected defaults', () {
      expect(NetworkConfig.requestTimeout, const Duration(seconds: 30));
      expect(NetworkConfig.connectionTimeout, const Duration(seconds: 10));
    });
  });

  // ── Serializer Tests ──

  group('Serializer Tests', () {
    test('taskToJson serializes all fields', () {
      final now = DateTime(2026, 3, 9, 12, 0);
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test Task',
        description: 'A description',
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        createdAt: now,
        modifiedAt: now,
        dueDate: now.add(const Duration(days: 7)),
        projectId: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
        tags: ['urgent', 'backend'],
        taskKey: 'TST-1',
        dependsOn: ['c3d4e5f6-a7b8-9012-cdef-123456789012'],
        subtasks: ['0:Write tests', '1:Setup CI'],
        estimatedMinutes: 120,
        trackedMinutes: 45,
        recurrence: 'weekly',
        attachments: ['/path/to/file.txt'],
      );

      final json = taskToJson(task);
      expect(json['id'], task.id);
      expect(json['title'], 'Test Task');
      expect(json['description'], 'A description');
      expect(json['status'], 'inProgress');
      expect(json['priority'], 'high');
      expect(json['created_at'], isNotNull);
      expect(json['modified_at'], isNotNull);
      expect(json['due_date'], isNotNull);
      expect(json['project_id'], task.projectId);
      expect(json['tags'], ['urgent', 'backend']);
      expect(json['task_key'], 'TST-1');
      expect(json['depends_on'], hasLength(1));
      expect(json['subtasks'], hasLength(2));
      expect(json['subtasks'][0], {'title': 'Write tests', 'done': false});
      expect(json['subtasks'][1], {'title': 'Setup CI', 'done': true});
      expect(json['estimated_minutes'], 120);
      expect(json['tracked_minutes'], 45);
      expect(json['recurrence'], 'weekly');
    });

    test('taskToJson handles null optional fields', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Minimal Task',
        createdAt: DateTime(2026, 1, 1),
      );

      final json = taskToJson(task);
      expect(json['description'], isNull);
      expect(json['due_date'], isNull);
      expect(json['project_id'], isNull);
      expect(json['task_key'], isNull);
      expect(json['estimated_minutes'], isNull);
      expect(json['recurrence'], isNull);
      expect(json['tags'], isEmpty);
      expect(json['depends_on'], isEmpty);
      expect(json['subtasks'], isEmpty);
    });

    test('projectToJson serializes all fields', () {
      final now = DateTime(2026, 3, 9);
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Test Project',
        projectKey: 'TST',
        description: 'A project',
        createdAt: now,
        color: '#FF5733',
        iconName: 'star',
        taskCounter: 5,
        isArchived: true,
      );

      final json = projectToJson(project);
      expect(json['id'], project.id);
      expect(json['name'], 'Test Project');
      expect(json['project_key'], 'TST');
      expect(json['description'], 'A project');
      expect(json['color'], '#FF5733');
      expect(json['icon_name'], 'star');
      expect(json['task_counter'], 5);
      expect(json['is_archived'], true);
      expect(json['created_at'], isNotNull);
      expect(json['modified_at'], isNotNull);
    });

    test('ritualToJson serializes all fields', () {
      final now = DateTime(2026, 3, 9);
      final ritual = Ritual(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Meditate',
        description: '10 minutes',
        isCompleted: true,
        createdAt: now,
        lastCompleted: now,
        streakCount: 7,
        frequency: RitualFrequency.weekly,
      );

      final json = ritualToJson(ritual);
      expect(json['id'], ritual.id);
      expect(json['title'], 'Meditate');
      expect(json['description'], '10 minutes');
      expect(json['is_completed'], true);
      expect(json['last_completed'], isNotNull);
      expect(json['streak_count'], 7);
      expect(json['frequency'], 'weekly');
    });

    test('ritualToJson handles null lastCompleted', () {
      final ritual = Ritual(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
      );

      final json = ritualToJson(ritual);
      expect(json['last_completed'], isNull);
      expect(json['is_completed'], false);
      expect(json['streak_count'], 0);
      expect(json['frequency'], 'daily');
    });
  });

  // ── Sync Config Tests ──

  group('Sync Config Tests', () {
    test('RetryConfig has expected defaults', () {
      expect(RetryConfig.maxRetries, 3);
      expect(RetryConfig.initialDelay, const Duration(seconds: 1));
      expect(RetryConfig.maxDelay, const Duration(seconds: 10));
      expect(RetryConfig.backoffMultiplier, 2.0);
    });

    test('NetworkConfig has expected defaults', () {
      expect(NetworkConfig.requestTimeout, const Duration(seconds: 30));
      expect(NetworkConfig.connectionTimeout, const Duration(seconds: 10));
    });

    test('SyncException has message and cause', () {
      final cause = Exception('root');
      final ex = SyncException('sync failed', cause: cause);
      expect(ex.message, 'sync failed');
      expect(ex.cause, cause);
      expect(ex.toString(), 'SyncException: sync failed');
    });

    test('SyncException without cause', () {
      final ex = SyncException('simple');
      expect(ex.message, 'simple');
      expect(ex.cause, isNull);
    });

    test('SyncState enum has all values', () {
      expect(
          SyncState.values,
          containsAll([
            SyncState.idle,
            SyncState.syncing,
            SyncState.success,
            SyncState.error
          ]));
    });

    test('ConflictResolution enum has all values', () {
      expect(
          ConflictResolution.values,
          containsAll(
              [ConflictResolution.keepLocal, ConflictResolution.keepRemote]));
    });
  });

  // ── Board Serializer Tests ──

  group('Board Serializer Tests', () {
    test('boardColumnToJson serializes all fields', () {
      final col = BoardColumn(
        id: 'col-1',
        title: 'To Do',
        taskIds: ['t1', 't2'],
        order: 0,
        color: '#FF0000',
        status: TaskStatus.todo,
      );

      final json = boardColumnToJson(col);

      expect(json['id'], 'col-1');
      expect(json['title'], 'To Do');
      expect(json['task_ids'], ['t1', 't2']);
      expect(json['order'], 0);
      expect(json['color'], '#FF0000');
      expect(json['status'], 'todo');
    });

    test('boardToJson includes nested columns', () {
      final board = Board(
        id: 'board-1',
        title: 'Main',
        createdAt: DateTime(2026, 1, 1),
        columns: [
          BoardColumn(
              id: 'c1', title: 'Col1', order: 0, status: TaskStatus.todo),
        ],
      );

      final json = boardToJson(board);

      expect(json['id'], 'board-1');
      expect(json['title'], 'Main');
      expect((json['columns'] as List).length, 1);
      expect((json['columns'] as List).first['title'], 'Col1');
    });

    test('projectToJson includes boards and active_board_id', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440200',
        name: 'Board Test',
        projectKey: 'BT',
        createdAt: DateTime(2026, 1, 1),
      );

      final json = projectToJson(project);

      expect(json['boards'], isA<List>());
      expect(json.containsKey('active_board_id'), isTrue);
    });

    test('boardColumnToJson round-trip structure', () {
      final col = BoardColumn(
        id: 'col-rt',
        title: 'In Progress',
        taskIds: ['t1'],
        order: 2,
        color: '#00FF00',
        status: TaskStatus.inProgress,
      );

      final json = boardColumnToJson(col);
      expect(json.keys,
          containsAll(['id', 'title', 'task_ids', 'order', 'color', 'status']));
    });

    test('boardToJson round-trip structure', () {
      final board = Board(
        id: 'board-rt',
        title: 'RT Board',
        createdAt: DateTime(2026, 1, 1),
        color: '#123456',
        columns: [
          BoardColumn(
              id: 'c1', title: 'A', order: 0, status: TaskStatus.todo),
          BoardColumn(
              id: 'c2', title: 'B', order: 1, status: TaskStatus.done),
        ],
      );

      final json = boardToJson(board);
      expect(json['id'], 'board-rt');
      expect(json['color'], '#123456');
      expect((json['columns'] as List).length, 2);
    });
  });

  // ── Board Sync Tests ──

  group('Board Sync Tests', () {
    test('toSyncMap includes boards and active_board_id', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440210',
        name: 'Sync Board',
        projectKey: 'SB',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = project.toSyncMap('user-1');

      expect(map.containsKey('boards'), isTrue);
      expect(map.containsKey('active_board_id'), isTrue);
      expect(map['boards'], isA<List>());
    });

    test('fromMap with board data reconstructs correctly', () {
      final data = {
        'id': '550e8400-e29b-41d4-a716-446655440211',
        'name': 'Board Project',
        'key': 'BP',
        'created_at': '2026-01-01T00:00:00.000',
        'boards': [
          {
            'id': 'b1',
            'title': 'Board One',
            'created_at': '2026-01-01T00:00:00.000',
            'color': '#FF0000',
            'columns': [
              {
                'id': 'c1',
                'title': 'To Do',
                'order': 0,
                'status': 'todo',
              },
            ],
          },
        ],
        'active_board_id': 'b1',
      };

      final project = ProjectParsing.fromMap(data);

      expect(project.boards.length, 1);
      expect(project.boards.first.title, 'Board One');
      expect(project.boards.first.columns.length, 1);
      expect(project.boards.first.columns.first.title, 'To Do');
      expect(project.activeBoardId, 'b1');
    });

    test('fromMap with null boards produces valid project', () {
      final data = {
        'id': '550e8400-e29b-41d4-a716-446655440212',
        'name': 'No Boards',
        'key': 'NB',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final project = ProjectParsing.fromMap(data);

      expect(project.boards, isNotEmpty);
      expect(project.columns, isNotEmpty);
    });

    test('toSyncMap -> fromMap round-trip preserves boards', () {
      final original = Project(
        id: '550e8400-e29b-41d4-a716-446655440213',
        name: 'Roundtrip',
        projectKey: 'RT',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = original.toSyncMap('user-1');
      final parsed = ProjectParsing.fromMap(map);

      expect(parsed.boards.length, original.boards.length);
      expect(parsed.activeBoardId, original.activeBoardId);
      if (original.boards.isNotEmpty) {
        expect(parsed.boards.first.title, original.boards.first.title);
        expect(parsed.boards.first.columns.length,
            original.boards.first.columns.length);
      }
    });
  });

  // ── Sync Parsing Tests ──

  group('Sync Parsing Tests', () {
    test('TaskParsing.fromMap parses all fields', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'title': 'Parsed Task',
        'description': 'A description',
        'status': 'inProgress',
        'priority': 'high',
        'created_at': '2026-03-09T12:00:00.000',
        'modified_at': '2026-03-09T13:00:00.000',
        'due_date': '2026-06-15T00:00:00.000',
        'project_id': 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
        'tags': ['alpha', 'beta'],
        'task_key': 'TST-1',
        'depends_on': ['c3d4e5f6-a7b8-9012-cdef-123456789012'],
        'subtasks': ['0:Sub1', '1:Sub2'],
        'estimated_minutes': 120,
        'tracked_minutes': 45,
        'recurrence': 'weekly',
        'attachments': ['/file.txt'],
      };

      final task = TaskParsing.fromMap(map);
      expect(task.id, map['id']);
      expect(task.title, 'Parsed Task');
      expect(task.description, 'A description');
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.high);
      expect(task.dueDate, isNotNull);
      expect(task.projectId, map['project_id']);
      expect(task.tags, ['alpha', 'beta']);
      expect(task.taskKey, 'TST-1');
      expect(task.dependsOn, hasLength(1));
      expect(task.subtasks, hasLength(2));
      expect(task.estimatedMinutes, 120);
      expect(task.trackedMinutes, 45);
      expect(task.recurrence, 'weekly');
      expect(task.attachments, ['/file.txt']);
    });

    test('TaskParsing.fromMap handles null optional fields', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'title': 'Minimal',
        'status': 'todo',
        'priority': 'medium',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final task = TaskParsing.fromMap(map);
      expect(task.description, isNull);
      expect(task.dueDate, isNull);
      expect(task.projectId, isNull);
      expect(task.taskKey, isNull);
      expect(task.tags, isEmpty);
      expect(task.dependsOn, isEmpty);
      expect(task.subtasks, isEmpty);
      expect(task.estimatedMinutes, isNull);
      expect(task.trackedMinutes, 0);
      expect(task.recurrence, isNull);
      expect(task.attachments, isEmpty);
    });

    test('TaskParsing.fromMap handles unknown status/priority', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'title': 'Unknown',
        'status': 'unknownStatus',
        'priority': 'unknownPriority',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final task = TaskParsing.fromMap(map);
      expect(task.status, TaskStatus.todo);
      expect(task.priority, TaskPriority.medium);
    });

    test('Task.toSyncMap serializes all fields', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Sync Task',
        description: 'sync desc',
        status: TaskStatus.blocked,
        priority: TaskPriority.low,
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 6, 1),
        projectId: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
        tags: ['tag1'],
        taskKey: 'SYN-1',
        dependsOn: ['c3d4e5f6-a7b8-9012-cdef-123456789012'],
        subtasks: ['0:Sub'],
        estimatedMinutes: 60,
        trackedMinutes: 20,
        recurrence: 'daily',
        attachments: ['/a.pdf'],
      );

      final map = task.toSyncMap('user-123');
      expect(map['id'], task.id);
      expect(map['user_id'], 'user-123');
      expect(map['title'], 'Sync Task');
      expect(map['status'], 'blocked');
      expect(map['priority'], 'low');
      expect(map['due_date'], isNotNull);
      expect(map['tags'], ['tag1']);
      expect(map['depends_on'], hasLength(1));
      expect(map['subtasks'], hasLength(1));
      expect(map['estimated_minutes'], 60);
      expect(map['tracked_minutes'], 20);
      expect(map['recurrence'], 'daily');
      expect(map['attachments'], ['/a.pdf']);
    });

    test('ProjectParsing.fromMap parses all fields', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'name': 'Parsed Project',
        'key': 'PP',
        'description': 'A project desc',
        'created_at': '2026-01-01T00:00:00.000',
        'modified_at': '2026-02-01T00:00:00.000',
        'color': '#FF5500',
        'icon_name': 'work',
        'task_counter': 10,
        'is_archived': true,
        'shared_with': ['user-a', 'user-b'],
        'owner_id': 'owner-1',
      };

      final project = ProjectParsing.fromMap(map);
      expect(project.name, 'Parsed Project');
      expect(project.projectKey, 'PP');
      expect(project.description, 'A project desc');
      expect(project.color, '#FF5500');
      expect(project.iconName, 'work');
      expect(project.taskCounter, 10);
      expect(project.isArchived, true);
      expect(project.sharedWith, ['user-a', 'user-b']);
      expect(project.ownerId, 'owner-1');
    });

    test('ProjectParsing.fromMap handles defaults', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'name': 'Default',
        'key': 'DF',
        'created_at': '2026-01-01T00:00:00.000',
      };

      final project = ProjectParsing.fromMap(map);
      expect(project.color, '#4A90E2');
      expect(project.taskCounter, 0);
      expect(project.isArchived, false);
      expect(project.sharedWith, isEmpty);
    });

    test('Project.toSyncMap serializes all fields', () {
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Sync Project',
        projectKey: 'SP',
        description: 'sync desc',
        createdAt: DateTime(2026, 1, 1),
        color: '#AABB00',
        iconName: 'star',
        taskCounter: 5,
        isArchived: true,
        sharedWith: ['u1'],
        ownerId: 'owner-1',
      );

      final map = project.toSyncMap('user-123');
      expect(map['user_id'], 'user-123');
      expect(map['name'], 'Sync Project');
      expect(map['key'], 'SP');
      expect(map['color'], '#AABB00');
      expect(map['icon_name'], 'star');
      expect(map['task_counter'], 5);
      expect(map['is_archived'], true);
      expect(map['shared_with'], ['u1']);
      expect(map['owner_id'], 'owner-1');
    });

    test('RitualParsing.fromMap parses all fields', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'title': 'Meditate',
        'description': '10 min',
        'is_completed': true,
        'created_at': '2026-01-01T00:00:00.000',
        'last_completed': '2026-03-09T00:00:00.000',
        'reset_time': '2026-03-08T00:00:00.000',
        'streak_count': 7,
        'frequency': 'weekly',
      };

      final ritual = RitualParsing.fromMap(map);
      expect(ritual.title, 'Meditate');
      expect(ritual.description, '10 min');
      expect(ritual.isCompleted, true);
      expect(ritual.lastCompleted, isNotNull);
      expect(ritual.resetTime, isNotNull);
      expect(ritual.streakCount, 7);
      expect(ritual.frequency, RitualFrequency.weekly);
    });

    test('RitualParsing.fromMap handles null optional fields', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'title': 'Minimal',
        'is_completed': false,
        'created_at': '2026-01-01T00:00:00.000',
        'streak_count': 0,
        'frequency': 'daily',
      };

      final ritual = RitualParsing.fromMap(map);
      expect(ritual.description, isNull);
      expect(ritual.lastCompleted, isNull);
      expect(ritual.resetTime, isNull);
    });

    test('Ritual.toSyncMap serializes all fields', () {
      final ritual = Ritual(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Sync Ritual',
        description: 'desc',
        isCompleted: true,
        createdAt: DateTime(2026, 1, 1),
        lastCompleted: DateTime(2026, 3, 1),
        resetTime: DateTime(2026, 2, 28),
        streakCount: 5,
        frequency: RitualFrequency.monthly,
      );

      final map = ritual.toSyncMap('user-123');
      expect(map['user_id'], 'user-123');
      expect(map['title'], 'Sync Ritual');
      expect(map['is_completed'], true);
      expect(map['last_completed'], isNotNull);
      expect(map['reset_time'], isNotNull);
      expect(map['streak_count'], 5);
      expect(map['frequency'], 'monthly');
    });

    test('TagParsing.fromMap parses all fields', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'name': 'urgent',
        'color': '#FF0000',
        'project_id': 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
      };

      final tag = TagParsing.fromMap(map);
      expect(tag.name, 'urgent');
      expect(tag.color, '#FF0000');
      expect(tag.projectId, map['project_id']);
    });

    test('Tag.toSyncMap serializes all fields', () {
      final tag = Tag(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'sync-tag',
        color: '#00FF00',
        projectId: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
      );

      final map = tag.toSyncMap('user-123');
      expect(map['user_id'], 'user-123');
      expect(map['name'], 'sync-tag');
      expect(map['color'], '#00FF00');
      expect(map['project_id'], tag.projectId);
    });

    test('RitualParsing.fromMap handles unknown frequency', () {
      final map = {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'title': 'Unknown Freq',
        'is_completed': false,
        'created_at': '2026-01-01T00:00:00.000',
        'streak_count': 0,
        'frequency': 'biannual',
      };

      final ritual = RitualParsing.fromMap(map);
      expect(ritual.frequency, RitualFrequency.daily);
    });

    test('TaskParsing round-trips through toSyncMap and fromMap', () {
      final original = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Round Trip',
        description: 'test',
        status: TaskStatus.inReview,
        priority: TaskPriority.low,
        createdAt: DateTime(2026, 3, 9),
        dueDate: DateTime(2026, 6, 15),
        tags: ['alpha'],
        subtasks: ['0:Sub'],
        estimatedMinutes: 30,
        trackedMinutes: 10,
        recurrence: 'monthly',
      );

      final map = original.toSyncMap('user-1');
      final restored = TaskParsing.fromMap(map);
      expect(restored.title, original.title);
      expect(restored.status, original.status);
      expect(restored.priority, original.priority);
      expect(restored.tags, original.tags);
      expect(restored.estimatedMinutes, original.estimatedMinutes);
      expect(restored.recurrence, original.recurrence);
    });

    test('ProjectParsing round-trips through toSyncMap and fromMap', () {
      final original = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Round Trip',
        projectKey: 'RT',
        description: 'test desc',
        createdAt: DateTime(2026, 1, 1),
        color: '#112233',
        taskCounter: 3,
        isArchived: false,
      );

      final map = original.toSyncMap('user-1');
      final restored = ProjectParsing.fromMap(map);
      expect(restored.name, original.name);
      expect(restored.projectKey, original.projectKey);
      expect(restored.color, original.color);
      expect(restored.taskCounter, original.taskCounter);
    });

    test('RitualParsing round-trips through toSyncMap and fromMap', () {
      final original = Ritual(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Round Trip Ritual',
        isCompleted: true,
        createdAt: DateTime(2026, 1, 1),
        lastCompleted: DateTime(2026, 3, 1),
        streakCount: 5,
        frequency: RitualFrequency.monthly,
      );

      final map = original.toSyncMap('user-1');
      final restored = RitualParsing.fromMap(map);
      expect(restored.title, original.title);
      expect(restored.isCompleted, true);
      expect(restored.streakCount, 5);
      expect(restored.frequency, RitualFrequency.monthly);
    });
  });
}
