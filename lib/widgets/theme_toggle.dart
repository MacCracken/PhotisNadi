import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.palette),
          onSelected: (value) {
            switch (value) {
              case 'toggle_ereader':
                themeService.toggleEReaderMode();
                break;
              case 'toggle_dark':
                themeService.toggleDarkMode();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_ereader',
              child: Row(
                children: [
                  Icon(
                    themeService.isEReaderMode
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  const Text('E-Reader Mode'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_dark',
              child: Row(
                children: [
                  Icon(
                    themeService.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  const Text('Dark Mode'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
