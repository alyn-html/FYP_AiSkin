import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_store.dart';
import 'diary_store.dart';
import 'weather_service.dart';
import 'ai_chat_service.dart';

class InsightService {
  InsightService._();
  static final instance = InsightService._();

  final insight = ValueNotifier<String?>(null);
  final tip1 = ValueNotifier<String>('');
  final tip2 = ValueNotifier<String>('');
  final loading = ValueNotifier<bool>(false);

  static const _insightKey = 'insight_text';
  static const _tip1Key = 'insight_tip1';
  static const _tip2Key = 'insight_tip2';
  static const _freshnessKey = 'insight_freshness_key';

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// A composite key that changes whenever there's genuinely new data to react to —
  /// a new scan, a new diary entry, or a new calendar day. Regeneration is skipped
  /// whenever this key matches what was last generated, avoiding needless API calls.
  String _computeFreshnessKey() {
    final scans = ScanStore.instance.results.value;
    final lastScanDate = scans.isEmpty ? 'none' : _dateKey(scans.last.date);
    final entries = DiaryStore.instance.entries.value;
    String lastEntryKey = 'none';
    if (entries.isNotEmpty) {
      final sorted = entries.values.toList()..sort((a, b) => b.date.compareTo(a.date));
      lastEntryKey = _dateKey(sorted.first.date);
    }
    return '${scans.length}|$lastScanDate|${entries.length}|$lastEntryKey|${_dateKey(DateTime.now())}';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    insight.value = prefs.getString(_insightKey);
    tip1.value = prefs.getString(_tip1Key) ?? '';
    tip2.value = prefs.getString(_tip2Key) ?? '';
    await refreshIfStale();
  }

  Future<void> refreshIfStale() async {
    final scans = ScanStore.instance.results.value;
    if (scans.isEmpty) return; // nothing to analyze yet — no scan taken

    final prefs = await SharedPreferences.getInstance();
    final storedFreshness = prefs.getString(_freshnessKey);
    final currentFreshness = _computeFreshnessKey();
    if (storedFreshness == currentFreshness && insight.value != null) return;

    loading.value = true;
    try {
      final latest = scans.last;
      final trendScans = scans.length > 3 ? scans.sublist(scans.length - 3) : scans;
      final scanTrend = trendScans
          .map((s) => {'date': _dateKey(s.date), 'topLabel': s.topLabel, 'healthScore': s.healthScore})
          .toList();

      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final recentEntries = DiaryStore.instance.entries.value.values.where((e) => e.date.isAfter(cutoff)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      final diaryContext = recentEntries
          .map((e) => {
                'date': _dateKey(e.date),
                if (e.condition != null) 'condition': e.condition,
                if (e.mood != null) 'mood': e.mood,
                if (e.sleep != null) 'sleep': e.sleep,
                if (e.water != null) 'water': e.water,
                if (e.stress != null) 'stress': e.stress,
                if (e.diet != null) 'diet': e.diet,
              })
          .toList();

      final skinType = prefs.getString('skin_type');
      final weather = WeatherService.instance.snapshot.value;

      final result = await AiChatService.generateInsight(
        topConcern: latest.topLabel,
        currentScore: (latest.topScore * 100).round(),
        scanTrend: scanTrend,
        diaryEntries: diaryContext,
        skinType: (skinType != null && skinType.isNotEmpty) ? skinType : null,
        weatherSummary: weather?.summary,
      );

      insight.value = result['insight'];
      tip1.value = result['tip1'] ?? '';
      tip2.value = result['tip2'] ?? '';

      await prefs.setString(_insightKey, insight.value ?? '');
      await prefs.setString(_tip1Key, tip1.value);
      await prefs.setString(_tip2Key, tip2.value);
      await prefs.setString(_freshnessKey, currentFreshness);
    } catch (e) {
      debugPrint('Insight generation failed: $e');
    } finally {
      loading.value = false;
    }
  }
}