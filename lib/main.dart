import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/ui/screens/dashboard_screen.dart';
import 'package:flutter_fitness_app/ui/screens/logs_screen.dart';
import 'package:flutter_fitness_app/ui/screens/progress_screen.dart';
import 'package:flutter_fitness_app/ui/screens/goals_screen.dart';
import 'package:flutter_fitness_app/ui/screens/foods_screen.dart';
import 'package:flutter_fitness_app/router.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/vision_nav_bar.dart';
import 'package:flutter_fitness_app/ui/screens/settings_goals_screen.dart'; // added

void showSnack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );
}

/// Récupérées au build:
/// flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _sbUrl = String.fromEnvironment('SUPABASE_URL');
const _sbAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  if (_sbUrl.isEmpty || _sbAnon.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Missing SUPABASE_URL / SUPABASE_ANON_KEY')),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(
    url: _sbUrl,
    anonKey: _sbAnon,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  debugPrint('supabase_flutter: INFO: **** Supabase init completed ****');
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Fitness Macros',
    theme: AppTheme.light,
    navigatorKey: AppRouter.navigatorKey,
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  Session? _session;
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    if (_session != null) _appState = AppState();
    _sub = auth.onAuthStateChange.listen((event) {
      final s = event.session;
      if (s != null) {
        if (_appState == null) _appState = AppState();
      } else {
        _appState?.dispose();
        _appState = null;
      }
      setState(() => _session = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _appState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return const _SignInScreen();
    return ChangeNotifierProvider.value(
      value: _appState!,
      child: const BottomNavScaffold(),
    );
  }
}

/// ----- Ton scaffold/navigation existants -----
class BottomNavScaffold extends StatefulWidget {
  const BottomNavScaffold({super.key});
  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold>
    with WidgetsBindingObserver {
  int index = 0;
  late final PageController _pageController = PageController(
    initialPage: index,
  );
  final GlobalKey<FoodsScreenState> _foodsKey = GlobalKey<FoodsScreenState>();

  late final List<Widget> screens = [
    DashboardScreen(openFoodsTab: _openFoodsTab),
    const LogsScreen(),
    const ProgressScreen(),
    FoodsScreen(key: _foodsKey), // moved Foods to index 3
    const SettingsGoalsScreen(), // new combined settings + goals at index 4
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final appState = context.read<AppState>();
      appState.tickDayRollover();
    }
  }

  void _goTo(int i) {
    if (i == index) return;
    setState(() => index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openFoodsTab(int tabIndex) {
    if (index != 3) { // foods now at index 3
      setState(() => index = 3);
      _pageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foodsKey.currentState?.setTabIndex(tabIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => index = i),
            children: screens,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: VisionNavBar(currentIndex: index, onItemSelected: _goTo),
          ),
          Positioned(
            left: 8,
            bottom: MediaQuery.of(context).padding.bottom + 64,
            child: GestureDetector(
              onLongPress: () async {
                await Supabase.instance.client.auth.signOut();
              },
              child: const SizedBox(width: 1, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----- Écran de connexion minimal (email + mot de passe) -----
class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final email = _email.text.trim();
      final pass = _pass.text;
      if (email.isEmpty || pass.isEmpty) {
        showSnack(context, 'Enter email and password');
        return;
      }
      debugPrint('[AUTH] signInWithPassword $email');
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      if (!mounted) return;
      final user = res.user;
      if (user == null) {
        setState(() => _error = 'Incorrect email or password.');
        showSnack(context, 'No user returned (check email confirmation?)');
      } else {
        showSnack(context, 'Signed in as ${user.email}');
        // AuthGate listener will rebuild UI automatically
      }
    } on AuthException catch (e) {
      debugPrint('[AUTH][AuthException] ${e.statusCode} ${e.message}');
      setState(() => _error = e.message);
      showSnack(context, e.message);
    } catch (e, st) {
      debugPrint('[AUTH][Unknown] $e\n$st');
      setState(() => _error = 'Unexpected error: $e');
      showSnack(context, 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final email = _email.text.trim();
      final pass = _pass.text;
      if (email.isEmpty || pass.isEmpty) {
        showSnack(context, 'Enter email and password');
        return;
      }
      debugPrint('[AUTH] signUp $email');
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (!mounted) return;
      if (res.user != null) {
        if (res.user!.emailConfirmedAt == null) {
          showSnack(context, 'Check your inbox to confirm your email.');
        } else {
          showSnack(context, 'Account created — signed in!');
        }
      } else {
        showSnack(context, 'Sign-up returned no user');
      }
    } on AuthException catch (e) {
      debugPrint('[AUTH][AuthException] ${e.statusCode} ${e.message}');
      showSnack(context, e.message);
    } catch (e, st) {
      debugPrint('[AUTH][Unknown] $e\n$st');
      showSnack(context, 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24,
                  color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fitness Macros',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _busy ? null : _signIn,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _busy ? null : _signUp,
                        child: const Text('Create account'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Vos données (logs/poids/foods/goals) seront liées à votre compte.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
