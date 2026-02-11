import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages theme preferences and e-reader mode settings.
class ThemeService extends ChangeNotifier {
  bool _isEReaderMode = false;
  bool _isDarkMode = false;

  bool get isEReaderMode => _isEReaderMode;
  bool get isDarkMode => _isDarkMode;

  Future<bool> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEReaderMode = prefs.getBool('e_reader_mode') ?? false;
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load theme preferences',
        name: 'ThemeService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> toggleEReaderMode() async {
    try {
      _isEReaderMode = !_isEReaderMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('e_reader_mode', _isEReaderMode);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save e-reader mode preference',
        name: 'ThemeService',
        error: e,
        stackTrace: stackTrace,
      );
      // Revert state on failure
      _isEReaderMode = !_isEReaderMode;
      return false;
    }
  }

  Future<bool> toggleDarkMode() async {
    try {
      _isDarkMode = !_isDarkMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', _isDarkMode);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save dark mode preference',
        name: 'ThemeService',
        error: e,
        stackTrace: stackTrace,
      );
      // Revert state on failure
      _isDarkMode = !_isDarkMode;
      return false;
    }
  }
}