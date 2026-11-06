import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/scan_store.dart';
import '../services/routine_store.dart';
import '../services/diary_store.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _view = 'landing'; // landing | login | signup

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _loginBusy = false;

  int _signupStep = 0;
  final _signupName = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPass = TextEditingController();
  bool _signupBusy = false;
  String? _skinType;
  final Set<String> _skinGoals = {};

  static const _skinTypes = [
    ('Oily', '💧', 'Shiny, enlarged pores'),
    ('Dry', '🌵', 'Tight, flaky patches'),
    ('Combination', '🌓', 'Oily T-zone, dry cheeks'),
    ('Normal', '🌿', 'Balanced, few concerns'),
    ('Sensitive', '🌸', 'Easily irritated'),
  ];

  static const _goalOptions = [
    ('acne', '🌸', 'Reduce Acne'),
    ('hydration', '💧', 'Improve Hydration'),
    ('brightening', '✨', 'Skin Brightening'),
    ('pores', '🌿', 'Minimize Pores'),
    ('anti-aging', '⭐', 'Anti-Ageing Care'),
  ];

  @override
  void dispose() {
    _loginEmail.dispose();
    _loginPass.dispose();
    _signupName.dispose();
    _signupEmail.dispose();
    _signupPass.dispose();
    super.dispose();
  }

  String _friendlyAuthError(FirebaseAuthException e, {required bool isSignup}) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts — please wait a moment and try again.';
      case 'network-request-failed':
        return "You're offline — check your connection and try again.";
      case 'email-already-in-use':
        return 'An account already exists for that email — try signing in instead.';
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      default:
        return (isSignup ? 'Sign-up failed: ' : 'Sign-in failed: ') + (e.message ?? e.code);
    }
  }

  Future<void> _login() async {
    final email = _loginEmail.text.trim();
    final password = _loginPass.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both email and password.')));
      return;
    }
    setState(() => _loginBusy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      // AuthGate's StreamBuilder picks up the signed-in state and navigates automatically.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyAuthError(e, isSignup: false)), backgroundColor: AppColors.coralDeep));
    } finally {
      if (mounted) setState(() => _loginBusy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _loginEmail.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email above first, then tap Forgot password?.')));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset email sent to $email.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'user-not-found' ? 'No account found for that email.' : 'Could not send reset email: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.coralDeep));
    }
  }

  Future<void> _completeSignup() async {
    final name = _signupName.text.trim();
    final email = _signupEmail.text.trim();
    final password = _signupPass.text;
    setState(() => _signupBusy = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(name);

      // Skin type/goals stay local for now — Phase 2 (Firestore) will make these cross-device too.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('skin_type', _skinType ?? '');
      await prefs.setString('skin_goals', _skinGoals.join(','));
      await ScanStore.instance.clear();
      await RoutineStore.instance.reset();
      await DiaryStore.instance.clear();
      // AuthGate's StreamBuilder picks up the signed-in state and navigates automatically.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyAuthError(e, isSignup: true)), backgroundColor: AppColors.coralDeep));
    } finally {
      if (mounted) setState(() => _signupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case 'login':
        return _loginView();
      case 'signup':
        return _signupView();
      default:
        return _landing();
    }
  }

  Widget _landing() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.coral, AppColors.coralDeep, const Color(0xFFC85A6A), const Color(0xFFF5C6CF)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🍓', style: TextStyle(fontSize: 70)),
                const SizedBox(height: 18),
                Text('AiSkin', style: GoogleFonts.fraunces(fontSize: 40, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -1)),
                const SizedBox(height: 8),
                const Text('Your AI-powered skin companion', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _view = 'signup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: AppColors.coralDeep,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _view = 'login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('I already have an account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginView() {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFFF5C6CF), const Color(0xFFFADADD), AppColors.cream], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(onTap: () => setState(() => _view = 'landing'), child: const Icon(Icons.arrow_back, size: 22)),
                  const SizedBox(height: 20),
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.coral, AppColors.coralDeep]), borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.center,
                    child: const Text('🍓', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(height: 18),
                  Text('Welcome Back', style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('Sign in to your AiSkin account', style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 28),
                  _inputField('Email', 'your@email.com', _loginEmail),
                  const SizedBox(height: 14),
                  _inputField('Password', '••••••••', _loginPass, obscure: true),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _sendPasswordReset, child: Text('Forgot password?', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loginBusy ? null : _login,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _loginBusy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: AppColors.rose, fontSize: 13)),
                      GestureDetector(
                        onTap: () => setState(() => _view = 'signup'),
                        child: Text('Sign Up', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signupView() {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.green, const Color(0xFFC5E0B0), AppColors.cream], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_signupStep == 0) {
                        setState(() => _view = 'landing');
                      } else {
                        setState(() => _signupStep = 0);
                      }
                    },
                    child: const Icon(Icons.arrow_back, size: 22),
                  ),
                  const SizedBox(height: 16),
                  Text(_signupStep == 0 ? 'Create Account' : 'Your Skin Profile', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text(_signupStep == 0 ? "Let's get you started" : 'Help us personalise your routine', style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 22),
                  if (_signupStep == 0) ..._signupStepOne() else ..._signupStepTwo(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _signupStepOne() {
    return [
      _inputField('Full Name', 'Your name', _signupName),
      const SizedBox(height: 14),
      _inputField('Email', 'your@email.com', _signupEmail),
      const SizedBox(height: 14),
      _inputField('Password', 'Create a password (6+ characters)', _signupPass, obscure: true),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This is a university FYP demo app — no formal Terms of Service exists yet.')),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'By signing up, you agree to our ',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFC0A0A0)),
                  children: [
                    TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (_signupName.text.trim().isEmpty || _signupEmail.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in your name and email.')));
              return;
            }
            if (_signupPass.text.length < 6) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.')));
              return;
            }
            setState(() => _signupStep = 1);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ),
    ];
  }

  List<Widget> _signupStepTwo() {
    return [
      Align(alignment: Alignment.centerLeft, child: Text("What's your skin type? 🌿", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark))),
      const SizedBox(height: 10),
      ..._skinTypes.map((t) {
        final (name, icon, desc) = t;
        final selected = _skinType == name;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => _skinType = name),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? AppColors.coral.withOpacity(0.12) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? AppColors.coral : Colors.transparent, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
                        Text(desc, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, color: AppColors.coral, size: 20),
                ],
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 18),
      Align(alignment: Alignment.centerLeft, child: Text('Primary skin goals (pick any) ✨', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark))),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _goalOptions.map((g) {
          final (key, icon, label) = g;
          final selected = _skinGoals.contains(key);
          return GestureDetector(
            onTap: () => setState(() => selected ? _skinGoals.remove(key) : _skinGoals.add(key)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: selected ? LinearGradient(colors: [AppColors.coral, AppColors.coralDeep]) : null,
                color: selected ? null : Colors.white,
              ),
              child: Text('$icon $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF8A7560))),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_skinType == null || _signupBusy) ? null : _completeSignup,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: _signupBusy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Start My Skin Journey 🌿', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Already have an account? ', style: TextStyle(fontSize: 12, color: AppColors.rose)),
          GestureDetector(
            onTap: () => setState(() => _view = 'login'),
            child: Text('Sign In', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ];
  }

  Widget _inputField(String label, String hint, TextEditingController ctrl, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.coral, width: 1.5)),
          ),
        ),
      ],
    );
  }
}