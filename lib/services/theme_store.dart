import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore {
  ThemeStore._();
  static final instance = ThemeStore._();

  final isDark = ValueNotifier<bool>(false);
  static const _key = 'dark_mode_enabled';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDark.value = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(bool value) async {
    isDark.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}