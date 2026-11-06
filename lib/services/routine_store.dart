import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

typedef _Step = (String, String, String); // name, icon, note

class RoutineStep {
  final String name, icon, note;
  const RoutineStep(this.name, this.icon, this.note);
}

enum ReminderRepeat { daily, weekly, once }

class CustomRoutineItem {
  final int id; // also used as the scheduled notification's id
  final String name;
  final int reminderHour;
  final int reminderMinute;
  final ReminderRepeat repeat;
  final int? weekday; // 1=Monday..7=Sunday, used when repeat == weekly
  final DateTime? onceDate; // used when repeat == once

  const CustomRoutineItem({
    required this.id,
    required this.name,
    required this.reminderHour,
    required this.reminderMinute,
    this.repeat = ReminderRepeat.daily,
    this.weekday,
    this.onceDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'repeat': repeat.name,
        if (weekday != null) 'weekday': weekday,
        if (onceDate != null) 'onceDate': onceDate!.toIso8601String(),
      };

  factory CustomRoutineItem.fromJson(Map<String, dynamic> j) => CustomRoutineItem(
        id: j['id'] as int,
        name: j['name'] as String,
        reminderHour: j['reminderHour'] as int,
        reminderMinute: j['reminderMinute'] as int,
        repeat: ReminderRepeat.values.firstWhere((r) => r.name == j['repeat'], orElse: () => ReminderRepeat.daily),
        weekday: j['weekday'] as int?,
        onceDate: j['onceDate'] != null ? DateTime.parse(j['onceDate'] as String) : null,
      );
}

class RoutineStore {
  RoutineStore._();
  static final instance = RoutineStore._();

  static const Map<String, (List<_Step>, List<_Step>)> _presets = {
    'default': (
      [
        ('Drink 500ml Water', '💧', 'Before anything else'),
        ('Hydrating Cleanser', '🧴', 'CeraVe Hydrating'),
        ('Hyaluronic Acid Serum', '✨', '2–3 drops, damp skin'),
        ('Moisturizer', '🫧', 'Cetaphil Cream'),
        ('SPF 50+ Sunscreen', '☀️', 'Last step, always!'),
      ],
      [
        ('Micellar Cleanser', '🌙', 'Double cleanse'),
        ('Retinol Treatment', '⭐', 'Pea-sized amount'),
        ('Hydrating Serum', '💧', 'Layer over retinol'),
        ('Rich Night Cream', '🍃', 'Lock in moisture'),
      ],
    ),
    'Acne breakout': (
      [
        ('Salicylic Acid Cleanser', '🧴', 'BHA 2%'),
        ('Niacinamide Serum', '✨', 'Oil control'),
        ('Oil-free Moisturizer', '🫧', 'Gel formula'),
        ('SPF 50+ Sunscreen', '☀️', 'Non-comedogenic'),
      ],
      [
        ('Gentle Cleanser', '🌙', 'No stripping'),
        ('Spot Treatment', '⭐', 'Benzoyl peroxide'),
        ('Light Moisturizer', '🍃', "Won't clog pores"),
      ],
    ),
    'Excess oiliness': (
      [
        ('Foaming Cleanser', '🧴', 'Removes excess oil'),
        ('Niacinamide Serum', '✨', 'Balances sebum'),
        ('Oil-free Gel Moisturizer', '🫧', 'Lightweight'),
        ('Mattifying SPF', '☀️', 'Non-greasy'),
      ],
      [
        ('Double Cleanse', '🌙', 'Oil then foam'),
        ('Clay Mask', '⭐', '2x per week'),
        ('Gel Moisturizer', '🍃', 'Oil-free'),
      ],
    ),
    'Dryness / dehydration': (
      [
        ('Drink 500ml Water', '💧', 'Before anything else'),
        ('Hydrating Cleanser', '🧴', 'CeraVe Hydrating'),
        ('Hyaluronic Acid Serum', '✨', '2–3 drops, damp skin'),
        ('Rich Moisturizer', '🫧', 'Cetaphil Cream'),
        ('SPF 50+ Sunscreen', '☀️', 'Last step, always!'),
      ],
      [
        ('Micellar Cleanser', '🌙', 'Double cleanse'),
        ('Hydrating Serum', '💧', 'Layer before cream'),
        ('Rich Night Cream', '🍃', 'Lock in moisture'),
      ],
    ),
    'Dark circles / eye bags': (
      [
        ('Gentle Cleanser', '🧴', 'Wake-up cleanse'),
        ('Vitamin C Serum', '✨', 'Brightening'),
        ('Caffeine Eye Cream', '👁️', 'De-puffing'),
        ('SPF 50+ Sunscreen', '☀️', 'Protects thin skin'),
      ],
      [
        ('Cleanser', '🌙', 'Remove makeup/SPF'),
        ('Retinol Eye Cream', '⭐', 'Small amount'),
        ('Night Cream', '🍃', 'Rich hydration'),
      ],
    ),
    'Redness / rosacea': (
      [
        ('Fragrance-free Cleanser', '🧴', 'Gentle formula'),
        ('Centella (Cica) Serum', '✨', 'Calming'),
        ('Barrier Moisturizer', '🫧', 'Ceramide-based'),
        ('Mineral SPF', '☀️', 'Zinc oxide'),
      ],
      [
        ('Gentle Cleanser', '🌙', 'No scrubbing'),
        ('Azelaic Acid', '⭐', 'Reduces redness'),
        ('Soothing Moisturizer', '🍃', 'Fragrance-free'),
      ],
    ),
  };

