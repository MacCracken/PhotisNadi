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
  // Reject paths containing shell metacharacters to prevent command injection.
  if (RegExp(r'[;&|`$]').hasMatch(path)) return;
  if (Platform.isLinux) {
    Process.run('xdg-open', [path]);
  } else if (Platform.isMacOS) {
    Process.run('open', [path]);
  } else if (Platform.isWindows) {
    // Use explorer.exe instead of 'start' to avoid runInShell: true,
    // which exposes command injection risk from user-influenced paths.
    Process.run('explorer.exe', [path]);
  }
}
