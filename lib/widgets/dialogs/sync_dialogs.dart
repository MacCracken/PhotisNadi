import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../common/utils.dart';

/// Shows the sync settings dialog
void showSyncSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _SyncSettingsDialog(),
  );
}

class _SyncSettingsDialog extends StatefulWidget {
  const _SyncSettingsDialog();

  @override
  State<_SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends State<_SyncSettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();

    if (!syncService.isInitialized) {
      return AlertDialog(
        title: const Text('Cloud Sync'),
        content: const Text(
          'Supabase is not configured. Run with:\n\n'
          'flutter run --dart-define=SUPABASE_URL=<url> '
          '--dart-define=SUPABASE_ANON_KEY=<key>',
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
                _AuthSection()
              else ...[
                _AccountSection(syncService: syncService),
                const Divider(height: 24),
                _SyncControlsSection(syncService: syncService),
                if (syncService.hasConflicts) ...[
                  const Divider(height: 24),
                  _ConflictsSection(syncService: syncService),
                ],
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
}

class _AuthSection extends StatefulWidget {
  @override
  State<_AuthSection> createState() => _AuthSectionState();
}

class _AuthSectionState extends State<_AuthSection> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSignUp ? 'Create Account' : 'Sign In',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            isDense: true,
          ),
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            isDense: true,
          ),
          obscureText: true,
          enabled: !_isLoading,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      }),
              child: Text(_isSignUp
                  ? 'Already have an account?'
                  : 'Create account'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final syncService = context.read<SyncService>();
    final error = _isSignUp
        ? await syncService.signUp(
            _emailController.text.trim(),
            _passwordController.text,
          )
        : await syncService.signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = error;
      });
    }
  }
}

class _AccountSection extends StatelessWidget {
  final SyncService syncService;

  const _AccountSection({required this.syncService});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.account_circle, size: 32, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                syncService.currentUserEmail ?? 'Signed in',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Text(
                'Cloud sync account',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => syncService.signOut(),
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}

class _SyncControlsSection extends StatelessWidget {
  final SyncService syncService;

  const _SyncControlsSection({required this.syncService});

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
          onChanged: (value) => syncService.setSyncEnabled(value),
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
                  : () => syncService.syncAll(),
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

class _ConflictsSection extends StatelessWidget {
  final SyncService syncService;

  const _ConflictsSection({required this.syncService});

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
              onSelected: (resolution) {
                syncService.resolveAllConflicts(resolution);
              },
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
                  child: const Text('Keep Local', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => syncService.resolveConflict(
                    conflict,
                    ConflictResolution.keepRemote,
                  ),
                  child: const Text('Keep Remote', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
