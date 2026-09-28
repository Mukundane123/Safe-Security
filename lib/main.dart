import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'repositories/demo_repository.dart';
import 'repositories/firebase_repository.dart';
import 'repositories/repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'state/auth_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';

/// Best-effort App Check. Only enforced in release builds: a debug build has
/// no registered App Check provider, and enforcing it there would block every
/// Firebase call. Register a Play Integrity provider (or a debug token in the
/// Firebase console) before shipping.
Future<void> _activateAppCheck() async {
  if (!kReleaseMode) return;
  try {
    await FirebaseAppCheck.instance.activate();
  } catch (e) {
    debugPrint('App Check activation failed: $e');
  }
}

/// Bounded attempt to connect Firebase. Anything non-terminating (no config,
/// no network, broken platform channels) must never block app boot, so every
/// step has a timeout and a demo fallback.
Future<IRepository> _createRepository() async {
  if (AppConfig.forceDemoMode) return DemoRepository();
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    final app = Firebase.app();
    final projectId = app.options.projectId;
    if (projectId.isEmpty) {
      // A default app exists but no google-services.json / FirebaseOptions were
      // wired up — treat as demo so the app still opens instantly.
      return DemoRepository();
    }
    unawaited(_activateAppCheck());
    return FirebaseRepository(app: app);
  } catch (e) {
    // No Firebase project configured (no google-services.json / offline), or
    // init failed. Fall back to the fully-featured in-memory demo.
    debugPrint('Firebase init failed, using demo repository: $e');
    return DemoRepository();
  }
}

Future<void> _initNotifications(IRepository repo) async {
  if (repo.isDemo) return;
  try {
    final notifications = NotificationService();
    await notifications.init(repo).timeout(const Duration(seconds: 15));
  } catch (e) {
    // Push is best-effort and must never block or crash the app.
    debugPrint('Push notification setup failed: $e');
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeGuardBootstrap());
}

/// Shows a branded splash immediately, then swaps in the real app once the
/// repository is ready — so the device never sits on a frozen launch screen.
class SafeGuardBootstrap extends StatefulWidget {
  const SafeGuardBootstrap({super.key});

  @override
  State<SafeGuardBootstrap> createState() => _SafeGuardBootstrapState();
}

class _SafeGuardBootstrapState extends State<SafeGuardBootstrap> {
  IRepository? _repo;
  SettingsController? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await SettingsController.load();
    final repo = await _createRepository();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _repo = repo;
    });
    if (!repo.isDemo) {
      // Fire-and-forget so the first frame is never delayed by FCM setup.
      unawaited(_initNotifications(repo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    if (repo == null) {
      return MaterialApp(
        title: 'SafeGuard',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildDarkAppTheme(),
        home: const _Splash(),
      );
    }
    return SafeGuardApp(repo: repo, settings: _settings!);
  }
}

class SafeGuardApp extends StatelessWidget {
  final IRepository repo;
  final SettingsController settings;
  const SafeGuardApp({super.key, required this.repo, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<IRepository>.value(value: repo),
        ChangeNotifierProvider(
          create: (_) => AuthController(repo),
        ),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: SettingsConsumer(),
    );
  }
}

class SettingsConsumer extends StatelessWidget {
  const SettingsConsumer({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'SafeGuard',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: settings.themeMode,
      home: const RootGate(),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    if (user == null) return const LoginScreen();
    return HomeShell(user: user);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.shield, size: 64, color: Color(0xFFB3261E)),
            SizedBox(height: 16),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading SafeGuard...'),
          ],
        ),
      ),
    );
  }
}