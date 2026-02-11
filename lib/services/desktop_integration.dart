import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';

class DesktopIntegration {
  static Future<void> initializeWindowManager() async {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> setupSystemTray() async {
    final SystemTray systemTray = SystemTray();
    final Menu trayMenu = Menu();

    await systemTray.initSystemTray(
      iconPath: 'assets/images/app_icon.png',
      toolTip: 'Photis Nadi',
    );

    await trayMenu.buildFrom([
      MenuItemLabel(
        label: 'Show',
        onClicked: (_) async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
      MenuItemLabel(
        label: 'Hide',
        onClicked: (_) async {
          await windowManager.hide();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Always on Top',
        onClicked: (_) async {
          bool isAlwaysOnTop = await windowManager.isAlwaysOnTop();
          await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (_) async {
          await windowManager.close();
        },
      ),
    ]);

    await systemTray.setContextMenu(trayMenu);
  }

  static Future<void> setupMacOSMenuBar() async {
    // This would require platform-specific implementation
    // Using window_manager as a cross-platform solution
    await windowManager.setAlwaysOnTop(false);
  }

  static Future<void> toggleAlwaysOnTop() async {
    bool isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    await windowManager.setAlwaysOnTop(!isAlwaysOnTop);
  }

  static Future<void> minimizeToTray() async {
    await windowManager.hide();
  }

  static Future<void> showFloatingWindow() async {
    await windowManager.setSize(const Size(400, 300));
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.setAlwaysOnTop(true);
  }
}
