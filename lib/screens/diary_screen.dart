import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/diary_store.dart';
import '../services/scan_store.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  String _tab = 'log';
  DateTime _month = DateTime.now();
  bool _showForm = false;

  String? _condition;
  String _mood = '🙂';
  double _sleep = 7;
  double _water = 6;
  double _stress = 3;
  final _productsCtrl = TextEditingController();
  final _dietCtrl = TextEditingController();

  static const _conditions = ['Clear', 'Mild Breakout', 'Oily', 'Dry', 'Irritated'];
  static const _moods = ['😞', '😐', '🙂', '😄', '🤩'];
  static const _concernLabels = [
    'Acne breakout',
    'Excess oiliness',
    'Dryness / dehydration',
    'Dark circles / eye bags',
    'Redness / rosacea',
  ];

  @override
  void dispose() {
    _productsCtrl.dispose();
    _dietCtrl.dispose();
    super.dispose();
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  ScanResult? _scanForDay(DateTime d) {
    final key = _key(d);
    final matches = ScanStore.instance.results.value.where((r) => _key(r.date) == key).toList();
    return matches.isEmpty ? null : matches.last;
  }

  void _showDayDetail(DateTime date) {
    final entry = DiaryStore.instance.entries.value[_key(date)];
    final scan = _scanForDay(date);
    if (entry == null && scan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No entry logged this day.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_dateLabel(date), style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 14),
              if (scan != null) ...[
                if (scan.photoPath != null && File(scan.photoPath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(File(scan.photoPath!), width: double.infinity, height: 220, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: double.infinity, height: 100,
                    decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.center,
                    child: Text('No photo saved for this scan', style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w500)),
                  ),
                const SizedBox(height: 10),
                Text('Scan — ${scan.topLabel} · ${scan.healthScore}/100',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.coralDeep)),
                const SizedBox(height: 14),
              ],
              if (entry?.condition != null) _detailRow('Condition', entry!.condition!),
              if (entry?.mood != null) _detailRow('Mood', entry!.mood!),
              if (entry?.sleep != null) _detailRow('Sleep', '${entry!.sleep!.round()} hrs'),
              if (entry?.water != null) _detailRow('Water', '${entry!.water!.round()} glasses'),
              if (entry?.stress != null) _detailRow('Stress', '${entry!.stress!.round()}/10'),
              if (entry?.products != null && entry!.products!.isNotEmpty) _detailRow('Products', entry.products!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _saveEntry() async {
    if (_condition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a skin condition first.')));
      return;
    }
    await DiaryStore.instance.saveManualEntry(
      DateTime.now(),
      condition: _condition!,
      mood: _mood,
      sleep: _sleep,
      water: _water,
      stress: _stress,
      products: _productsCtrl.text.trim(),
      diet: _dietCtrl.text.trim().isEmpty ? null : _dietCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _showForm = false;
      _condition = null;
      _mood = '🙂';
      _sleep = 7;
      _water = 6;
      _stress = 3;
      _productsCtrl.clear();
      _dietCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry saved 🌿')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([DiaryStore.instance.entries, ScanStore.instance.results]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Text('My Skin Diary 📔', style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textDark, letterSpacing: -0.6)),
              const SizedBox(height: 2),
              Text('Track your daily skin journey', style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              _tabs(),
              const SizedBox(height: 14),
              if (_tab == 'log') ..._logTab() else ..._progressTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _tabButton('log', '📅  Calendar Log')),
          Expanded(child: _tabButton('progress', '📈  Progress')),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label) {
    final active = _tab == key;
    return GestureDetector(
      onTap: () => setState(() => _tab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: active ? LinearGradient(colors: [const Color(0xFFD4B8E0), AppColors.purple]) : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: active ? AppColors.surface : AppColors.rose)),
      ),
    );
  }

  List<Widget> _logTab() {
    return [
      _calendarCard(),
      const SizedBox(height: 14),
      _addEntryButton(),
      if (_showForm) ...[
        const SizedBox(height: 14),
        _entryForm(),
      ],
      const SizedBox(height: 14),
      _recentEntries(),
    ];
  }

  Widget _calendarCard() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final entries = DiaryStore.instance.entries.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Text(_monthLabel(_month), style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              IconButton(
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(
              child: Center(child: Text(d, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.rose))),
            )).toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemBuilder: (context, i) {
              if (i < startWeekday) return const SizedBox();
              final day = i - startWeekday + 1;
              final date = DateTime(_month.year, _month.month, day);
              final entry = entries[_key(date)];
              final isToday = _key(date) == _key(DateTime.now());
              final selected = false;
              Color? dotColor;
              if (entry != null) {
                final isGood = entry.mood == '🙂' || entry.mood == '😄' || entry.mood == '🤩' || entry.condition == 'Clear';
                dotColor = isGood ? AppColors.green : const Color(0xFFF5A0A8);
              }
              return GestureDetector(
                onTap: () => _showDayDetail(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? LinearGradient(colors: [const Color(0xFFD4B8E0), AppColors.purple]) : null,
                    border: isToday ? Border.all(color: AppColors.purple, width: 1.5) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      if (dotColor != null) Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${names[d.month - 1]} ${d.year}';
  }

  Widget _addEntryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => setState(() => _showForm = !_showForm),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple, foregroundColor: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(_showForm ? 'Cancel' : '✍️  Log Today\'s Entry', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    );
  }

  Widget _entryForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skin Condition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _conditions.map((c) {
              final sel = _condition == c;
              return GestureDetector(
                onTap: () => setState(() => _condition = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: sel ? LinearGradient(colors: [const Color(0xFFF5C6CF), AppColors.coral]) : null,
                    color: sel ? null : const Color(0xFFE8D7B8).withOpacity(0.3),
                  ),
                  child: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? AppColors.surface : const Color(0xFF8A7560))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Mood', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _moods.map((emoji) {
              final sel = _mood == emoji;
              return GestureDetector(
                onTap: () => setState(() => _mood = emoji),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? AppColors.purple.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(color: sel ? AppColors.purple : Colors.transparent, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _sliderRow('😴 Sleep', _sleep, 0, 12, 'hrs', (v) => setState(() => _sleep = v)),
          _sliderRow('💧 Water', _water, 0, 12, 'glasses', (v) => setState(() => _water = v)),
          _sliderRow('😰 Stress', _stress, 0, 10, '/10', (v) => setState(() => _stress = v)),
          const SizedBox(height: 10),
          Text('Products Used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextField(
            controller: _productsCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Cleanser, Vitamin C serum, SPF 50',
              filled: true, fillColor: const Color(0xFFE8D7B8).withOpacity(0.15),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Text('Food & Drink Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 8),
          TextField(
            controller: _dietCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Dairy, fried food, lots of sugar — optional',
              filled: true, fillColor: const Color(0xFFE8D7B8).withOpacity(0.15),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveEntry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.surface, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, String unit, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              Text('${value.round()} $unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A7560))),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 4, activeTrackColor: AppColors.purple, thumbColor: AppColors.purple, inactiveTrackColor: const Color(0xFFE8D7B8)),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _recentEntries() {
    final entries = DiaryStore.instance.recentSorted;
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Center(
          child: Text('No entries yet — log your first day above!',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w500)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Entries', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 10),
        ...entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Text(e.mood ?? '📝', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateLabel(e.date), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textDark)),
                    if (e.condition != null) Text(e.condition!, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
                    if (e.hasScan) Text('Scan: ${e.scanTopConcern} · ${e.scanHealthScore}/100', style: TextStyle(fontSize: 11, color: AppColors.coralDeep, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${names[d.month - 1]} ${d.day}';
  }

  List<Widget> _progressTab() {
    final history = ScanStore.instance.results.value;
    if (history.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Center(
            child: Column(
              children: [
                const Text('📸', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text('Run a few scans to see your before/after progress here.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.5)),
              ],
            ),
          ),
        ),
      ];
    }

    final first = history.first;
    final last = history.last;
    final days = last.date.difference(first.date).inDays;

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Before & After', style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('${history.length} scans over $days day${days == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _beforeAfterCard('First Scan', first, const Color(0xFFF5A0A8))),
                const SizedBox(width: 10),
                Expanded(child: _beforeAfterCard('Latest Scan', last, AppColors.green)),
              ],
            ),
         ],
        ),
      ),
      if (history.length >= 2) ...[
        const SizedBox(height: 12),
        _progressReasoningCard(first, last),
      ],
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metric Changes', style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),            const SizedBox(height: 12),
            ..._concernLabels.map((label) {
              final before = ((first.scores[label] ?? 0) * 100).round();
              final after = ((last.scores[label] ?? 0) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                    Expanded(
                      child: Row(
                        children: [
                          Text('$before%', style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, size: 12, color: Color(0xFFC0A0A0)),
                          const SizedBox(width: 6),
                          Text('$after%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: after <= before ? const Color(0xFF4A8030) : const Color(0xFFC05870))),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }

  Widget _beforeAfterCard(String label, ScanResult r, Color accent) {
    final hasPhoto = r.photoPath != null && File(r.photoPath!).existsSync();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: accent.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPhoto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(r.photoPath!), width: double.infinity, height: 110, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
          ],
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8A7560))),
          const SizedBox(height: 4),
          Text('${r.healthScore}', style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.bold, color: accent)),
          const Text('skin score', style: TextStyle(fontSize: 10, color: Color(0xFF8A7560))),
          const SizedBox(height: 6),
          Text(r.topLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5A4030))),
        ],
      ),
    );
  }

  Widget _progressReasoningCard(ScanResult first, ScanResult last) {
    final improved = <String>[];
    final needsFocus = <String>[];
    final stable = <String>[];
    for (final label in _concernLabels) {
      final before = first.scores[label] ?? 0;
      final after = last.scores[label] ?? 0;
      final delta = after - before;
      if (delta <= -0.03) {
        improved.add(label);
      } else if (delta >= 0.03 || after >= 0.4) {
        needsFocus.add(label);
      } else {
        stable.add(label);
      }
    }

    Widget section(String title, List<String> items, Color color, IconData icon) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((label) {
              final reason = last.concernReasons[label] ?? '';
              final before = ((first.scores[label] ?? 0) * 100).round();
              final after = ((last.scores[label] ?? 0) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$label  ($before% → $after%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    if (reason.isNotEmpty)
                      Text(reason, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.4)),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What Changed', style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text('Based on the reasoning from your first and latest scan.', style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          section('Improved', improved, const Color(0xFF4A8030), Icons.trending_up),
          section('Needs Focus', needsFocus, const Color(0xFFC05870), Icons.priority_high),
          section('Stable', stable, AppColors.purple, Icons.remove),
        ],
      ),
    );
  }}