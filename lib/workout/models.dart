import 'package:flutter/material.dart';
import 'dart:async';

class Exercise {
  final String id;
  final String name;
  final List<String> muscleGroups;
  final String icon;
  final double defaultIncrementKg;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroups,
    required this.icon,
    this.defaultIncrementKg = 2.5,
  });

  String get muscleGroup => muscleGroups.isNotEmpty ? muscleGroups.first : 'Other';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroups': muscleGroups,
    'icon': icon,
    'defaultIncrementKg': defaultIncrementKg,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final mg = json['muscleGroups'];
    final List<String> groups;
    if (mg is List) {
      groups = mg.cast<String>();
    } else if (json['muscleGroup'] is String) {
      groups = [json['muscleGroup'] as String];
    } else {
      groups = ['Other'];
    }
    return Exercise(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      muscleGroups: groups,
      icon: json['icon'] ?? 'fitness_center',
      defaultIncrementKg: (json['defaultIncrementKg'] ?? 2.5).toDouble(),
    );
  }
}

class WorkoutExercise {
  final Exercise exercise;
  final int plannedSets;
  final int plannedReps;
  final int restSeconds;

  WorkoutExercise({
    required this.exercise,
    required this.plannedSets,
    required this.plannedReps,
    this.restSeconds = 90,
  });

  Map<String, dynamic> toJson() => {
    'exercise': exercise.toJson(),
    'plannedSets': plannedSets,
    'plannedReps': plannedReps,
    'restSeconds': restSeconds,
  };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      exercise: Exercise.fromJson(json['exercise']),
      plannedSets: json['plannedSets'],
      plannedReps: json['plannedReps'],
      restSeconds: json['restSeconds'] ?? 90,
    );
  }
}

class Workout {
  final String id;
  final String name;
  final List<WorkoutExercise> items;

  Workout({required this.id, required this.name, required this.items});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'],
      name: json['name'],
      items: (json['items'] as List<dynamic>)
          .map((i) => WorkoutExercise.fromJson(i))
          .toList(),
    );
  }
}

class SetLog {
  final DateTime at;
  final String exerciseId;
  final String exerciseName;
  final double weight;
  final int reps;
  final int? rpe;
  final bool isPR;

  SetLog({
    required this.at,
    required this.exerciseId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    this.rpe,
    this.isPR = false,
  });

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'weight': weight,
    'reps': reps,
    'rpe': rpe,
    'isPR': isPR,
  };

  factory SetLog.fromJson(Map<String, dynamic> json) {
    return SetLog(
      at: DateTime.parse(json['at']),
      exerciseId: json['exerciseId'],
      exerciseName: json['exerciseName'] ?? json['exerciseId'],
      weight: (json['weight'] ?? 0).toDouble(),
      reps: json['reps'] ?? 0,
      rpe: json['rpe'],
      isPR: json['isPR'] ?? false,
    );
  }
}

class WorkoutSession extends ChangeNotifier {
  final String id;
  final String name;
  final DateTime startTime;
  DateTime? endTime;
  final List<SetLog> sets;
  final Workout? plan;
  final DateTime? startedAt;
  Duration elapsed = Duration.zero;
  int currentIndex = 0;
  int currentSetOfExercise = 0;
  int restRemainingSeconds = 0;
  final Map<String, List<SetLog>> logs;
  Timer? _timer;

  WorkoutSession({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    List<SetLog>? sets,
    this.plan,
    DateTime? startedAt,
    this.elapsed = Duration.zero,
    this.currentIndex = 0,
    this.currentSetOfExercise = 0,
    this.restRemainingSeconds = 0,
    Map<String, List<SetLog>>? logs,
  }) : sets = sets ?? [],
       logs = logs ?? {},
       startedAt = startedAt ?? startTime;

  WorkoutExercise get currentItem =>
      plan?.items[currentIndex] ??
      WorkoutExercise(
        exercise: Exercise(id: '', name: '', muscleGroups: const [], icon: ''),
        plannedSets: 0,
        plannedReps: 0,
      );
  List<SetLog> get lastLogForCurrent => logs[currentItem.exercise.id] ?? [];
  double suggestionWeightKg() {
    final last = lastLogForCurrent.isNotEmpty
        ? lastLogForCurrent.last.weight
        : 0;
    return last + currentItem.exercise.defaultIncrementKg;
  }

