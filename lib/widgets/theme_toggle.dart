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
              case 'toggle_dark':
                themeService.toggleDarkMode();
              case 'toggle_density':
                themeService.setLayoutDensity(
                  themeService.isCompact
                      ? LayoutDensity.comfortable
                      : LayoutDensity.compact,
                );
              case 'accent_color':
                _showAccentColorPicker(context, themeService);
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
                  ),
                  const SizedBox(width: 8),
                  const Text('Dark Mode'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_density',
              child: Row(
                children: [
                  Icon(
                    themeService.isCompact
                        ? Icons.density_small
                        : Icons.density_medium,
                  ),
                  const SizedBox(width: 8),
                  Text(themeService.isCompact ? 'Comfortable' : 'Compact'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'accent_color',
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: themeService.accentColor.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Accent Color'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAccentColorPicker(
    BuildContext context,
    ThemeService themeService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accent Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AccentColor.values.map((accent) {
            final isSelected = themeService.accentColor == accent;
            return GestureDetector(
              onTap: () {
                themeService.setAccentColor(accent);
                Navigator.pop(context);
              },
              child: Tooltip(
                message: accent.label,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accent.color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
