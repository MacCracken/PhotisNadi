import 'package:flutter/material.dart';
import '../../../services/sync_service.dart';
import '../../../common/utils.dart';

class ConflictsSection extends StatelessWidget {
  final SyncService syncService;

  const ConflictsSection({super.key, required this.syncService});

  @override
  Widget build(BuildContext context) {
    final conflicts = syncService.pendingConflicts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber, size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text(
              '${conflicts.length} conflict${conflicts.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            PopupMenuButton<ConflictResolution>(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: ConflictResolution.keepLocal,
                  child: Text('Keep all local'),
                ),
                const PopupMenuItem(
                  value: ConflictResolution.keepRemote,
                  child: Text('Keep all remote'),
                ),
              ],
              onSelected: syncService.resolveAllConflicts,
              child: const Text(
                'Resolve all',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...conflicts.map((conflict) => _ConflictTile(
              conflict: conflict,
              syncService: syncService,
            )),
      ],
    );
  }
}

class _ConflictTile extends StatelessWidget {
  final SyncConflict conflict;
  final SyncService syncService;

  const _ConflictTile({
    required this.conflict,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    conflict.entityType,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conflict.entityTitle,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Local: ${formatDate(conflict.localModifiedAt)}  '
              'Remote: ${formatDate(conflict.remoteModifiedAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => syncService.resolveConflict(
                    conflict,
                    ConflictResolution.keepLocal,
                  ),
                  child:
                      const Text('Keep Local', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => syncService.resolveConflict(
                    conflict,
                    ConflictResolution.keepRemote,
                  ),
                  child:
                      const Text('Keep Remote', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
