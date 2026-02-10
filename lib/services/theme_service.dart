import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages theme preferences and e-reader mode settings.
class ThemeService extends ChangeNotifier {
  bool _isEReaderMode = false;
  bool _isDarkMode = false;

  bool get isEReaderMode => _isEReaderMode;
  bool get isDarkMode => _isDarkMode;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isEReaderMode = prefs.getBool('e_reader_mode') ?? false;
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    notifyListeners();
  }

  Future<void> toggleEReaderMode() async {
    _isEReaderMode = !_isEReaderMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('e_reader_mode', _isEReaderMode);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    notifyListeners();
  }
}