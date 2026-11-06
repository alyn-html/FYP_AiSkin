import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/scan_store.dart';
import '../services/routine_store.dart';
import '../services/insight_service.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  static const _steps = ['detect', 'analyze', 'recommend', 'routine', 'monitor'];
  static const _stepTitles = {
    'detect': ('🔍', 'Detect'),
    'analyze': ('📊', 'Analyze'),
    'recommend': ('💡', 'Recommend'),
    'routine': ('🌿', 'Routine'),
    'monitor': ('📈', 'Monitor'),
  };

  String _activeStep = 'routine';
  String _section = 'morning';

  static const _defaultNutrition = [
    ('🍓', 'Berries', 'Antioxidants'),
    ('🥑', 'Avocado', 'Omega-3 fats'),
    ('🥬', 'Spinach', 'Vitamins A & C'),
    ('💧', 'Water', '2L goal today'),
    ('🐟', 'Salmon', 'Collagen boost'),
    ('🥜', 'Walnuts', 'Zinc & biotin'),
  ];

  static const Map<String, List<(String, String, String)>> _nutritionPresets = {
    'Acne breakout': [
      ('🫐', 'Blueberries', 'Fights inflammation'),
      ('🐟', 'Salmon', 'Omega-3s calm breakouts'),
      ('🥦', 'Broccoli', 'Zinc for skin repair'),
      ('💧', 'Water', 'Flushes out toxins'),
      ('🍵', 'Green Tea', 'Helps regulate oil'),
      ('🎃', 'Pumpkin Seeds', 'Zinc & selenium'),
    ],
    'Excess oiliness': [
      ('🍵', 'Green Tea', 'Regulates sebum'),
      ('🥬', 'Leafy Greens', 'Vitamin A balances oil'),
      ('🍊', 'Citrus Fruits', 'Vitamin C for repair'),
      ('💧', 'Water', 'Balances oil production'),
      ('🌰', 'Almonds', 'Vitamin E'),
      ('🍠', 'Sweet Potato', 'Beta-carotene'),
    ],
    'Dryness / dehydration': [
      ('🥑', 'Avocado', 'Healthy fats lock in moisture'),
      ('🐟', 'Salmon', 'Omega-3 fats'),
      ('💧', 'Water', 'Core hydration'),
      ('🥒', 'Cucumber', 'High water content'),
      ('🥜', 'Walnuts', 'Omega-3 & biotin'),
      ('🍠', 'Sweet Potato', 'Vitamin A for skin barrier'),
    ],
    'Dark circles / eye bags': [
      ('🍊', 'Citrus Fruits', 'Vitamin C for collagen'),
      ('🥬', 'Spinach', 'Iron supports circulation'),
      ('💧', 'Water', 'Reduces puffiness'),
      ('🫐', 'Berries', 'Antioxidants'),
      ('🥚', 'Eggs', 'Vitamin K & protein'),
      ('🌰', 'Almonds', 'Vitamin E'),
    ],
    'Redness / rosacea': [
      ('🫐', 'Blueberries', 'Anti-inflammatory'),
      ('🐟', 'Salmon', 'Omega-3s calm redness'),
      ('🥒', 'Cucumber', 'Cooling & hydrating'),
      ('💧', 'Water', 'Reduces flare triggers'),
      ('🥬', 'Leafy Greens', 'Anti-inflammatory vitamins'),
      ('🍵', 'Chamomile Tea', 'Soothing properties'),
    ],
  };

  List<(String, String, String)> _nutritionFor(String? topLabel) {
    if (topLabel == null) return _defaultNutrition;
    return _nutritionPresets[topLabel] ?? _defaultNutrition;
  }

  @override
  void initState() {
    super.initState();
    InsightService.instance.load();
  }

  String _descriptionFor(String step) {
    final history = ScanStore.instance.results.value;
    final latest = history.isEmpty ? null : history.last;
    if (latest == null) {
      const fallback = {
        'detect': 'Take a Face Scan to see what your skin needs.',
        'analyze': 'Run a scan to see your hydration, oil balance and sensitivity breakdown.',
        'recommend': 'Recommendations are generated from your latest scan.',
        'routine': 'Your default routine is shown below. Scan to get one tailored to your skin.',
        'monitor': 'Scan regularly to track how your skin changes over time.',
      };
      return fallback[step]!;
    }
    switch (step) {
      case 'detect':
        return 'AI detected ${latest.topLabel.toLowerCase()} as your primary concern (${(latest.topScore * 100).round()}% confidence).';
      case 'analyze':
        return 'Skin health score: ${latest.healthScore}/100. Top concern: ${latest.topLabel}.';
      case 'recommend':
        return 'The routine below is tailored for ${latest.topLabel.toLowerCase()}. Re-scan anytime to refresh it.';
      case 'monitor':
        final n = history.length;
        return 'Tracking active — $n scan${n == 1 ? '' : 's'} logged. Scan regularly to watch trends over time.';
      default:
        return 'Your 5-step morning + night routine, tailored to your top concern.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([ScanStore.instance.results, RoutineStore.instance.done, RoutineStore.instance.label, RoutineStore.instance.customItems, InsightService.instance.insight, InsightService.instance.loading]),
        builder: (context, _) {
          final morning = RoutineStore.instance.morning;
          final night = RoutineStore.instance.night;
          final mDone = morning.where((s) => RoutineStore.instance.isDone('morning', s.name)).length;
          final nDone = night.where((s) => RoutineStore.instance.isDone('night', s.name)).length;
          final section = _section;
          final items = section == 'morning' ? morning : night;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Text('My Routine 🌿', style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textDark, letterSpacing: -0.6)),
              const SizedBox(height: 2),
              Text('AI-adapted based on your scans', style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              _workflowCard(),
              const SizedBox(height: 14),
              _updateBanner(),
              const SizedBox(height: 14),
              _insightCard(),
              const SizedBox(height: 14),
              _sectionToggle(mDone, morning.length, nDone, night.length),
              const SizedBox(height: 14),
              ...items.map((step) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _routineTile(section, step))),
              if (RoutineStore.instance.customItems.value.isNotEmpty) ...[
                const SizedBox(height: 14),
                _remindersSection(),
              ] else ...[
                const SizedBox(height: 14),
                _remindersSection(),
              ],
              const SizedBox(height: 8),
              Text('🥗 Skin Nutrition', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(
                ScanStore.instance.results.value.isEmpty
                    ? 'Scan once to personalise these picks'
                    : 'Tailored for ${ScanStore.instance.results.value.last.topLabel}',
                style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              _nutritionGrid(_nutritionFor(ScanStore.instance.results.value.isEmpty ? null : ScanStore.instance.results.value.last.topLabel)),
            ],
          );
        },
      ),
    );
  }

  Widget _workflowCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI WORKFLOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5A8C42), letterSpacing: 1)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_steps.length, (i) {
                final s = _steps[i];
                final info = _stepTitles[s]!;
                final isActive = s == _activeStep;
                final isPast = _steps.indexOf(_activeStep) > i;
                return Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _activeStep = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: isActive ? LinearGradient(colors: [AppColors.green, const Color(0xFF7FB069)]) : null,
                          color: isActive ? null : (isPast ? AppColors.green.withOpacity(0.25) : const Color(0xFFE8D7B8).withOpacity(0.4)),
                        ),
                        child: Text('${info.$1} ${info.$2}', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: isActive ? Colors.white : (isPast ? const Color(0xFF4A8030) : AppColors.rose),
                        )),
                      ),
                    ),
                    if (i < _steps.length - 1)
                      Container(width: 16, height: 1.5, color: isPast ? AppColors.green : const Color(0xFFE8D7B8)),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: AppColors.green, width: 3)),
            ),
            child: Text(_descriptionFor(_activeStep), style: TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w500, height: 1.55)),
          ),
        ],
      ),
    );
  }

  Widget _updateBanner() {
    final history = ScanStore.instance.results.value;
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withOpacity(0.3), width: 1.5),
        ),
        child: const Text('Take your first Face Scan to get a routine tailored to your skin.',
            style: TextStyle(fontSize: 12, color: Color(0xFF4A8030), fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.green.withOpacity(0.2), AppColors.green.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.green.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('🌱', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Routine Updated!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF2E6018))),
          ),
        ],
      ),
    );
  }

  Widget _insightCard() {
    final loading = InsightService.instance.loading.value;
    final insight = InsightService.instance.insight.value;
    final tip1 = InsightService.instance.tip1.value;
    final tip2 = InsightService.instance.tip2.value;

    if (ScanStore.instance.results.value.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.purple.withOpacity(0.10), AppColors.purple.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.purple.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔬', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('Your Personalized Insight', style: GoogleFonts.fraunces(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              if (loading) ...[
                const SizedBox(width: 8),
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.purple)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text('Based on your scans, diary, and today\'s weather', style: TextStyle(fontSize: 10.5, color: AppColors.rose, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text(
            insight ?? 'Log a diary entry or two to unlock a deeper, personalized insight here.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textDark, fontWeight: FontWeight.w500, height: 1.5),
          ),
          if (tip1.isNotEmpty || tip2.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (tip1.isNotEmpty) _insightTipRow(tip1),
            if (tip2.isNotEmpty) _insightTipRow(tip2),
          ],
        ],
      ),
    );
  }

  Widget _insightTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: AppColors.purple),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11.5, color: AppColors.textDark, fontWeight: FontWeight.w600, height: 1.4))),
        ],
      ),
    );
  }

  Widget _sectionToggle(int mDone, int mTotal, int nDone, int nTotal) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _sectionButton('morning', '☀️  Morning ($mDone/$mTotal)', const [Color(0xFFFDDCB5), Color(0xFFF5C888)], const Color(0xFF8A5820))),
          Expanded(child: _sectionButton('night', '🌙  Night ($nDone/$nTotal)', const [Color(0xFFD4B8E0), Color(0xFFB890C8)], const Color(0xFF5A3080))),
        ],
      ),
    );
  }

  Widget _sectionButton(String key, String label, List<Color> activeColors, Color activeText) {
    final active = _section == key;
    return GestureDetector(
      onTap: () => setState(() => _section = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: active ? LinearGradient(colors: activeColors) : null),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: active ? activeText : AppColors.rose)),
      ),
    );
  }

  Widget _routineTile(String section, RoutineStep step) {
    final done = RoutineStore.instance.isDone(section, step.name);
    return GestureDetector(
      onTap: () => RoutineStore.instance.toggle(section, step.name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: done ? AppColors.green.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: done ? AppColors.green.withOpacity(0.3) : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: done ? AppColors.green.withOpacity(0.2) : const Color(0xFFE8D7B8).withOpacity(0.3), borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text(step.icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.name, style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: done ? const Color(0xFFA0B090) : AppColors.textDark,
                    decoration: done ? TextDecoration.lineThrough : null,
                  )),
                  Text(step.note, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? LinearGradient(colors: [AppColors.green, const Color(0xFF7FB069)]) : null,
                color: done ? null : const Color(0xFFE8D7B8).withOpacity(0.5),
              ),
              alignment: Alignment.center,
              child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _remindersSection() {
    final items = RoutineStore.instance.customItems.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🔔 Your Reminders', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark, letterSpacing: -0.3)),
            GestureDetector(
              onTap: _showAddReminderDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('➕ Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.coralDeep)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Text('No custom reminders yet — tap Add to set one.', style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w500)),
          )
        else
          ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _reminderTile(item))),
      ],
    );
  }

  void _showAddReminderDialog() => _showReminderDialog();

  void _showEditReminderDialog(CustomRoutineItem item) => _showReminderDialog(existing: item);

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _repeatChip(String label, ReminderRepeat value, ReminderRepeat selected, ValueChanged<ReminderRepeat> onTap) {
    final sel = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: sel ? AppColors.coral : AppColors.coral.withOpacity(0.08)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.coralDeep)),
        ),
      ),
    );
  }

  void _showReminderDialog({CustomRoutineItem? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    TimeOfDay pickedTime = existing != null
        ? TimeOfDay(hour: existing.reminderHour, minute: existing.reminderMinute)
        : const TimeOfDay(hour: 20, minute: 0);
    ReminderRepeat selectedRepeat = existing?.repeat ?? ReminderRepeat.daily;
    int selectedWeekday = existing?.weekday ?? DateTime.now().weekday;
    DateTime selectedOnceDate = existing?.onceDate ?? DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? 'Add Reminder' : 'Edit Reminder', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What should the reminder say?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Apply night cream',
                    filled: true, fillColor: AppColors.coral.withOpacity(0.05),
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Repeat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _repeatChip('Daily', ReminderRepeat.daily, selectedRepeat, (r) => setDialogState(() => selectedRepeat = r)),
                    const SizedBox(width: 8),
                    _repeatChip('Weekly', ReminderRepeat.weekly, selectedRepeat, (r) => setDialogState(() => selectedRepeat = r)),
                    const SizedBox(width: 8),
                    _repeatChip('Specific Date', ReminderRepeat.once, selectedRepeat, (r) => setDialogState(() => selectedRepeat = r)),
                  ],
                ),
                const SizedBox(height: 14),
                if (selectedRepeat == ReminderRepeat.weekly) ...[
                  Text('Every', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: List.generate(7, (i) {
                      final wd = i + 1;
                      const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final sel = selectedWeekday == wd;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedWeekday = wd),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? AppColors.coral : AppColors.coral.withOpacity(0.08)),
                          alignment: Alignment.center,
                          child: Text(dayLabels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.coralDeep)),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                ],
                if (selectedRepeat == ReminderRepeat.once) ...[
                  Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedOnceDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (d != null) setDialogState(() => selectedOnceDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Text(_formatDate(selectedOnceDate), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.coralDeep)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text('Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: pickedTime);
                    if (t != null) setDialogState(() => pickedTime = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                    child: Text(pickedTime.format(context), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.coralDeep)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                if (existing == null) {
                  await RoutineStore.instance.addCustomItem(
                    name, pickedTime.hour, pickedTime.minute,
                    repeat: selectedRepeat,
                    weekday: selectedRepeat == ReminderRepeat.weekly ? selectedWeekday : null,
                    onceDate: selectedRepeat == ReminderRepeat.once ? selectedOnceDate : null,
                  );
                } else {
                  await RoutineStore.instance.editCustomItem(
                    existing.id, name: name, hour: pickedTime.hour, minute: pickedTime.minute,
                    repeat: selectedRepeat,
                    weekday: selectedRepeat == ReminderRepeat.weekly ? selectedWeekday : null,
                    onceDate: selectedRepeat == ReminderRepeat.once ? selectedOnceDate : null,
                  );
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderTile(CustomRoutineItem item) {
    final done = RoutineStore.instance.isDone('custom', item.id.toString());
    final timeLabel = TimeOfDay(hour: item.reminderHour, minute: item.reminderMinute).format(context);
    const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    String scheduleLabel;
    switch (item.repeat) {
      case ReminderRepeat.weekly:
        final name = (item.weekday != null && item.weekday! >= 1 && item.weekday! <= 7) ? weekdayNames[item.weekday! - 1] : 'week';
        scheduleLabel = 'Every $name at $timeLabel';
        break;
      case ReminderRepeat.once:
        if (item.onceDate != null) {
          final isPast = DateTime(item.onceDate!.year, item.onceDate!.month, item.onceDate!.day, item.reminderHour, item.reminderMinute).isBefore(DateTime.now());
          scheduleLabel = '${_formatDate(item.onceDate!)} at $timeLabel${isPast ? ' (past)' : ''}';
        } else {
          scheduleLabel = 'One-time at $timeLabel';
        }
        break;
      case ReminderRepeat.daily:
        scheduleLabel = 'Daily at $timeLabel';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: done ? AppColors.green.withOpacity(0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: done ? AppColors.green.withOpacity(0.3) : Colors.transparent, width: 1.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => RoutineStore.instance.toggle('custom', item.id.toString()),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? LinearGradient(colors: [AppColors.green, const Color(0xFF7FB069)]) : null,
                color: done ? null : const Color(0xFFE8D7B8).withOpacity(0.5),
              ),
              alignment: Alignment.center,
              child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showEditReminderDialog(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: done ? const Color(0xFFA0B090) : AppColors.textDark,
                    decoration: done ? TextDecoration.lineThrough : null,
                  )),
                  Text(scheduleLabel, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => RoutineStore.instance.removeCustomItem(item.id),
            child: Icon(Icons.close, size: 18, color: AppColors.rose),
          ),
        ],
      ),
    );
  }

  Widget _nutritionGrid(List<(String, String, String)> items) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: items.map((n) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(n.$1, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 5),
            Text(n.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(n.$3, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF5A8C42))),
          ],
        ),
      )).toList(),
    );
  }
}