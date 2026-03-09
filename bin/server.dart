import 'dart:io';
import 'package:hive/hive.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:photisnadi/models/board.dart';
import 'package:photisnadi/models/project.dart';
import 'package:photisnadi/models/ritual.dart';
import 'package:photisnadi/models/tag.dart';
import 'package:photisnadi/models/task.dart';
import 'package:photisnadi/server/api.dart';
import 'package:photisnadi/server/auth.dart';

Future<void> main() async {
  final apiKey = Platform.environment['PHOTISNADI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('PHOTISNADI_API_KEY environment variable is required');
    exit(1);
  }

  final dataDir =
      Platform.environment['PHOTISNADI_DATA_DIR'] ?? '/opt/photisnadi/data';
  final port =
      int.tryParse(Platform.environment['PHOTISNADI_API_PORT'] ?? '8081') ??
          8081;

  // Ensure data directory exists
  await Directory(dataDir).create(recursive: true);

  // Initialize Hive
  Hive.init(dataDir);
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(TaskPriorityAdapter());
  Hive.registerAdapter(RitualAdapter());
  Hive.registerAdapter(RitualFrequencyAdapter());
  Hive.registerAdapter(BoardAdapter());
  Hive.registerAdapter(BoardColumnAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(TagAdapter());

  final taskBox = await Hive.openBox<Task>('tasks');
  final projectBox = await Hive.openBox<Project>('projects');
  final ritualBox = await Hive.openBox<Ritual>('rituals');
  await Hive.openBox<Tag>('tags');

  stdout.writeln('Hive initialized at $dataDir');
  stdout.writeln(
      '  tasks=${taskBox.length} projects=${projectBox.length} rituals=${ritualBox.length}');

  // Build router
  final apiRouter = buildApiRouter(
    tasks: taskBox,
    projects: projectBox,
    rituals: ritualBox,
  );

  // Pipeline: logging + auth + CORS + router
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(apiKeyAuth(apiKey))
      .addHandler(apiRouter.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln(
      'Photis Nadi API server listening on http://${server.address.host}:${server.port}');
}
