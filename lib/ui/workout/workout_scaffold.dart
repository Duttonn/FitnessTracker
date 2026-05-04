import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme.dart';
import '../../workout/models.dart';
import 'WorkoutNavBar.dart';
import 'exercise_picker_sheet.dart';

class WorkoutScaffold extends StatefulWidget {
  const WorkoutScaffold({super.key});

  @override
  State<WorkoutScaffold> createState() => _WorkoutScaffoldState();
}

class _WorkoutScaffoldState extends State<WorkoutScaffold> {
  int _tabIndex = 0;
  late final PageController _pageController = PageController();

  void _goTo(int i) {
    if (i == _tabIndex) return;
    setState(() => _tabIndex = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.bgDark,
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _tabIndex = i),
                children: const [
                  _TodayTab(),
                  _TodayTab(), // Activity placeholder (same data for now)
                  _ProgressTab(),
                  _HistoryTab(),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: WorkoutNavBar(
                  currentIndex: _tabIndex,
                  onTab: _goTo,
                ),
              ),
            ],
          ),
          floatingActionButton: _tabIndex == 0 || _tabIndex == 1
              ? _LogSetFab(scaffoldContext: ctx)
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        ),
      ),
    );
  }
}

class _LogSetFab extends StatelessWidget {
  const _LogSetFab({required this.scaffoldContext});
  final BuildContext scaffoldContext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showExercisePicker(scaffoldContext);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'LOG SET',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ── Today Tab ────────────────────────────────────────────────────────────────

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dayType = appState.todayDayType;
    final todaySets = appState.todaySetLogs();
    final safeTop = MediaQuery.viewPaddingOf(context).top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: safeTop + 16)),

        // Header row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Today',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Back to macros button
                _ExitWorkoutButton(),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Day type banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: dayType == null
                ? _NoCheckinBanner()
                : _DayTypeBanner(dayType: dayType),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Today's sets
        if (todaySets.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _EmptySession(),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'TODAY\'S SETS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SetLogTile(log: todaySets[i]),
              childCount: todaySets.length,
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }
}

