import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/theme_store.dart';
import '../services/scan_store.dart';
import '../services/diary_store.dart';
import '../services/privacy_service.dart';

class ProfileScreen extends StatefulWidget {
  final String initialSection;
  final int navRequestId;
  const ProfileScreen({super.key, this.initialSection = 'profile', this.navRequestId = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _section = widget.initialSection;
  String _name = 'Your Name';
  String _email = '';
  String _skinType = 'Not set';

  final _toggles = {'notif': true, 'priv': false, 'loc': true, 'dark': false};
  Map<String, bool> _goals = {'acne': false, 'hydration': false, 'brightening': false, 'pores': false, 'anti-aging': false};

  static const _settings = [
    ('🔔', 'Push Notifications', 'Routine reminders & tips', 'notif'),
    ('🔒', 'Privacy Mode', 'Hide diary from screenshots', 'priv'),
    ('📍', 'Location Services', 'For dermatologist search', 'loc'),
    ('🌙', 'Dark Mode', 'Easy on the eyes at night', 'dark'),
  ];

  static const _allGoals = [
    ('acne', '🌸', 'Reduce Acne'),
    ('hydration', '💧', 'Improve Hydration'),
    ('brightening', '✨', 'Skin Brightening'),
    ('pores', '🌿', 'Minimize Pores'),
    ('anti-aging', '⭐', 'Anti-Ageing Care'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navRequestId != oldWidget.navRequestId) {
      setState(() => _section = widget.initialSection);
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final storedType = prefs.getString('skin_type');
    final storedGoals = prefs.getString('skin_goals');
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      _name = (user?.displayName != null && user!.displayName!.isNotEmpty) ? user.displayName! : 'Your Name';
      _email = user?.email ?? '';
      _skinType = (storedType != null && storedType.isNotEmpty) ? storedType : 'Not set';
      if (storedGoals != null && storedGoals.isNotEmpty) {
        final active = storedGoals.split(',').toSet();
        _goals = {for (final k in _goals.keys) k: active.contains(k)};
      }
    });
  }

  Future<void> _toggleGoal(String key) async {
    final updated = !(_goals[key] ?? false);
    setState(() => _goals[key] = updated);
    final prefs = await SharedPreferences.getInstance();
    final active = _goals.entries.where((e) => e.value).map((e) => e.key).join(',');
    await prefs.setString('skin_goals', active);
  }

  Future<void> _openMapsSearch() async {
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': 'dermatologist near me'});
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open Maps — is it installed?")));
    }
  }

