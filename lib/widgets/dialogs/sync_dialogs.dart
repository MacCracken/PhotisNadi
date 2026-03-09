import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_config_service.dart';
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
                  // Configured but not initialized — show status
                  const Text('Supabase credentials are saved but '
                      'initialization failed. Try reconnecting.'),
                  const SizedBox(height: 16),
                  _DisconnectButton(configService: configService),
                ] else ...[
                  const Text(
                    'Connect to Supabase to enable cloud sync across devices.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _SupabaseConfigForm(),
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
              const Divider(height: 24),
              _ConnectionInfo(configService: configService),
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

// ── Supabase Configuration Form ──

class _SupabaseConfigForm extends StatefulWidget {
  @override
  State<_SupabaseConfigForm> createState() => _SupabaseConfigFormState();
}

class _SupabaseConfigFormState extends State<_SupabaseConfigForm> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isTesting = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supabase Credentials',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Supabase URL',
            hintText: 'https://your-project.supabase.co',
            isDense: true,
          ),
          keyboardType: TextInputType.url,
          enabled: !_isTesting,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _keyController,
          decoration: const InputDecoration(
            labelText: 'Anon Key',
            hintText: 'eyJ...',
            isDense: true,
          ),
          obscureText: true,
          enabled: !_isTesting,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ],
        if (_success != null) ...[
          const SizedBox(height: 8),
          Text(
            _success!,
            style: TextStyle(color: Colors.green.shade700, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(
              onPressed: _isTesting ? null : _connectAndSave,
              child: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _connectAndSave() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _error = 'Both fields are required';
        _success = null;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _error = null;
      _success = null;
    });

    final configService = context.read<SupabaseConfigService>();
    final error = await configService.testConnection(url, key);

    if (error != null) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _error = error;
        });
      }
      return;
    }

    // Test passed — save credentials
    await configService.save(url, key);

    // Initialize sync service now that Supabase is ready
    if (mounted) {
      final syncService = context.read<SyncService>();
      await syncService.initialize();
      setState(() {
        _isTesting = false;
        _success = 'Connected successfully';
      });
    }
  }
}

// ── Connection Info & Disconnect ──

class _ConnectionInfo extends StatelessWidget {
  final SupabaseConfigService configService;

  const _ConnectionInfo({required this.configService});

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
          _DisconnectButton(configService: configService),
        ],
      ],
    );
  }
}

class _DisconnectButton extends StatelessWidget {
  final SupabaseConfigService configService;

  const _DisconnectButton({required this.configService});

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
            Navigator.pop(context); // Close sync dialog
          }
        }
      },
      icon: const Icon(Icons.link_off, size: 16),
      label: const Text('Disconnect'),
      style: TextButton.styleFrom(foregroundColor: Colors.red),
    );
  }
}

// ── Auth Section ──

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

// ── Account Section ──

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
          onPressed: syncService.signOut,
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}

// ── Sync Controls Section ──

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

// ── Conflicts Section ──

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