class _ExitWorkoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AppState>().exitWorkoutMode(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_rounded, color: Colors.white60, size: 15),
            const SizedBox(width: 6),
            const Text(
              'Macros',
              style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTypeBanner extends StatelessWidget {
  const _DayTypeBanner({required this.dayType});
  final DayType dayType;

  Color get _color => switch (dayType) {
    DayType.rest => const Color(0xFF48CAE4),
    DayType.training => AppColors.primary,
    DayType.intense => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: .3)),
      ),
      child: Row(
        children: [
          Text(dayType.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayType.label,
                style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Consumer<AppState>(
                builder: (_, s, __) {
                  final profile = s.macroProfiles[dayType]!;
                  return Text(
                    '${profile.kcal} kcal  ·  ${profile.protein.toInt()}p  ${profile.carbs.toInt()}c  ${profile.fat.toInt()}f',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoCheckinBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No day type selected for today.',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySession extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center_rounded, color: Colors.white24, size: 40),
          const SizedBox(height: 12),
          const Text(
            'No sets logged yet',
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap LOG SET to get started',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SetLogTile extends StatelessWidget {
  const _SetLogTile({required this.log});
  final SetLog log;

  @override
  Widget build(BuildContext context) {
    final timeStr = _timeAgo(log.at);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.exerciseName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${log.weight % 1 == 0 ? log.weight.toInt() : log.weight}kg × ${log.reps} reps',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Progress Tab ──────────────────────────────────────────────────────────────

class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final safeTop = MediaQuery.viewPaddingOf(context).top;

    // Collect all exercises that have been logged
    final exercisesWithLogs = appState.allSetLogs.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    // Map exerciseId → Exercise from all exercises (built-in + custom)
    final libMap = appState.exerciseLibraryMap;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: safeTop + 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Exercise Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                _ExitWorkoutButton(),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (exercisesWithLogs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.bar_chart_rounded, color: Colors.white24, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Log sets to see your progress here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final entry = exercisesWithLogs[i];
                final exercise = libMap[entry.key];
                final name = exercise?.name ?? entry.key;
                final groups = exercise?.muscleGroups.join(' · ') ?? '';
                final logs = entry.value;
                final last = logs.last;
                // Compute best 1RM
                double best1rm = 0;
                for (final l in logs) {
                  final rm = l.weight * (1 + l.reps / 30);
                  if (rm > best1rm) best1rm = rm;
                }
                return Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                   child: GestureDetector(
                     onTap: () => _showExerciseDetail(ctx, exercise, name, groups, logs),
                     child: _ExerciseProgressCard(
                       name: name,
                       groups: groups,
                       last: last,
                       best1rm: best1rm,
                       setCount: logs.length,
                       logs: logs,
                     ),
                   ),
                 );
              },
              childCount: exercisesWithLogs.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  void _showExerciseDetail(
    BuildContext context,
    Exercise? exercise,
    String name,
    String groups,
    List<SetLog> logs,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExerciseDetailSheet(
        name: name,
        groups: groups,
        logs: logs,
      ),
    );
  }
}

class _ExerciseProgressCard extends StatelessWidget {
  const _ExerciseProgressCard({
    required this.name,
    required this.groups,
    required this.last,
    required this.best1rm,
    required this.setCount,
    required this.logs,
  });

  final String name;
  final String groups;
  final SetLog last;
  final double best1rm;
  final int setCount;
  final List<SetLog> logs;

  @override
  Widget build(BuildContext context) {
    final lastWeight = last.weight % 1 == 0 ? last.weight.toInt().toString() : last.weight.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (groups.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(groups, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: 'Last', value: '${lastWeight}kg × ${last.reps}'),
              const SizedBox(width: 16),
              _Stat(label: 'Best E1RM', value: '${best1rm.toStringAsFixed(1)}kg'),
              const SizedBox(width: 16),
              _Stat(label: 'Sets', value: '$setCount'),
            ],
          ),
          const SizedBox(height: 10),
          _E1rmChart(logs: logs),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

// ── E1RM Sparkline ────────────────────────────────────────────────────────────

class _E1rmChart extends StatelessWidget {
  const _E1rmChart({required this.logs});
  final List<SetLog> logs;

  @override
  Widget build(BuildContext context) {
    // Build chronological E1RM data points — one per calendar day (max)
    final byDay = <String, double>{};
    for (final l in logs) {
      final dk = AppState.dayKeyFrom(l.at);
      final rm = l.weight * (1 + l.reps / 30);
      if ((byDay[dk] ?? 0) < rm) byDay[dk] = rm;
    }
    final sorted = byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (sorted.length < 2) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: Text('Log more sessions to see trend', style: TextStyle(color: Colors.white24, fontSize: 11)),
        ),
      );
    }
    final spots = sorted.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.96;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.04;

    return SizedBox(
      height: 52,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                  color: AppColors.primary,
                  strokeColor: AppColors.primary,
                  radius: 2.5,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: .12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── History Tab ─────────────────────────────────────────────────────────────────

/// Groups all logged sets by calendar day and shows them as collapsible sessions.
/// When a day has ≥2 exercises from the same primary muscle group, it labels that
/// session with the category name (e.g. "Chest Session").
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  /// Determine session label from the exercises logged on a given day.
  /// Returns the primary muscle group if ≥2 distinct exercises share it.
  String? _categoryLabel(List<SetLog> sets, Map<String, Exercise> libMap) {
    final countPerGroup = <String, Set<String>>{}; // group -> set of exerciseIds
    for (final s in sets) {
      final ex = libMap[s.exerciseId];
      if (ex == null) continue;
      for (final g in ex.muscleGroups) {
        (countPerGroup[g] ??= {}).add(s.exerciseId);
      }
    }
    // Find any group with 2+ distinct exercises
    String? best;
    int bestCount = 1;
    countPerGroup.forEach((g, ids) {
      if (ids.length > bestCount) {
        best = g;
        bestCount = ids.length;
      } else if (ids.length == 2 && best == null) {
        best = g;
      }
    });
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final appState = context.watch<AppState>();
    final libMap = appState.exerciseLibraryMap;

    // Group all sets by day key, sorted newest-first
    final byDay = <String, List<SetLog>>{};
    for (final logs in appState.allSetLogs.values) {
      for (final log in logs) {
        final dk = AppState.dayKeyFrom(log.at);
        (byDay[dk] ??= []).add(log);
      }
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: safeTop + 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'History',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                _ExitWorkoutButton(),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (days.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.history_rounded, color: Colors.white24, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'No sessions logged yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final dayKey = days[i];
                final daySets = byDay[dayKey]!;
                final category = _categoryLabel(daySets, libMap);
                return _SessionCard(
                  dayKey: dayKey,
                  sets: daySets,
                  libMap: libMap,
                  categoryLabel: category,
                );
              },
              childCount: days.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.dayKey,
    required this.sets,
    required this.libMap,
    this.categoryLabel,
  });
  final String dayKey;
  final List<SetLog> sets;
  final Map<String, Exercise> libMap;
  final String? categoryLabel;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(widget.dayKey) ?? DateTime.now();
    final isToday = widget.dayKey == AppState.dayKeyFrom(DateTime.now());
    final label = isToday
        ? 'Today'
        : DateFormat('EEE, MMM d').format(date);

    // Group by exercise for the summary line
    final byEx = <String, List<SetLog>>{};
    for (final s in widget.sets) {
      (byEx[s.exerciseId] ??= []).add(s);
    }
    final totalVolume = widget.sets.fold<double>(0, (acc, s) => acc + s.weight * s.reps);
    final prCount = widget.sets.where((s) => s.isPR).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: isToday ? AppColors.primary : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (widget.categoryLabel != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '💪 ${widget.categoryLabel} Session',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${byEx.length} exercise${byEx.length == 1 ? '' : 's'}  ·  ${widget.sets.length} sets  ·  ${(totalVolume / 1000).toStringAsFixed(1)}t volume',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (prCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🏆 $prCount PR',
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
              // Expanded detail
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                for (final entry in byEx.entries) ...[
                  _ExerciseSetGroup(
                    exerciseName: widget.libMap[entry.key]?.name ?? entry.key,
                    sets: entry.value,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseSetGroup extends StatelessWidget {
  const _ExerciseSetGroup({required this.exerciseName, required this.sets});
  final String exerciseName;
  final List<SetLog> sets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exerciseName,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: sets.map((s) {
            final w = s.weight % 1 == 0 ? s.weight.toInt().toString() : s.weight.toStringAsFixed(1);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: s.isPR
                    ? const Color(0xFFFFD700).withValues(alpha: .12)
                    : AppColors.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: s.isPR
                      ? const Color(0xFFFFD700).withValues(alpha: .4)
                      : AppColors.primary.withValues(alpha: .25),
                ),
              ),
              child: Text(
                '${w}kg × ${s.reps}${s.isPR ? ' 🏆' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: s.isPR ? const Color(0xFFFFD700) : AppColors.primary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Exercise Detail Sheet ─────────────────────────────────────────────────────────────────

/// Full-screen modal showing per-exercise E1RM chart + history of all sessions.
class _ExerciseDetailSheet extends StatefulWidget {
  const _ExerciseDetailSheet({
    required this.name,
    required this.groups,
    required this.logs,
  });
  final String name;
  final String groups;
  final List<SetLog> logs;

  @override
  State<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<_ExerciseDetailSheet> {
  String? _selectedDay; // dayKey currently expanded

  @override
  Widget build(BuildContext context) {
    // Group logs by day, sorted oldest-first for chart
    final byDay = <String, List<SetLog>>{};
    for (final l in widget.logs) {
      (byDay[AppState.dayKeyFrom(l.at)] ??= []).add(l);
    }
    final sortedDays = byDay.keys.toList()..sort();

    // Build E1RM spots per day
    final spots = <FlSpot>[];
    for (var i = 0; i < sortedDays.length; i++) {
      final dayLogs = byDay[sortedDays[i]]!;
      final bestRm = dayLogs.map((l) => l.weight * (1 + l.reps / 30)).reduce((a, b) => a > b ? a : b);
      spots.add(FlSpot(i.toDouble(), bestRm));
    }

    final minY = spots.isEmpty ? 0.0 : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = spots.isEmpty ? 100.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.05;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => CustomScrollView(
          controller: scrollCtrl,
          slivers: [
            // Drag handle + title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.name,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    if (widget.groups.isNotEmpty)
                      Text(widget.groups, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // E1RM chart
            if (spots.length >= 2)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ESTIMATED 1RM TREND',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (_) => const FlLine(
                                color: Colors.white10,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (v, _) => Text(
                                    '${v.toStringAsFixed(0)}kg',
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: (sortedDays.length / 4).ceilToDouble().clamp(1, 999),
                                  getTitlesWidget: (v, _) {
                                    final idx = v.toInt();
                                    if (idx < 0 || idx >= sortedDays.length) return const SizedBox();
                                    final d = DateTime.tryParse(sortedDays[idx]);
                                    if (d == null) return const SizedBox();
                                    return Text(
                                      DateFormat('d MMM').format(d),
                                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (spots) => spots.map((s) {
                                  final idx = s.x.toInt();
                                  final d = idx < sortedDays.length ? DateTime.tryParse(sortedDays[idx]) : null;
                                  final dateStr = d != null ? DateFormat('d MMM').format(d) : '';
                                  return LineTooltipItem(
                                    '$dateStr\n${s.y.toStringAsFixed(1)}kg E1RM',
                                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  );
                                }).toList(),
                              ),
                              handleBuiltInTouches: true,
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 2.5,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                                    color: AppColors.primary,
                                    strokeColor: const Color(0xFF0A0A0A),
                                    radius: 4,
                                    strokeWidth: 2,
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.primary.withValues(alpha: .1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            // Per-session history
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  'SESSION HISTORY',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  // newest-first
                  final dayKey = sortedDays[sortedDays.length - 1 - i];
                  final dayLogs = byDay[dayKey]!..sort((a, b) => a.at.compareTo(b.at));
                  final date = DateTime.tryParse(dayKey);
                  final isToday = dayKey == AppState.dayKeyFrom(DateTime.now());
                  final dateLabel = isToday ? 'Today' : (date != null ? DateFormat('EEE, MMM d').format(date) : dayKey);
                  final isExpanded = _selectedDay == dayKey;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDay = isExpanded ? null : dayKey),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: isExpanded
                              ? Border.all(color: AppColors.primary.withValues(alpha: .4))
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    color: isToday ? AppColors.primary : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${dayLogs.length} sets',
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                              ],
                            ),
                            if (isExpanded) ...[
                              const SizedBox(height: 10),
                              const Divider(color: Colors.white12, height: 1),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: dayLogs.map((s) {
                                  final w = s.weight % 1 == 0 ? s.weight.toInt().toString() : s.weight.toStringAsFixed(1);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: s.isPR
                                          ? const Color(0xFFFFD700).withValues(alpha: .12)
                                          : AppColors.primary.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: s.isPR
                                            ? const Color(0xFFFFD700).withValues(alpha: .4)
                                            : AppColors.primary.withValues(alpha: .25),
                                      ),
                                    ),
                                    child: Text(
                                      '${w}kg × ${s.reps}${s.isPR ? ' 🏆' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: s.isPR ? const Color(0xFFFFD700) : AppColors.primary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: sortedDays.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
