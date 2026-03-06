import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available accent color presets.
enum AccentColor {
  indigo(Color(0xFF4F46E5), 'Indigo'),
  teal(Color(0xFF14B8A6), 'Teal'),
  rose(Color(0xFFE11D48), 'Rose'),
  amber(Color(0xFFF59E0B), 'Amber'),
  emerald(Color(0xFF10B981), 'Emerald'),
  violet(Color(0xFF8B5CF6), 'Violet'),
  sky(Color(0xFF0EA5E9), 'Sky'),
  orange(Color(0xFFF97316), 'Orange');

  final Color color;
  final String label;
  const AccentColor(this.color, this.label);
}

/// Layout density modes.
enum LayoutDensity {
  compact,
  comfortable,
}

/// Manages theme preferences: accent color, layout density, dark mode, e-reader mode.
class ThemeService extends ChangeNotifier {
  bool _isEReaderMode = false;
  bool _isDarkMode = false;
  AccentColor _accentColor = AccentColor.indigo;
  LayoutDensity _layoutDensity = LayoutDensity.comfortable;

  bool get isEReaderMode => _isEReaderMode;
  bool get isDarkMode => _isDarkMode;
  AccentColor get accentColor => _accentColor;
  LayoutDensity get layoutDensity => _layoutDensity;
  bool get isCompact => _layoutDensity == LayoutDensity.compact;

  Future<bool> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEReaderMode = prefs.getBool('e_reader_mode') ?? false;
      _isDarkMode = prefs.getBool('dark_mode') ?? false;

      final accentName = prefs.getString('accent_color');
      if (accentName != null) {
        _accentColor = AccentColor.values.firstWhere(
          (c) => c.name == accentName,
          orElse: () => AccentColor.indigo,
        );
      }

      final densityName = prefs.getString('layout_density');
      if (densityName != null) {
        _layoutDensity = LayoutDensity.values.firstWhere(
          (d) => d.name == densityName,
          orElse: () => LayoutDensity.comfortable,
        );
      }

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
      _isDarkMode = !_isDarkMode;
      return false;
    }
  }

  Future<bool> setAccentColor(AccentColor color) async {
    try {
      _accentColor = color;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accent_color', color.name);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save accent color',
        name: 'ThemeService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> setLayoutDensity(LayoutDensity density) async {
    try {
      _layoutDensity = density;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('layout_density', density.name);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save layout density',
        name: 'ThemeService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
