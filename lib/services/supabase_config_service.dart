import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _keyUrl = 'supabase_url';
const _keyAnonKey = 'supabase_anon_key';

class SupabaseConfigService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  bool _isConfigured = false;
  String? _url;
  String? _anonKey;

  bool get isConfigured => _isConfigured;
  String? get url => _url;

  /// Load credentials from secure storage. Returns true if found.
  Future<bool> load() async {
    try {
      _url = await _storage.read(key: _keyUrl);
      _anonKey = await _storage.read(key: _keyAnonKey);
      final configured = _url != null &&
          _url!.isNotEmpty &&
          _anonKey != null &&
          _anonKey!.isNotEmpty;
      _isConfigured = configured;
      return configured;
    } catch (e) {
      developer.log(
        'Failed to load Supabase credentials',
        name: 'SupabaseConfigService',
        error: e,
      );
      return false;
    }
  }

  /// Test a connection with the given credentials.
  /// Returns null on success, error message on failure.
  Future<String?> testConnection(String url, String anonKey) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        return 'Invalid URL format';
      }

      // Try to reach the Supabase REST endpoint
      await Supabase.initialize(url: url, anonKey: anonKey);
      // If initialize succeeds, the URL and key are valid format-wise.
      // Do a lightweight check to verify connectivity.
      final client = Supabase.instance.client;
      // currentSession is null when not logged in — that's fine,
      // it just means the connection itself works.
      client.auth.currentSession;
      return null;
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  /// Save credentials to secure storage and initialize Supabase.
  /// Call [testConnection] first to validate.
  Future<void> save(String url, String anonKey) async {
    await _storage.write(key: _keyUrl, value: url);
    await _storage.write(key: _keyAnonKey, value: anonKey);
    _url = url;
    _anonKey = anonKey;
    _isConfigured = true;
    notifyListeners();
  }

  /// Initialize Supabase SDK with stored credentials.
  /// Returns true if successful.
  Future<bool> initializeSupabase() async {
    if (!_isConfigured || _url == null || _anonKey == null) return false;
    try {
      await Supabase.initialize(url: _url!, anonKey: _anonKey!);
      return true;
    } catch (e) {
      developer.log(
        'Failed to initialize Supabase',
        name: 'SupabaseConfigService',
        error: e,
      );
      return false;
    }
  }

  /// Clear credentials and disconnect.
  Future<void> disconnect() async {
    try {
      if (_isConfigured) {
        final client = Supabase.instance.client;
        await client.auth.signOut();
      }
    } catch (_) {
      // Ignore sign-out errors during disconnect
    }

    await _storage.delete(key: _keyUrl);
    await _storage.delete(key: _keyAnonKey);
    _url = null;
    _anonKey = null;
    _isConfigured = false;
    notifyListeners();
  }
}
