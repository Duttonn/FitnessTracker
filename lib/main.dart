import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/ui/screens/dashboard_screen.dart';
import 'package:flutter_fitness_app/ui/screens/logs_screen.dart';
import 'package:flutter_fitness_app/ui/screens/progress_screen.dart';
import 'package:flutter_fitness_app/ui/screens/goals_screen.dart';
import 'package:flutter_fitness_app/ui/screens/foods_screen.dart';
import 'package:flutter_fitness_app/router.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/vision_nav_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()
        ..load()
        ..startRolloverTimer(),
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
    // Animate to foods page then set tab; using post-frame ensures state is mounted.
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
    // Enable edge-to-edge so we can draw under system gesture area
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
