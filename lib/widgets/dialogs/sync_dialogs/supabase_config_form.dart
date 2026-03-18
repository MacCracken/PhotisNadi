import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_config_service.dart';
import '../../../services/sync_service.dart';

class SupabaseConfigForm extends StatefulWidget {
  const SupabaseConfigForm({super.key});

  @override
  State<SupabaseConfigForm> createState() => _SupabaseConfigFormState();
}

class _SupabaseConfigFormState extends State<SupabaseConfigForm> {
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

    await configService.save(url, key);

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
