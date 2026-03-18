import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_config_service.dart';
import '../../../services/sync_service.dart';
import 'supabase_config_form.dart';
import 'auth_section.dart';
import 'account_section.dart';
import 'sync_controls_section.dart';
import 'conflicts_section.dart';

/// Shows the sync settings dialog
void showSyncSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const SyncSettingsDialog(),
  );
}

class SyncSettingsDialog extends StatefulWidget {
  const SyncSettingsDialog({super.key});

  @override
  State<SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends State<SyncSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final configService = context.watch<SupabaseConfigService>();

    if (!syncService.isInitialized) {
      return AlertDialog(
        title: const Text('Cloud Sync'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (configService.isConfigured) ...[
                  const Text('Supabase credentials are saved but '
                      'initialization failed. Try reconnecting.'),
                  const SizedBox(height: 16),
                  DisconnectButton(configService: configService),
                ] else ...[
                  const Text(
                    'Connect to Supabase to enable cloud sync across devices.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SupabaseConfigForm(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Cloud Sync'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!syncService.isAuthenticated)
                AuthSection()
              else ...[
                AccountSection(syncService: syncService),
                const Divider(height: 24),
                SyncControlsSection(syncService: syncService),
                if (syncService.hasConflicts) ...[
                  const Divider(height: 24),
                  ConflictsSection(syncService: syncService),
                ],
              ],
              const Divider(height: 24),
              ConnectionInfo(configService: configService),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class ConnectionInfo extends StatelessWidget {
  final SupabaseConfigService configService;

  const ConnectionInfo({super.key, required this.configService});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                configService.url ?? 'Build-time configuration',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (configService.isConfigured) ...[
          const SizedBox(height: 8),
          DisconnectButton(configService: configService),
        ],
      ],
    );
  }
}

class DisconnectButton extends StatelessWidget {
  final SupabaseConfigService configService;

  const DisconnectButton({super.key, required this.configService});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Disconnect Supabase?'),
            content: const Text(
              'This will clear your saved credentials and disable cloud sync. '
              'Your local data will not be affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        );
        if ((confirm ?? false) && context.mounted) {
          await configService.disconnect();
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      icon: const Icon(Icons.link_off, size: 16),
      label: const Text('Disconnect'),
      style: TextButton.styleFrom(foregroundColor: Colors.red),
    );
  }
}
