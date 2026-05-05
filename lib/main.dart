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
import 'package:flutter_fitness_app/ui/screens/foods_screen.dart';
import 'package:flutter_fitness_app/router.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/screens/settings_goals_screen.dart';
import 'package:flutter_fitness_app/ui/daily_checkin_sheet.dart';
import 'package:flutter_fitness_app/ui/workout/workout_scaffold.dart';
import 'package:flutter_fitness_app/ui/widgets/vision_nav_bar.dart';

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
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _checkinShown = false;

  @override
  void initState() {
    super.initState();
    // Listen for AppState load completion, then show checkin if needed.
    // We can't do this in initState directly because AppState.load() is async
    // and _lastCheckInKey is null until it finishes — causing a false needsCheckIn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.isLoaded) {
        _maybeShowCheckin();
      } else {
        appState.addListener(_onAppStateLoaded);
      }
    });
  }

  void _onAppStateLoaded() {
    final appState = context.read<AppState>();
    if (appState.isLoaded) {
      appState.removeListener(_onAppStateLoaded);
      _maybeShowCheckin();
    }
  }

  @override
  void dispose() {
    // Safety: remove listener if widget is disposed before load completes
    try {
      context.read<AppState>().removeListener(_onAppStateLoaded);
    } catch (_) {}
    super.dispose();
  }

  void _maybeShowCheckin() {
    if (_checkinShown) return;
    final appState = context.read<AppState>();
    if (appState.needsCheckIn) {
      _checkinShown = true;
      showDailyCheckin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, appState, __) {
        if (appState.isWorkoutMode) {
          return const WorkoutScaffold();
        }
        return const BottomNavScaffold();
      },
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
    final pad = MediaQuery.viewPaddingOf(context).bottom;
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
          // Workout gate button — positioned above the nav bar on the right
          Positioned(
            bottom: VisionNavBar.kHeight + (pad > 0 ? pad : 8) + 12,
            right: 20,
            child: _WorkoutGateButton(),
          ),
        ],
      ),
    );
  }
}

class _WorkoutGateButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        appState.enterWorkoutMode();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 17),
            const SizedBox(width: 7),
            const Text(
              'WORKOUT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
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

/// Returns the appropriate default [Meal] for the current time of day.
Meal timeAwareMeal() {
  final h = TimeOfDay.now().hour;
  if (h < 10) return Meal.breakfast;
  if (h < 14) return Meal.lunch;
  if (h < 19) return Meal.dinner;
  return Meal.snack;
}

class _SignInScreenState extends State<_SignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _showPass = false;
  bool _awaitingConfirmation = false; // after sign-up, waiting for email confirm
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
          // Email confirmation required
          setState(() => _awaitingConfirmation = true);
        } else {
          showSnack(context, 'Account created — signed in!');
        }
      } else {
        showSnack(context, 'Sign-up returned no user');
      }
    } on AuthException catch (e) {
      debugPrint('[AUTH][AuthException] ${e.statusCode} ${e.message}');
      setState(() => _error = e.message);
    } catch (e, st) {
      debugPrint('[AUTH][Unknown] $e\n$st');
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ── Email confirmation waiting screen ─────────────────────────────────
    if (_awaitingConfirmation) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_read_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Check your inbox',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a confirmation link to:\n${_email.text.trim()}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Open the link on this device, then come back and sign in.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () =>
                      setState(() => _awaitingConfirmation = false),
                  child: const Text('Back to Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo / Brand
                const SizedBox(height: 12),
                Icon(
                  Icons.fitness_center_rounded,
                  size: 52,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Fitness Macros',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Track your nutrition, reach your goals.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // ── Email
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Password
                StatefulBuilder(
                  builder: (_, setS) => TextField(
                    controller: _pass,
                    obscureText: !_showPass,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _showPass ? 'Hide password' : 'Show password',
                        icon: Icon(
                          _showPass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                    ),
                  ),
                ),

                // ── Error
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Sign in
                ElevatedButton(
                  onPressed: _busy ? null : _signIn,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 10),

                // ── Create account
                OutlinedButton(
                  onPressed: _busy ? null : _signUp,
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 16),

                Text(
                  'Your data is linked to your account and synced securely.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black38,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
