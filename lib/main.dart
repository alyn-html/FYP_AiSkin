import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/scan_store.dart';
import 'services/routine_store.dart';
import 'services/diary_store.dart';
import 'services/notification_service.dart';
import 'services/theme_store.dart';
import 'services/privacy_service.dart';
import 'services/weather_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/routine_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/profile_screen.dart';
import 'services/diary_store.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();
  await RoutineStore.instance.resyncNotifications();
  await ThemeStore.instance.load();
  await PrivacyService.instance.load();
  await WeatherService.instance.load();
  await ScanStore.instance.load();
  await RoutineStore.instance.load();
  await DiaryStore.instance.load();

  runApp(const AiSkinApp());
}


class AiSkinApp extends StatelessWidget {
  const AiSkinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeStore.instance.isDark,
      builder: (context, _, __) {
        return MaterialApp(
          title: 'AiSkin',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return RootNav();
        return const AuthScreen();
      },
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return RootNav();
        return const AuthScreen();
      },
    );
  }

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _indexValue = 0;
  int get _index => _indexValue;
  set _index(int v) {
    _indexValue = v;
    PrivacyService.instance.syncSecureFlag(onDiaryTab: v == 3);
  }
  String _scanTarget = 'scan';
  int _scanNav = 0;
  String _profileTarget = 'profile';
  int _profileNav = 0;

  void _goTo(int i) => setState(() => _index = i);

  void _goToScan(String tab) {
    setState(() {
      _scanTarget = tab;
      _scanNav++;
      _index = 1;
    });
  }

  void _goToProfile(String section) {
    setState(() {
      _profileTarget = section;
      _profileNav++;
      _index = 4;
    });
  }
  List<Widget> get _screens => [
    HomeScreen(
      onFaceScanTap: () => _goToScan('scan'),
      onSkinChatTap: () => _goToScan('chat'),
      onRoutineTap: () => _goTo(2),
      onFindDermTap: () => _goToProfile('derm'),
    ),
    ScanScreen(onViewRoutine: () => _goTo(2), initialTab: _scanTarget, navRequestId: _scanNav),
    RoutineScreen(),
    DiaryScreen(),
    ProfileScreen(initialSection: _profileTarget, navRequestId: _profileNav),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.cream,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.spa_outlined), selectedIcon: Icon(Icons.spa), label: 'Routine'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Diary'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}