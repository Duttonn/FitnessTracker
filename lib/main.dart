import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ⬅️ NEW

import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/ui/screens/dashboard_screen.dart';
import 'package:flutter_fitness_app/ui/screens/logs_screen.dart';
import 'package:flutter_fitness_app/ui/screens/progress_screen.dart';
import 'package:flutter_fitness_app/ui/screens/goals_screen.dart';
import 'package:flutter_fitness_app/ui/screens/foods_screen.dart';
import 'package:flutter_fitness_app/router.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/vision_nav_bar.dart';

// Read from --dart-define at build/run time
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _supabaseAnon = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge status bar style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );

  // Initialize Supabase (if keys are provided)
  if (_supabaseUrl.isNotEmpty && _supabaseAnon.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnon,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        // persistSession removed (always enabled by default in >=2.10.0)
      ),
    );
  } else {
    // Not fatal: the app can still run locally/offline without Supabase.
    // (You’ll pass keys via --dart-define; see your build/run command.)
    debugPrint(
      '[Supabase] Missing SUPABASE_URL / SUPABASE_ANON_KEY dart-defines. '
      'Running without remote backend.',
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(), // self-initializes (init + load + timer)
      child: const FitnessApp(),
    ),
  );
}

class FitnessApp extends StatefulWidget {
  const FitnessApp({super.key});
  @override
  State<FitnessApp> createState() => _FitnessAppState();
}

class _FitnessAppState extends State<FitnessApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final appState = context.read<AppState>();
      appState.tickDayRollover();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness Macros',
      theme: AppTheme.light,
      navigatorKey: AppRouter.navigatorKey,
      home: const BottomNavScaffold(),
    );
  }
}

class BottomNavScaffold extends StatefulWidget {
  const BottomNavScaffold({super.key});
  @override
  State<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends State<BottomNavScaffold> {
  int index = 0;
  late final PageController _pageController = PageController(
    initialPage: index,
  );
  final GlobalKey<FoodsScreenState> _foodsKey = GlobalKey<FoodsScreenState>();

  void _goTo(int i) {
    if (i == index) return;
    setState(() => index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  late final List<Widget> screens = [
    DashboardScreen(openFoodsTab: _openFoodsTab),
    const LogsScreen(),
    const ProgressScreen(),
    const GoalsScreen(),
    FoodsScreen(key: _foodsKey),
  ];

  void _openFoodsTab(int tabIndex) {
    if (index != 4) {
      setState(() => index = 4);
      _pageController.animateToPage(
        4,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foodsKey.currentState?.setTabIndex(tabIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
        ],
      ),
    );
  }
}
