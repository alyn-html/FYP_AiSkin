import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'scan_store.dart';

class AiUsage {
  AiUsage._();
  static final instance = AiUsage._();
  static const dailyLimit = 5;

  final remaining = ValueNotifier<int>(dailyLimit);

  static const _countKey = 'ai_usage_count';
  static const _dateKey = 'ai_usage_date';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    if (prefs.getString(_dateKey) != today) {
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, 0);
      remaining.value = dailyLimit;
      return;
    }
    final used = prefs.getInt(_countKey) ?? 0;
    remaining.value = (dailyLimit - used).clamp(0, dailyLimit);
  }

  Future<bool> tryConsume() async {
    await load();
    if (remaining.value <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final used = (prefs.getInt(_countKey) ?? 0) + 1;
    await prefs.setInt(_countKey, used);
    remaining.value = (dailyLimit - used).clamp(0, dailyLimit);
    return true;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}

class AiReply {
  final String text;
  final String? interactionId;
  AiReply(this.text, this.interactionId);
}

class FullSkinAnalysis {
  final int healthScore;
  final String topConcern;
  final Map<String, double> concernScores; // 0..1, independent per concern (not softmax)
  final Map<String, String> concernReasons;
  final Map<String, String> zoneNotes; // face zone -> observation
  final String summary;

  FullSkinAnalysis({
    required this.healthScore,
    required this.topConcern,
    required this.concernScores,
    required this.concernReasons,
    required this.zoneNotes,
    required this.summary,
  });
}

class AiChatService {
  // Get a free key at aistudio.google.com — never commit this to a public repo.
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-3.5-flash'; // Google's current quickstart default; try gemini-2.5-flash if this errors

  static const _concernLabels = [
    'Acne breakout',
    'Excess oiliness',
    'Dryness / dehydration',
    'Dark circles / eye bags',
    'Redness / rosacea',
  ];

  static Future<Map<String, dynamic>> _post(List<Map<String, dynamic>> input) async {
    if (_apiKey.isEmpty) {
      throw Exception('Add your Gemini API key in ai_chat_service.dart first.');
    }
    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions'),
      headers: {'x-goog-api-key': _apiKey, 'content-type': 'application/json'},
      body: jsonEncode({'model': _model, 'input': input}),
    );
    if (response.statusCode != 200) {
      throw Exception('AI request failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

    /// Cached by DailyTipService to once per calendar day — never call this on every rebuild.
    static Future<String> generateDailyTip() async {
      final prefs = await SharedPreferences.getInstance();
      final skinType = prefs.getString('skin_type');
      final contextLine = (skinType != null && skinType.isNotEmpty)
          ? " The user's skin type is $skinType — work that in only if it fits naturally, don't force it."
          : '';

      final prompt = 'Write ONE short, genuinely interesting skincare tip for a mobile app\'s "Tip of the Day" card.$contextLine\n\n'
          'Avoid generic advice everyone already knows as the whole tip (plain "drink water" or "wear sunscreen" alone is too basic). '
          'About half the time, connect it to a real seasonal or environmental skin stressor people deal with day to day — haze and air '
          'pollution, strong UV, high humidity, dry air-conditioned indoor air, and so on — briefly explain how it affects skin and give one '
          'concrete, practical fix (a specific type of mask, reapplying sunscreen at a certain interval, a particular ingredient to look for). '
          'The other half of the time, share an interesting, lesser-known skincare fact or technique instead.\n\n'
          'Hard limits: 2 short sentences maximum, about 35 words total, no markdown, at most one emoji, plain text ready to show directly in the app.';

      final data = await _post([{'type': 'text', 'text': prompt}]);
      final text = _extractText(data).trim();
      if (text.isEmpty) throw Exception('Empty daily tip response');
      return text;
    }

  static String _extractText(Map<String, dynamic> data) {
    final steps = (data['steps'] as List?) ?? [];
    final buffer = StringBuffer();
    for (final step in steps) {
      if (step is Map && step['type'] == 'model_output') {
        final content = (step['content'] as List?) ?? [];
        for (final block in content) {
          if (block is Map && block['type'] == 'text') buffer.write(block['text'] ?? '');
        }
      }
    }
    return buffer.toString();
  }

  /// previous_interaction_id lets Google's server remember the conversation for us —
  /// no need to manually resend history on every message.
  static Future<AiReply> reply({
    required String userMessage,
    String? imageBase64,
    String? imageMimeType,
    String? previousInteractionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final skinType = prefs.getString('skin_type');
    final latest = ScanStore.instance.latest;

    final contextParts = <String>[];
    if (skinType != null && skinType.isNotEmpty) contextParts.add('Their skin type is $skinType.');
    if (latest != null) {
      contextParts.add('Their latest scan shows "${latest.topLabel}" as the top concern '
          '(${(latest.topScore * 100).round()}% severity), skin health score ${latest.healthScore}/100.');
    }
    final context = contextParts.isEmpty ? 'No scan or skin-type data yet.' : contextParts.join(' ');

    final preamble = 'You are a friendly, concise AI skincare assistant inside the AiSkin app. $context '
        'Give warm, practical skincare advice in under 60 words. Use 1 emoji naturally, never more. '
        'If a photo is attached, comment on what you can see and how it relates to their question. '
        'For anything medical or serious, recommend seeing a dermatologist rather than diagnosing.\n\n';

    final input = <Map<String, dynamic>>[
      {'type': 'text', 'text': '$preamble$userMessage'},
    ];
    if (imageBase64 != null) {
      input.add({'type': 'image', 'data': imageBase64, 'mime_type': imageMimeType ?? 'image/jpeg'});
    }

    final body = <String, dynamic>{};
    final data = await _postWithPreviousId(input, previousInteractionId, body);
    final text = _extractText(data);
    return AiReply(text.trim(), data['id'] as String?);
  }

  static Future<Map<String, dynamic>> _postWithPreviousId(
    List<Map<String, dynamic>> input,
    String? previousInteractionId,
    Map<String, dynamic> extra,
  ) async {
    if (_apiKey.isEmpty) {
      throw Exception('Add your Gemini API key in ai_chat_service.dart first.');
    }
    final body = <String, dynamic>{'model': _model, 'input': input};
    if (previousInteractionId != null) body['previous_interaction_id'] = previousInteractionId;
    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions'),
      headers: {'x-goog-api-key': _apiKey, 'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('AI request failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Synthesizes recent diary history, scan trend, and live weather/air-quality into one
  /// grounded, non-diagnostic insight. Cached by InsightService — never call on every rebuild.
  static Future<Map<String, String>> generateInsight({
    required String topConcern,
    required int currentScore,
    required List<Map<String, dynamic>> scanTrend, // [{date, topLabel, healthScore}, oldest first]
    required List<Map<String, dynamic>> diaryEntries, // [{date, condition, mood, sleep, water, stress, diet}]
    String? skinType,
    String? weatherSummary,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('Skin type: ${skinType ?? 'not set'}');
    buffer.writeln('Current top concern: $topConcern ($currentScore% severity)');
    if (scanTrend.isNotEmpty) {
      buffer.writeln('Recent scan trend (oldest to newest):');
      for (final s in scanTrend) {
        buffer.writeln('- ${s['date']}: ${s['topLabel']}, health score ${s['healthScore']}/100');
      }
    }
    if (diaryEntries.isNotEmpty) {
      buffer.writeln('Diary log, last ~2 weeks:');
      for (final e in diaryEntries) {
        final parts = <String>[];
        if (e['condition'] != null) parts.add('condition: ${e['condition']}');
        if (e['mood'] != null) parts.add('mood: ${e['mood']}');
        if (e['sleep'] != null) parts.add('sleep: ${e['sleep']}h');
        if (e['water'] != null) parts.add('water: ${e['water']} glasses');
        if (e['stress'] != null) parts.add('stress: ${e['stress']}/10');
        if (e['diet'] != null) parts.add('diet notes: ${e['diet']}');
        if (parts.isNotEmpty) buffer.writeln('- ${e['date']}: ${parts.join(', ')}');
      }
    }
    if (weatherSummary != null) buffer.writeln('Current local weather: $weatherSummary');

    final prompt = 'You are analyzing a skincare app user\'s full recent context to produce ONE short, '
        'genuinely personalized, evidence-based insight — not a generic tip anyone would get.\n\n'
        '${buffer.toString()}\n\n'
        'Respond in EXACTLY this format, nothing else, no markdown:\n\n'
        'INSIGHT: <2-3 sentences analyzing how these specific factors may be interacting to affect their skin right now. '
        'Reference their actual data, not generic advice. If you notice a recurring pattern across multiple scans or diary '
        'entries (e.g. a concern staying elevated alongside consistently high stress, low sleep, or certain foods), describe '
        'it as an observed pattern using hedged language like "may be linked to" or "worth keeping an eye on" — never assert '
        'a diagnosis. Never name a hormonal or medical cause yourself; if a pattern looks persistent or hormonal, say it may '
        'be worth mentioning to a dermatologist or doctor instead.>\n'
        'TIP_1: <one short, concrete, actionable tip specific to their current context>\n'
        'TIP_2: <another short, concrete, actionable tip, different angle from TIP_1>\n\n'
        'Keep INSIGHT under 55 words total. Keep each TIP under 18 words.';

    final data = await _post([{'type': 'text', 'text': prompt}]);
    final text = _extractText(data);

    final insightMatch = RegExp(r'INSIGHT:\s*(.+?)(?=\nTIP_1:|$)', dotAll: true).firstMatch(text);
    final tip1Match = RegExp(r'TIP_1:\s*(.+?)(?=\nTIP_2:|$)', dotAll: true).firstMatch(text);
    final tip2Match = RegExp(r'TIP_2:\s*(.+)', dotAll: true).firstMatch(text);

    return {
      'insight': insightMatch != null ? insightMatch.group(1)!.trim() : 'Keep logging scans and diary entries for a more personalized insight here.',
      'tip1': tip1Match != null ? tip1Match.group(1)!.trim() : '',
      'tip2': tip2Match != null ? tip2Match.group(1)!.trim() : '',
    };
  }
  /// The primary, sole skin analysis engine — no separate on-device classifier is used.
  /// Replaces the retired MobileNetV2/TFLite model entirely, per the project's revised design.
  static Future<FullSkinAnalysis> analyzeFace({
    required String imageBase64,
    required String imageMimeType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final skinType = prefs.getString('skin_type');
    final contextLine = (skinType != null && skinType.isNotEmpty) ? 'The user has told us their skin type is $skinType. ' : '';

    final prompt = 'You are performing a full AI-based skin analysis for a skincare app, directly from this photo '
        '— you are the sole analysis engine, no separate classifier model is used. $contextLine'
        'Analyze the photo for exactly these 5 concerns: ${_concernLabels.join(', ')}.\n\n'
        'Respond in EXACTLY this format, nothing else, no markdown:\n\n'
        'SCORE: <overall skin health score, 0-100, 100 = very healthy>\n'
        'TOP_CONCERN: <the single most prominent concern, matching one of the 5 names exactly>\n'
        'CONCERN: Acne breakout | <0-100 severity> | <one short sentence on what you observe and why>\n'
        'CONCERN: Excess oiliness | <0-100 severity> | <one short sentence on what you observe and why>\n'
        'CONCERN: Dryness / dehydration | <0-100 severity> | <one short sentence on what you observe and why>\n'
        'CONCERN: Dark circles / eye bags | <0-100 severity> | <one short sentence on what you observe and why>\n'
        'CONCERN: Redness / rosacea | <0-100 severity> | <one short sentence on what you observe and why>\n'
        'ZONE: Forehead | <what you observe in this area>\n'
        'ZONE: Cheeks | <what you observe in this area>\n'
        'ZONE: Under-eye | <what you observe in this area>\n'
        'ZONE: Chin | <what you observe in this area>\n'
        'SUMMARY: <one short paragraph, max 50 words, tying the analysis together in plain language>\n\n'
        "Treat each of the 5 concerns independently — skin can genuinely show multiple concerns at once, so don't force these to add up to 100%.\n"
        'This is educational analysis only, not a medical diagnosis — do not claim certainty about medical conditions.';

    final input = [
      {'type': 'text', 'text': prompt},
      {'type': 'image', 'data': imageBase64, 'mime_type': imageMimeType},
    ];

    final data = await _post(input);
    final text = _extractText(data);

    final scoreMatch = RegExp(r'SCORE:\s*(\d+)').firstMatch(text);
    final topMatch = RegExp(r'TOP_CONCERN:\s*(.+)').firstMatch(text);
    final summaryMatch = RegExp(r'SUMMARY:\s*(.+)').firstMatch(text);

    final concernScores = <String, double>{};
    final concernReasons = <String, String>{};
    for (final label in _concernLabels) {
      final pattern = RegExp('CONCERN:\\s*${RegExp.escape(label)}\\s*\\|\\s*(\\d+)\\s*\\|\\s*(.+)');
      final m = pattern.firstMatch(text);
      if (m != null) {
        concernScores[label] = (int.tryParse(m.group(1)!) ?? 20) / 100.0;
        concernReasons[label] = m.group(2)!.trim();
      } else {
        concernScores[label] = 0.2;
        concernReasons[label] = 'No specific observation available for this concern.';
      }
    }

    final zoneNotes = <String, String>{};
    for (final zoneMatch in RegExp(r'ZONE:\s*([^|]+)\|\s*(.+)').allMatches(text)) {
      zoneNotes[zoneMatch.group(1)!.trim()] = zoneMatch.group(2)!.trim();
    }

    final score = scoreMatch != null ? (int.tryParse(scoreMatch.group(1)!) ?? 70) : 70;
    var topConcern = topMatch != null ? topMatch.group(1)!.trim() : _concernLabels.first;
    if (!_concernLabels.contains(topConcern)) {
      topConcern = concernScores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }
    final summary = summaryMatch != null ? summaryMatch.group(1)!.trim() : 'Analysis complete.';

    return FullSkinAnalysis(
      healthScore: score.clamp(0, 100),
      topConcern: topConcern,
      concernScores: concernScores,
      concernReasons: concernReasons,
      zoneNotes: zoneNotes,
      summary: summary,
    );
  }
}
