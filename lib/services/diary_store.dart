import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaryEntry {
  final DateTime date;
  final String? condition;
  final String? mood;
  final double? sleep;
  final double? water;
  final double? stress;
  final String? products;
  final String? diet;
  final String? scanTopConcern;
  final int? scanHealthScore;

  const DiaryEntry({
    required this.date,
    this.condition,
    this.mood,
    this.sleep,
    this.water,
    this.stress,
    this.products,
    this.diet,
    this.scanTopConcern,
    this.scanHealthScore,
  });

  bool get hasManualLog => condition != null || mood != null;
  bool get hasScan => scanTopConcern != null;

  DiaryEntry copyWith({
    String? condition,
    String? mood,
    double? sleep,
    double? water,
    double? stress,
    String? products,
    String? diet,
    String? scanTopConcern,
    int? scanHealthScore,
  }) {
    return DiaryEntry(
      date: date,
      condition: condition ?? this.condition,
      mood: mood ?? this.mood,
      sleep: sleep ?? this.sleep,
      water: water ?? this.water,
      stress: stress ?? this.stress,
      products: products ?? this.products,
      diet: diet ?? this.diet,
      scanTopConcern: scanTopConcern ?? this.scanTopConcern,
      scanHealthScore: scanHealthScore ?? this.scanHealthScore,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        if (condition != null) 'condition': condition,
        if (mood != null) 'mood': mood,
        if (sleep != null) 'sleep': sleep,
        if (water != null) 'water': water,
        if (stress != null) 'stress': stress,
        if (products != null) 'products': products,
        if (diet != null) 'diet': diet,
        if (scanTopConcern != null) 'scanTopConcern': scanTopConcern,
        if (scanHealthScore != null) 'scanHealthScore': scanHealthScore,
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        date: DateTime.parse(j['date'] as String),
        condition: j['condition'] as String?,
        mood: j['mood'] as String?,
        sleep: (j['sleep'] as num?)?.toDouble(),
        water: (j['water'] as num?)?.toDouble(),
        stress: (j['stress'] as num?)?.toDouble(),
        products: j['products'] as String?,
        diet: j['diet'] as String?,
        scanTopConcern: j['scanTopConcern'] as String?,
        scanHealthScore: j['scanHealthScore'] as int?,
      );
}

class DiaryStore {
  DiaryStore._();
  static final instance = DiaryStore._();

  final entries = ValueNotifier<Map<String, DiaryEntry>>({});
  static const _key = 'diary_entries';

  String keyFor(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    entries.value = map.map((k, v) => MapEntry(k, DiaryEntry.fromJson(v as Map<String, dynamic>)));
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entries.value.map((k, v) => MapEntry(k, v.toJson()))));
  }

  DiaryEntry? entryFor(DateTime date) => entries.value[keyFor(date)];

  Future<void> saveManualEntry(
    DateTime date, {
    required String condition,
    required String mood,
    required double sleep,
    required double water,
    required double stress,
    required String products,
    String? diet,
  }) async {
    final key = keyFor(date);
    final existing = entries.value[key];
    final updated = (existing ?? DiaryEntry(date: date)).copyWith(
      condition: condition,
      mood: mood,
      sleep: sleep,
      water: water,
      stress: stress,
      products: products,
      diet: diet,
    );
    final map = Map<String, DiaryEntry>.from(entries.value);
    map[key] = updated;
    entries.value = map;
    await _save();
  }

  Future<void> attachScanToToday(String topConcern, int healthScore) async {
    final today = DateTime.now();
    final key = keyFor(today);
    final existing = entries.value[key];
    final updated = (existing ?? DiaryEntry(date: today)).copyWith(
      scanTopConcern: topConcern,
      scanHealthScore: healthScore,
    );
    final map = Map<String, DiaryEntry>.from(entries.value);
    map[key] = updated;
    entries.value = map;
    await _save();
  }

  Future<void> clear() async {
    entries.value = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  List<DiaryEntry> get recentSorted {
    final list = entries.value.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}