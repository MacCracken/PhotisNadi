import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'themes/app_theme.dart';
import 'models/board.dart';
import 'models/project.dart';
import 'models/ritual.dart';
import 'models/tag.dart';
import 'models/task.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/supabase_config_service.dart';
import 'services/sync_service.dart';
import 'services/task_service.dart';
import 'services/theme_service.dart';
import 'services/yeoman_service.dart';
import 'common/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(TaskStatusAdapter());
  Hive.registerAdapter(TaskPriorityAdapter());
  Hive.registerAdapter(RitualAdapter());
  Hive.registerAdapter(RitualFrequencyAdapter());
  Hive.registerAdapter(BoardAdapter());
  Hive.registerAdapter(BoardColumnAdapter());
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(TagAdapter());

  // Open boxes with error handling
  try {
    await Hive.openBox<Task>('tasks');
    await Hive.openBox<Ritual>('rituals');
    await Hive.openBox<Project>('projects');
    await Hive.openBox<Tag>('tags');
    await Hive.openBox('settings');
  } on Exception catch (e) {
    debugPrint('Failed to open Hive boxes: $e');
  }

  // Load Supabase credentials from secure storage (configured at runtime via UI)
  final configService = SupabaseConfigService();
  final hasStoredCreds = await configService.load();
  final supabaseConfigured =
      hasStoredCreds && await configService.initializeSupabase();

  // Initialize desktop integration (not on web)
  if (!kIsWeb && isDesktop()) {
    await initDesktop();
  }

  runApp(PhotisNadiApp(
    supabaseConfigured: supabaseConfigured,
    configService: configService,
  ));
}

class PhotisNadiApp extends StatelessWidget {
  final bool supabaseConfigured;
  final SupabaseConfigService configService;

  const PhotisNadiApp({
    super.key,
    this.supabaseConfigured = false,
    required this.configService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider(create: (_) {
          final notificationService = NotificationService();
          if (!kIsWeb) {
            notificationService.initialize();
          }
          return notificationService;
        }),
        ChangeNotifierProvider(create: (_) {
          final syncService = SyncService();
          if (supabaseConfigured) {
            syncService.initialize();
          }
          return syncService;
        }),
        ChangeNotifierProvider(create: (_) {
          final yeomanService = YeomanService();
          yeomanService.initialize();
          return yeomanService;
        }),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          final primary = themeService.accentColor.color;
          return MaterialApp(
            title: 'Photis Nadi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildLightTheme(primary),
            darkTheme: AppTheme.buildDarkTheme(primary),
            themeMode:
                themeService.isEReaderMode ? ThemeMode.light : ThemeMode.system,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
            ],
            home: const HomeScreen(),
            builder: (context, child) {
              return themeService.isEReaderMode
                  ? AppTheme.applyEReaderTheme(context, child!)
                  : child!;
            },
          );
        },
      ),
    );
  }
}
