import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/desktop_integration.dart';

bool isDesktop() {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
}

Future<void> initDesktop() async {
  await DesktopIntegration.initializeWindowManager();
  await DesktopIntegration.setupSystemTray();
}

/// Open a file with the system default application.
/// No-op on web.
void openFile(String path) {
  if (kIsWeb) return;
  if (Platform.isLinux) {
    Process.run('xdg-open', [path]);
  } else if (Platform.isMacOS) {
    Process.run('open', [path]);
  } else if (Platform.isWindows) {
    Process.run('start', [path], runInShell: true);
  }
}
