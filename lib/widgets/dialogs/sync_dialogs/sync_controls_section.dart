import 'package:flutter/material.dart';
import '../../../services/sync_service.dart';
import '../../../common/utils.dart';

class SyncControlsSection extends StatelessWidget {
  final SyncService syncService;

  const SyncControlsSection({super.key, required this.syncService});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Enable Sync'),
          subtitle: const Text('Auto-sync every 5 minutes'),
          value: syncService.isSyncEnabled,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) => syncService.setSyncEnabled(enabled: value),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSyncStatusIcon(syncService.syncState),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _syncStateLabel(syncService.syncState),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (syncService.lastSyncedAt != null)
                    Text(
                      'Last synced: ${formatDate(syncService.lastSyncedAt!)} '
                      '${_formatTime(syncService.lastSyncedAt!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  if (syncService.syncError != null)
                    Text(
                      syncService.syncError!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync now',
              onPressed: syncService.syncState == SyncState.syncing
                  ? null
                  : syncService.syncAll,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatusIcon(SyncState state) {
    switch (state) {
      case SyncState.idle:
        return const Icon(Icons.cloud_off, size: 20, color: Colors.grey);
      case SyncState.syncing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncState.success:
        return const Icon(Icons.cloud_done, size: 20, color: Colors.green);
      case SyncState.error:
        return const Icon(Icons.cloud_off, size: 20, color: Colors.red);
    }
  }

  String _syncStateLabel(SyncState state) {
    switch (state) {
      case SyncState.idle:
        return 'Not synced';
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.success:
        return 'Synced';
      case SyncState.error:
        return 'Sync failed';
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