  final label = ValueNotifier<String>('default');
  final done = ValueNotifier<Set<String>>({});
  final customItems = ValueNotifier<List<CustomRoutineItem>>([]);

  static const _doneKey = 'routine_done_steps';
  static const _dateKey = 'routine_done_date';
  static const _labelKey = 'routine_for_label';
  static const _customKey = 'routine_custom_items';

  (List<_Step>, List<_Step>) _presetFor(String key) => _presets[key] ?? _presets['default']!;

  List<RoutineStep> get morning => _presetFor(label.value).$1.map((s) => RoutineStep(s.$1, s.$2, s.$3)).toList();
  List<RoutineStep> get night => _presetFor(label.value).$2.map((s) => RoutineStep(s.$1, s.$2, s.$3)).toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    label.value = prefs.getString(_labelKey) ?? 'default';

    final customRaw = prefs.getString(_customKey);
    if (customRaw != null) {
      customItems.value = (jsonDecode(customRaw) as List)
          .map((e) => CustomRoutineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final today = _today();
    if (prefs.getString(_dateKey) != today) {
      await prefs.setString(_dateKey, today);
      await prefs.remove(_doneKey);
      done.value = {};
      return;
    }
    done.value = (prefs.getStringList(_doneKey) ?? []).toSet();
  }

  // Re-establishes every scheduled reminder — safe to call on every app start, since
  // scheduling with the same id just replaces the pending notification.
  Future<void> resyncNotifications() async {
    for (final item in customItems.value) {
      if (item.repeat == ReminderRepeat.once && item.onceDate != null) {
        final target = DateTime(item.onceDate!.year, item.onceDate!.month, item.onceDate!.day, item.reminderHour, item.reminderMinute);
        if (target.isBefore(DateTime.now())) continue;
      }
      await NotificationService.instance.scheduleReminder(
        id: item.id,
        title: 'AiSkin Reminder 🌸',
        body: item.name,
        hour: item.reminderHour,
        minute: item.reminderMinute,
        weekday: item.repeat == ReminderRepeat.weekly ? item.weekday : null,
        onceDate: item.repeat == ReminderRepeat.once ? item.onceDate : null,
      );
    }
  }

  Future<void> setLabel(String newLabel) async {
    if (newLabel == label.value) return;
    label.value = newLabel;
    done.value = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_labelKey, newLabel);
    await prefs.remove(_doneKey);
  }

  Future<void> toggle(String section, String stepName) async {
    final key = '$section:$stepName';
    final updated = Set<String>.from(done.value);
    updated.contains(key) ? updated.remove(key) : updated.add(key);
    done.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey, _today());
    await prefs.setStringList(_doneKey, updated.toList());
  }

  bool isDone(String section, String stepName) => done.value.contains('$section:$stepName');

  Future<CustomRoutineItem> addCustomItem(
    String name,
    int hour,
    int minute, {
    ReminderRepeat repeat = ReminderRepeat.daily,
    int? weekday,
    DateTime? onceDate,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    final item = CustomRoutineItem(
      id: id, name: name, reminderHour: hour, reminderMinute: minute,
      repeat: repeat, weekday: weekday, onceDate: onceDate,
    );
    final updated = [...customItems.value, item];
    customItems.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
    await NotificationService.instance.scheduleReminder(
      id: id,
      title: 'AiSkin Reminder 🌸',
      body: name,
      hour: hour,
      minute: minute,
      weekday: repeat == ReminderRepeat.weekly ? weekday : null,
      onceDate: repeat == ReminderRepeat.once ? onceDate : null,
    );
    return item;
  }

  Future<void> editCustomItem(
    int id, {
    required String name,
    required int hour,
    required int minute,
    ReminderRepeat repeat = ReminderRepeat.daily,
    int? weekday,
    DateTime? onceDate,
  }) async {
    final idx = customItems.value.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final updatedItem = CustomRoutineItem(
      id: id, name: name, reminderHour: hour, reminderMinute: minute,
      repeat: repeat, weekday: weekday, onceDate: onceDate,
    );
    final updated = [...customItems.value];
    updated[idx] = updatedItem;
    customItems.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
    await NotificationService.instance.scheduleReminder(
      id: id,
      title: 'AiSkin Reminder 🌸',
      body: name,
      hour: hour,
      minute: minute,
      weekday: repeat == ReminderRepeat.weekly ? weekday : null,
      onceDate: repeat == ReminderRepeat.once ? onceDate : null,
    );
  }

  Future<void> removeCustomItem(int id) async {
    final updated = customItems.value.where((e) => e.id != id).toList();
    customItems.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customKey, jsonEncode(updated.map((e) => e.toJson()).toList()));
    await NotificationService.instance.cancel(id);
  }

  Future<void> reset() async {
    label.value = 'default';
    done.value = {};
    for (final item in customItems.value) {
      await NotificationService.instance.cancel(item.id);
    }
    customItems.value = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_labelKey);
    await prefs.remove(_doneKey);
    await prefs.remove(_dateKey);
    await prefs.remove(_customKey);
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}