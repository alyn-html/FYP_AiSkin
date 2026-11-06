import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  PrivacyService._();
  static final instance = PrivacyService._();

  static const _channel = MethodChannel('aiskin/privacy');
  static const _key = 'privacy_mode_enabled';

  final enabled = ValueNotifier<bool>(false);
  bool _currentlySecure = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  /// Call whenever the visible tab changes (or right after toggling the setting) —
  /// applies FLAG_SECURE only when Privacy Mode is on AND the Diary tab is showing.
  Future<void> syncSecureFlag({required bool onDiaryTab}) async {
    final shouldBeSecure = enabled.value && onDiaryTab;
    if (shouldBeSecure == _currentlySecure) return;
    _currentlySecure = shouldBeSecure;
    try {
      await _channel.invokeMethod('setSecure', {'secure': shouldBeSecure});
      debugPrint('Privacy: secure flag set to $shouldBeSecure');
    } catch (e) {
      debugPrint('Could not toggle secure flag: $e');
    }
  }
}