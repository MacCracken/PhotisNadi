import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/common/utils.dart';
import 'package:photisnadi/common/performance_monitor.dart';

void main() {
  group('Task Model Tests', () {
    test('copyWith should preserve all fields', () {
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440010',
        title: 'Test',
        description: 'Desc',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
        createdAt: DateTime(2024, 1, 1),
        dueDate: DateTime(2024, 2, 1),
        projectId: '550e8400-e29b-41d4-a716-446655440099',
        tags: ['tag1'],
        taskKey: 'P-1',
      );

      final copy = task.copyWith(title: 'Updated');

      expect(copy.title, 'Updated');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440010');
      expect(copy.description, 'Desc');
      expect(copy.status, TaskStatus.todo);
      expect(copy.priority, TaskPriority.high);
      expect(copy.projectId, '550e8400-e29b-41d4-a716-446655440099');
      expect(copy.tags, ['tag1']);
      expect(copy.taskKey, 'P-1');
    });

    test('modifiedAt defaults to createdAt', () {
      final now = DateTime(2024, 1, 1);
      final task = Task(
        id: '550e8400-e29b-41d4-a716-446655440011',
        title: 'Test',
        createdAt: now,
      );

      expect(task.modifiedAt, now);
    });
  });

  group('Project Model Tests', () {
    test('generateNextTaskKey increments counter', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(project.generateNextTaskKey(), 'TST-1');
      expect(project.generateNextTaskKey(), 'TST-2');
      expect(project.generateNextTaskKey(), 'TST-3');
      expect(project.taskCounter, 3);
    });

    test('copyWith should preserve all fields', () {
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440020',
        name: 'Test',
        projectKey: 'TST',
        description: 'A project',
        createdAt: DateTime(2024, 1, 1),
        color: '#FF0000',
        iconName: 'star',
        taskCounter: 5,
        isArchived: true,
      );

      final copy = project.copyWith(name: 'Updated');

      expect(copy.name, 'Updated');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440020');
      expect(copy.projectKey, 'TST');
      expect(copy.description, 'A project');
      expect(copy.color, '#FF0000');
      expect(copy.iconName, 'star');
      expect(copy.taskCounter, 5);
      expect(copy.isArchived, true);
    });

    test('modifiedAt defaults to createdAt', () {
      final now = DateTime(2024, 1, 1);
      final project = Project(
        id: '550e8400-e29b-41d4-a716-446655440021',
        name: 'Test',
        projectKey: 'TST',
        createdAt: now,
      );

      expect(project.modifiedAt, now);
    });
  });

  group('Board Model Tests', () {
    test('BoardColumn should store tasks', () {
      final column = BoardColumn(
        id: '550e8400-e29b-41d4-a716-446655440030',
        title: 'To Do',
        taskIds: ['task-1', 'task-2'],
        status: TaskStatus.todo,
      );

      expect(column.taskIds.length, 2);
      expect(column.title, 'To Do');
    });

    test('Board should store column ids', () {
      final board = Board(
        id: '550e8400-e29b-41d4-a716-446655440031',
        title: 'Main Board',
        createdAt: DateTime(2024, 1, 1),
        columnIds: ['col-1', 'col-2', 'col-3'],
      );

      expect(board.columnIds.length, 3);
      expect(board.title, 'Main Board');
    });

    test('BoardColumn copyWith should preserve fields', () {
      final column = BoardColumn(
        id: '550e8400-e29b-41d4-a716-446655440032',
        title: 'To Do',
        order: 0,
        color: '#FF0000',
        status: TaskStatus.todo,
      );

      final copy = column.copyWith(title: 'Done');

      expect(copy.title, 'Done');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440032');
      expect(copy.order, 0);
      expect(copy.color, '#FF0000');
    });

    test('Board copyWith should preserve fields', () {
      final board = Board(
        id: '550e8400-e29b-41d4-a716-446655440033',
        title: 'Main Board',
        createdAt: DateTime(2024, 1, 1),
        color: '#00FF00',
      );

      final copy = board.copyWith(title: 'Updated Board');

      expect(copy.title, 'Updated Board');
      expect(copy.id, '550e8400-e29b-41d4-a716-446655440033');
      expect(copy.color, '#00FF00');
    });

    test('Board creates with valid data', () {
      final board = Board(
        id: '550e8400-e29b-41d4-a716-446655440070',
        title: 'Test Board',
        createdAt: DateTime.now(),
      );
      expect(board.title, 'Test Board');
    });

    test('Board rejects empty ID', () {
      expect(
        () => Board(id: '', title: 'Test', createdAt: DateTime.now()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board rejects empty title', () {
      expect(
        () => Board(
          id: '550e8400-e29b-41d4-a716-446655440071',
          title: '',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board.defaultBoard creates valid board', () {
      final board = Board.defaultBoard('test-id');
      expect(board.title, 'Default');
      expect(board.columns.length, 5);
    });

    test('Board.bugTracking template has correct columns', () {
      final board = Board.bugTracking('test-id');
      expect(board.title, 'Bug Tracking');
      expect(board.columns.any((c) => c.title == 'New'), isTrue);
    });

    test('Board.sprint template has correct columns', () {
      final board = Board.sprint('test-id');
      expect(board.title, 'Sprint');
      expect(board.columns.any((c) => c.title == 'Backlog'), isTrue);
    });

    test('BoardColumn creates correctly', () {
      final col = BoardColumn(
        id: '550e8400-e29b-41d4-a716-446655440072',
        title: 'Test',
        status: TaskStatus.todo,
      );
      expect(col.title, 'Test');
      expect(col.status, TaskStatus.todo);
    });
  });

  group('Validation Tests', () {
    test('isValidHexColor validates correct hex colors', () {
      expect(isValidHexColor('#FF0000'), isTrue);
      expect(isValidHexColor('FF0000'), isTrue);
      expect(isValidHexColor('#AABBCC'), isTrue);
      expect(isValidHexColor('#ff0000'), isTrue);
      expect(isValidHexColor('#FF0000FF'), isTrue);
    });

    test('isValidHexColor rejects invalid hex colors', () {
      expect(isValidHexColor(''), isFalse);
      expect(isValidHexColor('#GG0000'), isFalse);
      expect(isValidHexColor('#FFF'), isFalse);
      expect(isValidHexColor('invalid'), isFalse);
      expect(isValidHexColor('#12345'), isFalse);
    });

    test('normalizeHexColor normalizes colors correctly', () {
      expect(normalizeHexColor('#FF0000'), '#FF0000');
      expect(normalizeHexColor('FF0000'), '#FF0000');
      expect(normalizeHexColor(' #aabbcc '), '#AABBCC');
      expect(normalizeHexColor('#ff0000ff'), '#FF0000FF');
    });

    test('isValidProjectKey validates project keys', () {
      expect(isValidProjectKey('AB'), isTrue);
      expect(isValidProjectKey('ABC'), isTrue);
      expect(isValidProjectKey('ABCD'), isTrue);
      expect(isValidProjectKey('ABCDE'), isTrue);
      expect(isValidProjectKey('A1'), isTrue);
      expect(isValidProjectKey('A12'), isTrue);
    });

    test('isValidProjectKey rejects invalid project keys', () {
      expect(isValidProjectKey(''), isFalse);
      expect(isValidProjectKey('A'), isFalse);
      expect(isValidProjectKey('ABCDEF'), isFalse);
      expect(isValidProjectKey('ab'), isFalse);
      expect(isValidProjectKey('AB!'), isFalse);
      expect(isValidProjectKey('A B'), isFalse);
    });

    test('isValidUuid validates UUIDs', () {
      expect(isValidUuid('550e8400-e29b-41d4-a716-446655440000'), isTrue);
      expect(isValidUuid('550E8400-E29B-41D4-A716-446655440000'), isTrue);
    });

    test('isValidUuid rejects invalid UUIDs', () {
      expect(isValidUuid(''), isFalse);
      expect(isValidUuid('invalid'), isFalse);
      expect(isValidUuid('550e8400-e29b-41d4-a716'), isFalse);
      expect(isValidUuid('550e8400-e29b-41d4-a716-4466554400000'), isFalse);
      expect(isValidUuid('550e8400-e29b-41d4-a716-44665544000g'), isFalse);
    });
  });

  group('Model Validation Tests', () {
    test('Task throws on invalid ID', () {
      expect(
        () => Task(
          id: 'invalid',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Task throws on empty title', () {
      expect(
        () => Task(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '   ',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Task throws on invalid projectId', () {
      expect(
        () => Task(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: 'Test',
          createdAt: DateTime.now(),
          projectId: 'invalid',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Project throws on invalid ID', () {
      expect(
        () => Project(
          id: 'invalid',
          name: 'Test',
          projectKey: 'TST',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Project throws on empty name', () {
      expect(
        () => Project(
          id: '550e8400-e29b-41d4-a716-446655440000',
          name: '   ',
          projectKey: 'TST',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Project throws on invalid project key', () {
      expect(
        () => Project(
          id: '550e8400-e29b-41d4-a716-446655440000',
          name: 'Test',
          projectKey: 'too_long_key',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board throws on empty ID', () {
      expect(
        () => Board(
          id: '',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Board throws on empty title', () {
      expect(
        () => Board(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('BoardColumn throws on empty title', () {
      expect(
        () => BoardColumn(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '',
          status: TaskStatus.todo,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Ritual throws on invalid ID', () {
      expect(
        () => Ritual(
          id: 'invalid',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Ritual throws on empty title', () {
      expect(
        () => Ritual(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: '   ',
          createdAt: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Tag Model Tests', () {
    test('Tag creates successfully with valid data', () {
      final tag = Tag(
        id: '550e8400-e29b-41d4-a716-446655440040',
        name: 'Bug',
        color: '#E53935',
        projectId: '550e8400-e29b-41d4-a716-446655440099',
      );

      expect(tag.name, 'Bug');
      expect(tag.color, '#E53935');
    });

    test('Tag throws on invalid ID', () {
      expect(
        () => Tag(
          id: 'invalid',
          name: 'Bug',
          color: '#E53935',
          projectId: '550e8400-e29b-41d4-a716-446655440099',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag throws on empty name', () {
      expect(
        () => Tag(
          id: '550e8400-e29b-41d4-a716-446655440040',
          name: '   ',
          color: '#E53935',
          projectId: '550e8400-e29b-41d4-a716-446655440099',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag throws on invalid color', () {
      expect(
        () => Tag(
          id: '550e8400-e29b-41d4-a716-446655440040',
          name: 'Bug',
          color: 'not-a-color',
          projectId: '550e8400-e29b-41d4-a716-446655440099',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag throws on invalid projectId', () {
      expect(
        () => Tag(
          id: '550e8400-e29b-41d4-a716-446655440040',
          name: 'Bug',
          color: '#E53935',
          projectId: 'invalid',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Tag copyWith preserves fields', () {
      final tag = Tag(
        id: '550e8400-e29b-41d4-a716-446655440040',
        name: 'Bug',
        color: '#E53935',
        projectId: '550e8400-e29b-41d4-a716-446655440099',
      );

      final copy = tag.copyWith(name: 'Feature');

      expect(copy.name, 'Feature');
      expect(copy.id, tag.id);
      expect(copy.color, '#E53935');
      expect(copy.projectId, tag.projectId);
    });
  });

  // ── Validator Tests ──

  group('Validator Tests', () {
    test('isValidHexColor accepts valid colors', () {
      expect(isValidHexColor('#FF0000'), isTrue);
      expect(isValidHexColor('#ff0000'), isTrue);
      expect(isValidHexColor('FF0000'), isTrue);
      expect(isValidHexColor('#FF000080'), isTrue);
    });

    test('isValidHexColor rejects invalid colors', () {
      expect(isValidHexColor(''), isFalse);
      expect(isValidHexColor('#FFF'), isFalse);
      expect(isValidHexColor('#GGGGGG'), isFalse);
      expect(isValidHexColor('not-a-color'), isFalse);
    });

    test('normalizeHexColor normalizes formats', () {
      expect(normalizeHexColor('ff0000'), '#FF0000');
      expect(normalizeHexColor('#ff0000'), '#FF0000');
      expect(normalizeHexColor('  #ff0000  '), '#FF0000');
    });

    test('isValidProjectKey validates keys', () {
      expect(isValidProjectKey('AB'), isTrue);
      expect(isValidProjectKey('ABCDE'), isTrue);
      expect(isValidProjectKey('A1'), isTrue);
      expect(isValidProjectKey(''), isFalse);
      expect(isValidProjectKey('A'), isFalse);
      expect(isValidProjectKey('ABCDEF'), isFalse);
      expect(isValidProjectKey('ab'), isFalse);
      expect(isValidProjectKey('A B'), isFalse);
    });

    test('isValidUuid validates UUIDs', () {
      expect(isValidUuid('550e8400-e29b-41d4-a716-446655440000'), isTrue);
      expect(isValidUuid('not-a-uuid'), isFalse);
      expect(isValidUuid(''), isFalse);
    });

    test('capitalizeFirst works correctly', () {
      expect(capitalizeFirst('hello'), 'Hello');
      expect(capitalizeFirst(''), '');
      expect(capitalizeFirst('a'), 'A');
      expect(capitalizeFirst('Hello'), 'Hello');
    });

    test('generateProjectKey generates correct keys', () {
      expect(generateProjectKey('My Project'), 'MP');
      expect(generateProjectKey('A Big Cool Project'), 'ABC');
      expect(generateProjectKey('Solo'), 'SOL');
      expect(generateProjectKey('Hi'), 'HI');
      expect(generateProjectKey('A'), 'A');
      expect(generateProjectKey(''), '');
      expect(generateProjectKey('   '), '');
    });
  });

  // ── Utils Tests ──

  group('Utils Tests', () {
    test('parseColor parses valid hex colors', () {
      final color = parseColor('#FF0000');
      expect(color.toARGB32(), isNonZero);
    });

    test('parseColor returns blue for invalid input', () {
      final color = parseColor('not-a-color');
      expect(color, Colors.blue);
    });

    test('parseColor handles missing hash prefix', () {
      final color = parseColor('FF0000');
      expect(color.toARGB32(), isNonZero);
    });

    test('formatDate formats correctly', () {
      final date = DateTime(2026, 3, 9);
      expect(formatDate(date), '9/3/2026');
    });

    test('formatPriority formats all priorities', () {
      expect(formatPriority(TaskPriority.low), 'Low');
      expect(formatPriority(TaskPriority.medium), 'Medium');
      expect(formatPriority(TaskPriority.high), 'High');
    });

    test('formatStatus formats all statuses', () {
      expect(formatStatus(TaskStatus.todo), 'Todo');
      expect(formatStatus(TaskStatus.inProgress), 'In Progress');
      expect(formatStatus(TaskStatus.inReview), 'In Review');
      expect(formatStatus(TaskStatus.blocked), 'Blocked');
      expect(formatStatus(TaskStatus.done), 'Done');
    });

    test('getPriorityColor returns correct colors', () {
      expect(getPriorityColor(TaskPriority.high), Colors.red);
      expect(getPriorityColor(TaskPriority.medium), Colors.orange);
      expect(getPriorityColor(TaskPriority.low), Colors.green);
    });
  });

  // ── Task Model Extended Tests ──

  group('Task Model Extended Tests', () {
    test('formattedTrackedTime formats zero', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        trackedMinutes: 0,
      );
      expect(task.formattedTrackedTime, '0m');
    });

    test('formattedTrackedTime formats minutes only', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        trackedMinutes: 45,
      );
      expect(task.formattedTrackedTime, '45m');
    });

    test('formattedTrackedTime formats hours only', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        trackedMinutes: 120,
      );
      expect(task.formattedTrackedTime, '2h');
    });

    test('formattedTrackedTime formats hours and minutes', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        trackedMinutes: 90,
      );
      expect(task.formattedTrackedTime, '1h 30m');
    });

    test('parsedSubtasks parses correctly', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        subtasks: ['0:Do thing', '1:Done thing', '0:Another'],
      );
      final parsed = task.parsedSubtasks;
      expect(parsed.length, 3);
      expect(parsed[0].title, 'Do thing');
      expect(parsed[0].done, false);
      expect(parsed[1].title, 'Done thing');
      expect(parsed[1].done, true);
      expect(parsed[2].title, 'Another');
      expect(parsed[2].done, false);
    });

    test('subtasksDone counts completed subtasks', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        subtasks: ['0:A', '1:B', '1:C', '0:D'],
      );
      expect(task.subtasksDone, 2);
    });

    test('addSubtask appends new subtask', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
      );
      task.addSubtask('New subtask');
      expect(task.subtasks.length, 1);
      expect(task.subtasks.first, '0:New subtask');
    });

    test('toggleSubtask toggles completion', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        subtasks: ['0:Do it'],
      );
      task.toggleSubtask(0);
      expect(task.subtasks[0], '1:Do it');
      task.toggleSubtask(0);
      expect(task.subtasks[0], '0:Do it');
    });

    test('toggleSubtask ignores out of range', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        subtasks: ['0:A'],
      );
      task.toggleSubtask(-1);
      task.toggleSubtask(5);
      expect(task.subtasks.length, 1);
    });

    test('removeSubtask removes at index', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        subtasks: ['0:A', '0:B', '0:C'],
      );
      task.removeSubtask(1);
      expect(task.subtasks.length, 2);
      expect(task.parsedSubtasks[0].title, 'A');
      expect(task.parsedSubtasks[1].title, 'C');
    });

    test('removeSubtask ignores out of range', () {
      final task = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Test',
        createdAt: DateTime.now(),
        subtasks: ['0:A'],
      );
      task.removeSubtask(-1);
      task.removeSubtask(5);
      expect(task.subtasks.length, 1);
    });

    test('copyWith preserves all fields', () {
      final original = Task(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        title: 'Original',
        description: 'desc',
        status: TaskStatus.inProgress,
        priority: TaskPriority.high,
        createdAt: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 2, 1),
        projectId: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
        tags: ['tag1'],
        taskKey: 'TST-1',
        dependsOn: ['c3d4e5f6-a7b8-9012-cdef-123456789012'],
        subtasks: ['0:Sub'],
        estimatedMinutes: 60,
        trackedMinutes: 30,
        recurrence: 'daily',
        attachments: ['/file.txt'],
      );

      final copy = original.copyWith(title: 'Changed');
      expect(copy.title, 'Changed');
      expect(copy.description, 'desc');
      expect(copy.status, TaskStatus.inProgress);
      expect(copy.priority, TaskPriority.high);
      expect(copy.projectId, original.projectId);
      expect(copy.tags, ['tag1']);
      expect(copy.estimatedMinutes, 60);
      expect(copy.trackedMinutes, 30);
      expect(copy.recurrence, 'daily');
      expect(copy.attachments, ['/file.txt']);
    });

    test('constructor rejects empty title', () {
      expect(
        () => Task(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          title: '   ',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects invalid UUID', () {
      expect(
        () => Task(
          id: 'not-a-uuid',
          title: 'Test',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects invalid project ID', () {
      expect(
        () => Task(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          title: 'Test',
          createdAt: DateTime.now(),
          projectId: 'bad-id',
        ),
        throwsArgumentError,
      );
    });
  });

  // ── Project Model Extended Tests ──

  group('Project Model Extended Tests', () {
    test('generateNextTaskKey increments counter', () {
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime.now(),
      );
      expect(project.generateNextTaskKey(), 'TST-1');
      expect(project.generateNextTaskKey(), 'TST-2');
      expect(project.taskCounter, 2);
    });

    test('defaultColumns has 5 statuses', () {
      final cols = Project.defaultColumns();
      expect(cols.length, 5);
      expect(cols[0].status, TaskStatus.todo);
      expect(cols[4].status, TaskStatus.done);
    });

    test('activeBoard returns first board when no activeBoardId', () {
      final board = Board(
        id: 'board-1',
        title: 'My Board',
        createdAt: DateTime.now(),
      );
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime.now(),
        boards: [board],
      );
      expect(project.activeBoard, isNotNull);
      expect(project.activeBoard!.title, 'My Board');
    });

    test('activeColumns falls back to project columns', () {
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime.now(),
      );
      expect(project.activeColumns, isNotEmpty);
    });

    test('constructor normalizes color', () {
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime.now(),
        color: '#aabb11',
      );
      expect(project.color, '#AABB11');
    });

    test('constructor falls back to default for invalid color', () {
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime.now(),
        color: 'not-a-color',
      );
      expect(project.color, '#4A90E2');
    });

    test('constructor rejects invalid project key', () {
      expect(
        () => Project(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          name: 'Test',
          projectKey: 'toolong!',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects empty name', () {
      expect(
        () => Project(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          name: '',
          projectKey: 'TST',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('copyWith overrides fields', () {
      final original = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Original',
        projectKey: 'OG',
        createdAt: DateTime.now(),
      );
      final copy = original.copyWith(name: 'Changed', isArchived: true);
      expect(copy.name, 'Changed');
      expect(copy.isArchived, true);
      expect(copy.projectKey, 'OG');
    });

    test('migration creates board from columns', () {
      final project = Project(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        name: 'Test',
        projectKey: 'TST',
        createdAt: DateTime.now(),
      );
      expect(project.boards.length, 1);
      expect(project.boards.first.title, 'Default');
      expect(project.activeBoardId, isNotNull);
    });
  });

  // ── PerformanceMonitor Tests ──

  group('PerformanceMonitor Tests', () {
    setUp(PerformanceMonitor.reset);

    test('measure returns operation result', () {
      final result = PerformanceMonitor.measure('test-op', () => 42);
      expect(result, 42);
    });

    test('measureAsync returns async operation result', () async {
      final result = await PerformanceMonitor.measureAsync(
        'async-op',
        () async => 'hello',
      );
      expect(result, 'hello');
    });

    test('reset clears all metrics', () {
      PerformanceMonitor.measure('op1', () => 1);
      PerformanceMonitor.measure('op2', () => 2);
      PerformanceMonitor.reset();
      PerformanceMonitor.report();
    });

    test('measure handles exceptions', () {
      expect(
        () => PerformanceMonitor.measure('fail', () => throw Exception('boom')),
        throwsException,
      );
    });

    test('measureAsync handles async exceptions', () async {
      expect(
        () => PerformanceMonitor.measureAsync(
          'async-fail',
          () async => throw Exception('boom'),
        ),
        throwsException,
      );
    });
  });

  // ── formatStatus Extended Tests ──

  group('formatStatus Extended Tests', () {
    test('formats camelCase enum names with spaces', () {
      expect(formatStatus(TaskStatus.inProgress), 'In Progress');
      expect(formatStatus(TaskStatus.inReview), 'In Review');
    });

    test('formats single-word enum names with capital', () {
      expect(formatStatus(TaskStatus.todo), 'Todo');
      expect(formatStatus(TaskStatus.blocked), 'Blocked');
      expect(formatStatus(TaskStatus.done), 'Done');
    });
  });

  // ── weekNumber Extended Tests ──

  group('weekNumber Extended Tests', () {
    test('same week returns same number', () {
      // Mon Mar 9 and Fri Mar 13, 2026 are same week
      expect(
        Ritual.weekNumber(DateTime(2026, 3, 9)),
        Ritual.weekNumber(DateTime(2026, 3, 13)),
      );
    });

    test('different weeks return different numbers', () {
      // Mar 9 (Mon) and Mar 16 (Mon) are in consecutive weeks
      expect(
        Ritual.weekNumber(DateTime(2026, 3, 9)),
        isNot(Ritual.weekNumber(DateTime(2026, 3, 16))),
      );
    });

    test('year boundary - Dec 31 2025 is week 1 of 2026', () {
      // Dec 31, 2025 is a Wednesday. ISO week containing Jan 1, 2026 (Thu)
      // is week 1 of 2026. Dec 31 is in that same week.
      final dec31 = DateTime(2025, 12, 31);
      final jan1 = DateTime(2026, 1, 1);
      expect(Ritual.weekNumber(dec31), Ritual.weekNumber(jan1));
    });

    test('weekNumber always returns positive', () {
      // Test various dates across the year
      for (var month = 1; month <= 12; month++) {
        final date = DateTime(2026, month, 15);
        expect(Ritual.weekNumber(date), greaterThan(0));
      }
    });

    test('Jan 1 on Thursday is week 1', () {
      // 2026: Jan 1 is Thursday => week 1
      expect(Ritual.weekNumber(DateTime(2026, 1, 1)), 1);
    });
  });
}
