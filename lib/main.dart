import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/leagues_screen.dart';
import 'screens/login_screen.dart';
import 'screens/more_screen.dart';
import 'screens/my_team_screen.dart';
import 'screens/transfers_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.loadTheme();
  runApp(const FplStationApp());
}

class FplStationApp extends StatefulWidget {
  const FplStationApp({super.key});

  @override
  State<FplStationApp> createState() => _FplStationAppState();
}

class _FplStationAppState extends State<FplStationApp> {
  bool _checkingSession = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    final session = await AuthService.tryAutoLogin();
    if (!mounted) return;
    setState(() {
      _loggedIn = session != null;
      _checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Station Football FPL 26/27',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: _checkingSession
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : _loggedIn
                  ? MainNavigationShell(
                      onLogout: () => setState(() => _loggedIn = false),
                    )
                  : LoginScreen(
                      onLoginSuccess: () => setState(() => _loggedIn = true),
                    ),
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final VoidCallback onLogout;

  const MainNavigationShell({super.key, required this.onLogout});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  int _myTeamSubTab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onNavigateToMyTeam: () {
          setState(() {
            _myTeamSubTab = 0;
            _currentIndex = 1;
          });
        },
        onNavigateToPoints: () {
          setState(() {
            _myTeamSubTab = 1;
            _currentIndex = 1;
          });
        },
      ),
      MyTeamScreen(
        key: ValueKey('my_team_$_myTeamSubTab'),
        initialSubTab: _myTeamSubTab,
      ),
      const TransfersScreen(),
      const LeaguesScreen(),
      MoreScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer_outlined),
            activeIcon: Icon(Icons.sports_soccer),
            label: 'My Team',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Transfers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Leagues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            activeIcon: Icon(Icons.menu_open),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
