import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_chat_service.dart';

class DailyTipService {
  DailyTipService._();
  static final instance = DailyTipService._();

  final tip = ValueNotifier<String?>(null);
  static const _tipKey = 'daily_tip_text';
  static const _dateKey = 'daily_tip_date';
  static const _fallback = "Omega-3 rich foods like avocado & salmon boost your skin's natural glow.";

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final storedDate = prefs.getString(_dateKey);
    final storedTip = prefs.getString(_tipKey);

    if (storedDate == today && storedTip != null && storedTip.isNotEmpty) {
      tip.value = storedTip;
      return;
    }

    // Show something immediately (stale tip or fallback) while we fetch today's.
    tip.value = (storedTip != null && storedTip.isNotEmpty) ? storedTip : _fallback;

    try {
      final fresh = await AiChatService.generateDailyTip();
      tip.value = fresh;
      await prefs.setString(_tipKey, fresh);
      await prefs.setString(_dateKey, today);
    } catch (e) {
      debugPrint('Daily tip generation failed, keeping fallback: $e');
    }
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}