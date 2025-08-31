import '../providers/app_state.dart';

class OldExportParser {
  static ({
    Map<String, List<MacroEntry>> entriesByDay,
    List<WeightEntry> weights,
  })
  parse(String input) {
    final lines = input.split(RegExp(r'\r?\n'));
    final map = <String, List<MacroEntry>>{};
    final weights = <WeightEntry>[];
    String? currentDayKey;
    Meal? currentMeal;
    final dayHeader = RegExp(
      r'^DAY\s+\d+:\s*(\d{1,2}/\d{1,2}/\d{4})\s*\|\s*([\d\.]+)\s*Calories.*\|\s*([\d\.]+)\s*KG$',
      caseSensitive: false,
    );
    final mealHeader = RegExp(
      r'^(Breakfast|Lunch|Dinner|Snack)={2,}$',
      caseSensitive: false,
    );
    final entryLine = RegExp(
      r'^\s*(.+?)\s*\|\s*(.+?)\s*\|\s*([\d\.]+)\s*Calories\s*\|\s*([\d\.]+)g\s*Carbs\s*\|\s*([\d\.]+)g\s*Fat\s*\|\s*([\d\.]+)g\s*Protein\s*$',
      caseSensitive: false,
    );
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final d = dayHeader.firstMatch(line);
      if (d != null) {
        final mdyyyy = d.group(1);
        final kgStr = d.group(3);
        if (mdyyyy == null) {
          throw const FormatException('Missing date in legacy export header');
        }
        final date = DateTime.parse(_toIso(mdyyyy));
        currentDayKey = AppState.dayKeyFrom(date);
        map.putIfAbsent(currentDayKey, () => []);
        final kg = double.tryParse(kgStr ?? '');
        if (kg != null) {
          weights.add(WeightEntry(loggedAt: date, kg: kg));
        }
        currentMeal = null;
        continue;
      }
      final m = mealHeader.firstMatch(line);
      if (m != null) {
        final mealName = (m.group(1) ?? '').toLowerCase();
        currentMeal = switch (mealName) {
          'breakfast' => Meal.breakfast,
          'lunch' => Meal.lunch,
          'dinner' => Meal.dinner,
          _ => Meal.snack,
        };
        continue;
      }
      final e = entryLine.firstMatch(line);
      if (e != null && currentDayKey != null) {
        final titleRaw = e.group(1) ?? '';
        final caloriesStr = e.group(3) ?? '0';
        final carbsStr = e.group(4) ?? '0';
        final fatStr = e.group(5) ?? '0';
        final protStr = e.group(6) ?? '0';
        final title = titleRaw.trim();
        final calories = int.tryParse(caloriesStr.split('.').first) ?? 0;
        final carbs = double.tryParse(carbsStr) ?? 0;
        final fat = double.tryParse(fatStr) ?? 0;
        final prot = double.tryParse(protStr) ?? 0;
        map[currentDayKey]!.add(
          MacroEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            dayKey: currentDayKey,
            createdAt: DateTime.now(),
            meal: currentMeal ?? Meal.lunch,
            protein: prot,
            carbs: carbs,
            fat: fat,
            fiber: 0,
            kcal: calories,
            title: title.isEmpty ? 'Quick Add' : title,
          ),
        );
      }
    }
    return (entriesByDay: map, weights: weights);
  }

  static String _toIso(String mdyyyy) {
    final parts = mdyyyy.split('/');
    final m = parts[0].padLeft(2, '0');
    final d = parts[1].padLeft(2, '0');
    final y = parts[2];
    return '$y-$m-$d';
  }
}