  int _computeStreak(Map<String, DiaryEntry> entries) {
    int streak = 0;
    DateTime cursor = DateTime.now();
    if (!entries.containsKey(DiaryStore.instance.keyFor(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (entries.containsKey(DiaryStore.instance.keyFor(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text('You can sign back in anytime with the same email and password.', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirm == true) await FirebaseAuth.instance.signOut();
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent to $email.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send reset email: ${e.message ?? e.code}'), backgroundColor: AppColors.coralDeep));
    }
  }

  void _showDeleteAccountDialog() {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This permanently deletes your account and sign-in — this cannot be undone. Enter your password to confirm.', style: TextStyle(fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                filled: true, fillColor: AppColors.coral.withOpacity(0.05),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final password = passwordCtrl.text;
              if (password.isEmpty) return;
              Navigator.pop(dialogContext);
              await _deleteAccount(password);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B), foregroundColor: Colors.white),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      await ScanStore.instance.clear();
      await DiaryStore.instance.clear();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential') ? 'Incorrect password — account not deleted.' : 'Could not delete account: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.coralDeep));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([ScanStore.instance.results, DiaryStore.instance.entries]),
        builder: (context, _) {
          final scans = ScanStore.instance.results.value;
          final latest = ScanStore.instance.latest;
          final streak = _computeStreak(DiaryStore.instance.entries.value);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _avatarHero(scanCount: scans.length, skinScore: latest?.healthScore, streak: streak),
              const SizedBox(height: 16),
              _sectionTabs(),
              const SizedBox(height: 16),
              if (_section == 'profile') ..._profileSection(latestConcern: latest?.topLabel) else ..._dermSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _avatarHero({required int scanCount, required int? skinScore, required int streak}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x66E8D7B8)))),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.coral, const Color(0xFFE06878)]), borderRadius: BorderRadius.circular(26)),
                alignment: Alignment.center,
                child: const Text('🍓', style: TextStyle(fontSize: 38)),
              ),
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cream, width: 2)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_name, style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textDark, letterSpacing: -0.4)),
          const SizedBox(height: 3),
          Text(_email.isNotEmpty ? _email : 'Complete your profile', style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.10), borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statBlock('$streak', 'Day Streak'),
                _statDivider(),
                _statBlock(skinScore != null ? '$skinScore' : '--', 'Skin Score'),
                _statDivider(),
                _statBlock('$scanCount', 'Scans'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 16), color: AppColors.coral.withOpacity(0.25));

  Widget _statBlock(String val, String label) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.coral, height: 1)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.rose, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _sectionTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _tabButton('profile', '👤  Profile & Settings')),
          Expanded(child: _tabButton('derm', '🏥  Find Dermatologist')),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label) {
    final active = _section == key;
    return GestureDetector(
      onTap: () => setState(() => _section = key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: active ? LinearGradient(colors: [AppColors.coral, AppColors.coralDeep]) : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: active ? Colors.white : AppColors.rose)),
      ),
    );
  }

  List<Widget> _profileSection({String? latestConcern}) {
    return [
      _card(
        title: 'Skin Profile',
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8, crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            _skinProfileTile('🌿', 'Skin Type', _skinType),
            _skinProfileTile('🌸', 'Sensitivity', 'Moderate'),
            _skinProfileTile('💧', 'Concern', latestConcern ?? 'Not set'),
            _skinProfileTile('✨', 'Skin Tone', 'Light-Medium'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _card(
        title: 'Skin Goals',
        child: Column(
          children: _allGoals.map((g) {
            final (key, icon, label) = g;
            final selected = _goals[key] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _toggleGoal(key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.coral.withOpacity(0.12) : const Color(0xFFE8D7B8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AppColors.coral.withOpacity(0.3) : Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark))),
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          gradient: selected ? LinearGradient(colors: [AppColors.coral, AppColors.coralDeep]) : null,
                          color: selected ? null : const Color(0xFFE8D7B8).withOpacity(0.5),
                        ),
                        alignment: Alignment.center,
                        child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 12),
      _card(
        title: 'Settings',
        child: Column(
          children: _settings.asMap().entries.map((e) {
            final (icon, label, sub, key) = e.value;
            final isLast = e.key == _settings.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0x66E8D7B8), width: 0.5))),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text(icon, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                        Text(sub, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Switch(
                    value: key == 'dark'
                        ? ThemeStore.instance.isDark.value
                        : key == 'priv'
                            ? PrivacyService.instance.enabled.value
                            : (_toggles[key] ?? false),
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.coral,
                    onChanged: (v) {
                      if (key == 'dark') {
                        ThemeStore.instance.toggle(v);
                        setState(() {});
                      } else if (key == 'priv') {
                        PrivacyService.instance.toggle(v);
                        setState(() {});
                      } else {
                        setState(() => _toggles[key] = v);
                      }
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 12),
      _card(
        title: 'Account',
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_reset, color: AppColors.coral),
              title: Text('Reset Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              subtitle: const Text('Email a password reset link', style: TextStyle(fontSize: 11)),
              onTap: _sendPasswordReset,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout, color: AppColors.coral),
              title: Text('Log Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              onTap: _logout,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_forever, color: Color(0xFFC0392B)),
              title: const Text('Delete Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFC0392B))),
              subtitle: const Text('Permanently erase your account', style: TextStyle(fontSize: 11)),
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.coral.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.coral.withOpacity(0.3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚕️ Health Disclaimer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFC05870))),
            SizedBox(height: 4),
            Text(
              'AiSkin provides educational skincare recommendations only and does not diagnose, treat, or cure any condition. Always consult a licensed dermatologist or healthcare professional for medical concerns.',
              style: TextStyle(fontSize: 11, color: Color(0xFFC0A0A0), fontWeight: FontWeight.w500, height: 1.55),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _skinProfileTile(String icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.coral.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coral.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.rose, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  List<Widget> _dermSection() {
    return [
      Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [const Color(0xFFC5E0B0), AppColors.green, const Color(0xFFD0E8C0)])),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(top: 40, left: 60, child: Text('🏥', style: TextStyle(fontSize: 22))),
            const Positioned(bottom: 50, right: 50, child: Text('🏥', style: TextStyle(fontSize: 16))),
            const Positioned(bottom: 30, left: 40, child: Text('🏥', style: TextStyle(fontSize: 16))),
            Positioned(
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(999)),
                child: Text('📍 Find a dermatologist near you', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _openMapsSearch,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.coral, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('📍  Find Nearby Dermatologists', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.rose.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
        child: Text(
          'This opens Google Maps with a live search for dermatologists near your current location — real results, not a preset list.',
          style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w600, height: 1.4),
        ),
      ),
    ];
  }
}