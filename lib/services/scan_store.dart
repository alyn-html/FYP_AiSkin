import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routine_store.dart';

class ScanResult {
  final DateTime date;
  final Map<String, double> scores; // per-concern severity, 0..1, independent (Gemini-derived)
  final Map<String, String> concernReasons;
  final Map<String, String> zoneNotes; // face zone -> observation
  final String summary;
  final int healthScoreDirect; // Gemini's own holistic 0-100 score
  final String? photoPath; // saved copy of the scan photo; null for scans taken before this existed

  ScanResult(
    this.date,
    this.scores, {
    this.concernReasons = const {},
    this.zoneNotes = const {},
    this.summary = '',
    this.healthScoreDirect = 70,
    this.photoPath,
  });

  String get topLabel => scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  double get topScore => scores[topLabel]!;
  int get healthScore => healthScoreDirect;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'scores': scores,
        'concernReasons': concernReasons,
        'zoneNotes': zoneNotes,
        'summary': summary,
        'healthScoreDirect': healthScoreDirect,
        if (photoPath != null) 'photoPath': photoPath,
      };

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        DateTime.parse(j['date'] as String),
        Map<String, double>.from((j['scores'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()))),
        concernReasons: j['concernReasons'] != null
            ? Map<String, String>.from(j['concernReasons'] as Map)
            : const {},
        zoneNotes: j['zoneNotes'] != null ? Map<String, String>.from(j['zoneNotes'] as Map) : const {},
        summary: j['summary'] as String? ?? '',
        healthScoreDirect: j['healthScoreDirect'] as int? ?? 70,
        photoPath: j['photoPath'] as String?,
      );
}

class ScanStore {
  ScanStore._();
  static final instance = ScanStore._();

  final results = ValueNotifier<List<ScanResult>>([]);
  static const _key = 'scan_history';
  static const _maxHistory = 7;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).map((e) => ScanResult.fromJson(e as Map<String, dynamic>)).toList();
    results.value = list;
  }

  Future<void> addResult(
    Map<String, double> scores, {
    Map<String, String> concernReasons = const {},
    Map<String, String> zoneNotes = const {},
    String summary = '',
    int healthScoreDirect = 70,
    String? photoPath,
  }) async {
    final result = ScanResult(
      DateTime.now(),
      scores,
      concernReasons: concernReasons,
      zoneNotes: zoneNotes,
      summary: summary,
      healthScoreDirect: healthScoreDirect,
      photoPath: photoPath,
    );
    var updated = [...results.value, result];
    if (updated.length > _maxHistory) {
      final removed = updated.sublist(0, updated.length - _maxHistory);
      updated = updated.sublist(updated.length - _maxHistory);
      for (final r in removed) {
        if (r.photoPath == null) continue;
        final f = File(r.photoPath!);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (e) {
            debugPrint('Could not delete old scan photo: $e');
          }
        }
      }
    }
    results.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(updated.map((r) => r.toJson()).toList()));
    await RoutineStore.instance.setLabel(result.topLabel);
  }

  Future<void> clear() async {
    results.value = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  ScanResult? get latest => results.value.isEmpty ? null : results.value.last;
}