  int suggestionReps() => currentItem.plannedReps;
  double epley1RM(double weight, int reps) => weight * (1 + reps / 30);
  bool isPR(double weight, int reps) {
    final oneRM = epley1RM(weight, reps);
    final best = logs.values
        .expand((l) => l)
        .map((l) => epley1RM(l.weight, l.reps))
        .fold(0.0, (a, b) => a > b ? a : b);
    return oneRM > best;
  }

  void logSet(double weight, int reps, {int? rpe}) {
    final exerciseId = plan != null ? currentItem.exercise.id : 'free';
    final exerciseName = plan != null ? currentItem.exercise.name : 'Free';
    final log = SetLog(
      at: DateTime.now(),
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      rpe: rpe,
      isPR: isPR(weight, reps),
    );
    (logs[exerciseId] ??= []).add(log);
    sets.add(log);
    if (plan != null) {
      currentSetOfExercise++;
      if (currentSetOfExercise >= currentItem.plannedSets) {
        currentSetOfExercise = 0;
        currentIndex = (currentIndex + 1) % plan!.items.length;
      }
      restRemainingSeconds = currentItem.restSeconds;
    }
    notifyListeners();
  }

  void prev() {
    if (plan == null) return;
    currentIndex = (currentIndex - 1 + plan!.items.length) % plan!.items.length;
    currentSetOfExercise = 0;
    restRemainingSeconds = 0;
    notifyListeners();
  }

  void next() {
    if (plan == null) return;
    currentIndex = (currentIndex + 1) % plan!.items.length;
    currentSetOfExercise = 0;
    restRemainingSeconds = 0;
    notifyListeners();
  }

  void jumpTo(int index) {
    if (plan == null) return;
    currentIndex = index;
    currentSetOfExercise = 0;
    restRemainingSeconds = 0;
    notifyListeners();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed = DateTime.now().difference(startedAt ?? DateTime.now());
      if (restRemainingSeconds > 0) restRemainingSeconds--;
      notifyListeners();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'sets': sets.map((s) => s.toJson()).toList(),
    'plan': plan?.toJson(),
    'startedAt': startedAt?.toIso8601String(),
    'elapsed': elapsed.inSeconds,
    'currentIndex': currentIndex,
    'currentSetOfExercise': currentSetOfExercise,
    'restRemainingSeconds': restRemainingSeconds,
    'logs': logs.map((k, v) => MapEntry(k, v.map((l) => l.toJson()).toList())),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'],
      name: json['name'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      sets: (json['sets'] as List<dynamic>)
          .map((s) => SetLog.fromJson(s))
          .toList(),
      plan: json['plan'] != null ? Workout.fromJson(json['plan']) : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : null,
      elapsed: Duration(seconds: json['elapsed'] ?? 0),
      currentIndex: json['currentIndex'] ?? 0,
      currentSetOfExercise: json['currentSetOfExercise'] ?? 0,
      restRemainingSeconds: json['restRemainingSeconds'] ?? 0,
      logs:
          (json['logs'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as List<dynamic>).map((l) => SetLog.fromJson(l)).toList(),
            ),
          ) ??
          {},
    );
  }

  WorkoutSession copyWith({
    String? id,
    String? name,
    DateTime? startTime,
    DateTime? endTime,
    List<SetLog>? sets,
    Workout? plan,
    DateTime? startedAt,
    Duration? elapsed,
    int? currentIndex,
    int? currentSetOfExercise,
    int? restRemainingSeconds,
    Map<String, List<SetLog>>? logs,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      sets: sets ?? this.sets,
      plan: plan ?? this.plan,
      startedAt: startedAt ?? this.startedAt,
      elapsed: elapsed ?? this.elapsed,
      currentIndex: currentIndex ?? this.currentIndex,
      currentSetOfExercise: currentSetOfExercise ?? this.currentSetOfExercise,
      restRemainingSeconds: restRemainingSeconds ?? this.restRemainingSeconds,
      logs: logs ?? this.logs,
    );
  }
}
