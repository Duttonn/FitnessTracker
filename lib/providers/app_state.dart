import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/local_store_interface.dart';
import 'package:flutter_fitness_app/models/ingredient.dart';
import 'package:flutter_fitness_app/models/meal_def.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;
import 'package:supabase_flutter/supabase_flutter.dart';

enum FoodsTab { ingredients, meals } // added

class Goals {
  double protein;
  double carbs;
  double fat;
  double fiber;
  int kcal;
  DateTime? updatedAt; // sync metadata
  Goals({
    this.protein = 120,
    this.carbs = 250,
    this.fat = 65,
    this.fiber = 30,
    this.kcal = 2100,
    this.updatedAt,
  });
  Map<String, dynamic> toJson() => {
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'kcal': kcal,
    'updatedAt': updatedAt?.toIso8601String(),
  };
  factory Goals.fromJson(Map m) => Goals(
    protein: (m['protein'] ?? 120).toDouble(),
    carbs: (m['carbs'] ?? 250).toDouble(),
    fat: (m['fat'] ?? 65).toDouble(),
    fiber: (m['fiber'] ?? 30).toDouble(),
    kcal: (m['kcal'] ?? 2100).toInt(),
    updatedAt: m['updatedAt'] != null
        ? DateTime.tryParse(m['updatedAt'])
        : null,
  );
}

class GoalPreset {
  final String id;
  final String name;
  final Goals goals;
  GoalPreset({required this.id, required this.name, required this.goals});
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'goals': goals.toJson(),
  };
  factory GoalPreset.fromJson(Map<String, dynamic> m) => GoalPreset(
    id: m['id'] as String,
    name: m['name'] as String,
    goals: Goals.fromJson(Map<String, dynamic>.from(m['goals'] as Map)),
  );
}

enum Meal { breakfast, lunch, dinner, snack }

class MacroEntry {
  String id;
  String dayKey;
  DateTime createdAt;
  Meal meal;
  double protein, carbs, fat, fiber;
  int kcal;
  String? title;
  MacroEntry({
    required this.id,
    required this.dayKey,
    required this.createdAt,
    required this.meal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.kcal,
    this.title,
  });
  MacroEntry copyWith({
    String? id,
    String? dayKey,
    DateTime? createdAt,
    Meal? meal,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    int? kcal,
    String? title,
  }) => MacroEntry(
    id: id ?? this.id,
    dayKey: dayKey ?? this.dayKey,
    createdAt: createdAt ?? this.createdAt,
    meal: meal ?? this.meal,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    fiber: fiber ?? this.fiber,
    kcal: kcal ?? this.kcal,
    title: title ?? this.title,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'dayKey': dayKey,
    'createdAt': createdAt.toIso8601String(),
    'meal': meal.name,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'kcal': kcal,
    'title': title,
  };
  factory MacroEntry.fromJson(Map<String, dynamic> m) => MacroEntry(
    id: m['id'],
    dayKey: m['dayKey'],
    createdAt: DateTime.parse(m['createdAt']),
    meal: Meal.values.firstWhere(
      (e) => e.name == m['meal'],
      orElse: () => Meal.lunch,
    ),
    protein: (m['protein'] ?? 0).toDouble(),
    carbs: (m['carbs'] ?? 0).toDouble(),
    fat: (m['fat'] ?? 0).toDouble(),
    fiber: (m['fiber'] ?? 0).toDouble(),
    kcal: (m['kcal'] ?? 0).toInt(),
    title: m['title'],
  );
}

class Food {
  String id;
  String name;
  String? brand;
  double p100, c100, f100, fiber100;
  int kcal100;
  int servingGrams;
  bool favorite;
  Food({
    required this.id,
    required this.name,
    this.brand,
    required this.p100,
    required this.c100,
    required this.f100,
    required this.fiber100,
    required this.kcal100,
    this.servingGrams = 100,
    this.favorite = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'p100': p100,
    'c100': c100,
    'f100': f100,
    'fiber100': fiber100,
    'kcal100': kcal100,
    'servingGrams': servingGrams,
    'favorite': favorite,
  };
  factory Food.fromJson(Map<String, dynamic> m) => Food(
    id: m['id'],
    name: m['name'],
    brand: m['brand'],
    p100: (m['p100'] ?? 0).toDouble(),
    c100: (m['c100'] ?? 0).toDouble(),
    f100: (m['f100'] ?? 0).toDouble(),
    fiber100: (m['fiber100'] ?? 0).toDouble(),
    kcal100: (m['kcal100'] ?? 0).toInt(),
    servingGrams: (m['servingGrams'] ?? 100).toInt(),
    favorite: (m['favorite'] ?? false),
  );
}

class WeightEntry {
  DateTime loggedAt;
  double kg;
  WeightEntry({required this.loggedAt, required this.kg});
  Map<String, dynamic> toJson() => {
    'loggedAt': loggedAt.toIso8601String(),
    'kg': kg,
  };
  factory WeightEntry.fromJson(Map<String, dynamic> m) => WeightEntry(
    loggedAt: DateTime.parse(m['loggedAt']),
    kg: (m['kg'] ?? 0).toDouble(),
  );
}

class AppState extends ChangeNotifier {
  Goals goals = Goals();
  final Map<String, List<MacroEntry>> entriesByDay = {};
  final List<WeightEntry> weights = [];
  final List<Food> foods = []; // legacy simple foods
  // New structured foods
  final Map<String, Ingredient> ingredients = {};
  final Map<String, MealDef> meals = {};
  // Barcode -> ingredient id cache (persisted)
  final Map<String, String> barcodeCache = {};
  String? _lastDayKey; // to detect rollovers while app is open
  Timer? _rollTimer;
  // Goal presets
  Map<String, GoalPreset> goalPresets = {}; // id -> preset
  String? activeGoalPresetId;
  FoodsTab _foodsTab = FoodsTab.ingredients; // current foods screen tab
  List<int> activeWeekdays = List.generate(
    7,
    (i) => i,
  ); // 0=Mon? using existing order
  LocalStore _store = createLocalStore();
  // Expose whether cloud sync active (auth present)
  bool get isCloudSyncing => Supabase.instance.client.auth.currentUser != null;
  AppState() {
    _initStore();
  }
  Future<void> refreshStoreForAuthChange() async {
    final newStore = createLocalStore();
    _store = newStore;
    await _store.init();
    await load();
  }

  Future<void> _initStore() async {
    await _store.init();
    await load();
    startRolloverTimer();
  }

  static String dayKeyFrom(DateTime t) {
    final adj = t.subtract(const Duration(hours: 4));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${adj.year}-${two(adj.month)}-${two(adj.day)}';
  }

  List<MacroEntry> entriesForDay(String dayKey) => entriesByDay[dayKey] ?? [];
  Map<String, num> totalsForDay(String dayKey) {
    final list = entriesForDay(dayKey);
    double p = 0, c = 0, f = 0, fib = 0;
    int kcal = 0;
    for (final e in list) {
      p += e.protein;
      c += e.carbs;
      f += e.fat;
      fib += e.fiber;
      kcal += e.kcal;
    }
    return {'protein': p, 'carbs': c, 'fat': f, 'fiber': fib, 'kcal': kcal};
  }

  void addEntry(MacroEntry e) {
    final k = e.dayKey;
    (entriesByDay[k] ??= []).add(e);
    _save();
    notifyListeners();
  }

  void updateEntry(MacroEntry updated) {
    // If dayKey changed, move between day buckets
    for (final list in entriesByDay.values) {
      list.removeWhere((e) => e.id == updated.id && e.dayKey != updated.dayKey);
    }
    final list = entriesByDay[updated.dayKey];
    if (list != null) {
      final idx = list.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        list[idx] = updated;
      } else {
        list.add(updated);
      }
      _save();
      notifyListeners();
    }
  }

  void deleteEntry(String id, String dayKey) {
    entriesByDay[dayKey]?.removeWhere((e) => e.id == id);
    _save();
    notifyListeners();
  }

  void duplicateEntry(MacroEntry e) {
    addEntry(
      e.copyWith(
        id: _uuid(),
        createdAt: DateTime.now(),
        dayKey: dayKeyFrom(DateTime.now()),
      ),
    );
  }

  void setGoals(Goals g, {bool updateActivePreset = true}) {
    goals = g;
    goals.kcal = (g.protein * 4 + g.carbs * 4 + g.fat * 9).round();
    goals.updatedAt = DateTime.now();
    if (updateActivePreset && activeGoalPresetId != null) {
      final id = activeGoalPresetId!;
      final preset = goalPresets[id];
      if (preset != null) {
        goalPresets[id] = GoalPreset(
          id: preset.id,
          name: preset.name,
          goals: goals,
        );
      }
    }
    _save();
    notifyListeners();
  }

  String addGoalPreset(String name, Goals g) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    goalPresets[id] = GoalPreset(id: id, name: name, goals: g);
    _save();
    notifyListeners();
    return id;
  }

  void activateGoalPreset(String id) {
    final preset = goalPresets[id];
    if (preset == null) return;
    activeGoalPresetId = id;
    // apply goals WITHOUT updating preset (avoid recursion)
    setGoals(
      Goals(
        protein: preset.goals.protein,
        carbs: preset.goals.carbs,
        fat: preset.goals.fat,
        fiber: preset.goals.fiber,
        kcal: preset.goals.kcal,
      ),
      updateActivePreset: false,
    );
    _save();
    notifyListeners();
  }

  void bumpCarbs(int delta) {
    final newCarbs = (goals.carbs + delta).clamp(0, 999).toDouble();
    setGoals(
      Goals(
        protein: goals.protein,
        carbs: newCarbs,
        fat: goals.fat,
        fiber: goals.fiber,
        kcal: (goals.protein * 4 + newCarbs * 4 + goals.fat * 9).round(),
      ),
    );
  }

  void addFood(Food f) {
    foods.add(f);
    _save();
    notifyListeners();
  }

  void toggleFavorite(String foodId) {
    final f = foods.firstWhere((x) => x.id == foodId);
    f.favorite = !f.favorite;
    _save();
    notifyListeners();
  }

  void addWeight(double kg, {DateTime? at}) {
    weights.add(WeightEntry(loggedAt: at ?? DateTime.now(), kg: kg));
    _save();
    notifyListeners();
  }

  void tickDayRollover() {
    final current = dayKeyFrom(DateTime.now());
    _lastDayKey ??= current;
    if (_lastDayKey != current) {
      _lastDayKey = current;
      _save();
      notifyListeners();
    }
  }

  Future<void> load() async {
    final m = await _store.loadJson();
    if (m.isNotEmpty) {
      _fromJson(m);
    }
    _lastDayKey = dayKeyFrom(DateTime.now());
    notifyListeners();
  }

  Future<void> _save() async => _store.saveJson(toJson());

  Map<String, dynamic> toJson() => {
    'goals': goals.toJson(),
    'entriesByDay': entriesByDay.map(
      (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
    ),
    'weights': weights.map((w) => w.toJson()).toList(),
    'foods': foods.map((f) => f.toJson()).toList(),
    'ingredients': ingredients.map((k, v) => MapEntry(k, v.toJson())),
    'meals': meals.map((k, v) => MapEntry(k, v.toJson())),
    'goalPresets': goalPresets.map((k, v) => MapEntry(k, v.toJson())),
    'activeGoalPresetId': activeGoalPresetId,
    'barcodeCache': barcodeCache,
    'activeWeekdays': activeWeekdays,
  };
  void _fromJson(Map m) {
    goals = Goals.fromJson(m['goals'] ?? {});
    entriesByDay.clear();
    (m['entriesByDay'] ?? {}).forEach((k, list) {
      entriesByDay[k] = (list as List)
          .map((e) => MacroEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
    weights
      ..clear()
      ..addAll(
        ((m['weights'] ?? []) as List).map(
          (w) => WeightEntry.fromJson(Map<String, dynamic>.from(w)),
        ),
      );
    foods
      ..clear()
      ..addAll(
        ((m['foods'] ?? []) as List).map(
          (f) => Food.fromJson(Map<String, dynamic>.from(f)),
        ),
      );
    // new structured foods
    ingredients
      ..clear()
      ..addAll(
        ((m['ingredients'] ?? {}) as Map).map(
          (k, v) => MapEntry(
            k as String,
            Ingredient.fromJson(Map<String, dynamic>.from(v)),
          ),
        ),
      );
    meals
      ..clear()
      ..addAll(
        ((m['meals'] ?? {}) as Map).map(
          (k, v) => MapEntry(
            k as String,
            MealDef.fromJson(Map<String, dynamic>.from(v)),
          ),
        ),
      );
    // goal presets
    goalPresets.clear();
    final gp = m['goalPresets'];
    if (gp is Map) {
      gp.forEach((k, v) {
        try {
          goalPresets[k as String] = GoalPreset.fromJson(
            Map<String, dynamic>.from(v as Map),
          );
        } catch (_) {}
      });
    }
    activeGoalPresetId = m['activeGoalPresetId'] as String?;
    // barcode cache
    barcodeCache.clear();
    final bc = m['barcodeCache'];
    if (bc is Map) {
      bc.forEach((k, v) {
        if (k is String && v is String) barcodeCache[k] = v;
      });
    }
    final aw = m['activeWeekdays'];
    if (aw is List) {
      activeWeekdays = aw.whereType<int>().toList();
    }
  }

  static String _uuid() => DateTime.now().microsecondsSinceEpoch.toString();
  static String newId() => _uuid(); // convenience for UI

  void startRolloverTimer() {
    _rollTimer?.cancel();
    _rollTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => tickDayRollover(),
    );
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    super.dispose();
  }

  void mergeImport(
    Map<String, List<MacroEntry>> map,
    List<WeightEntry> newWeights,
  ) {
    map.forEach((k, list) {
      (entriesByDay[k] ??= []).addAll(list);
    });
    weights.addAll(newWeights);
    _save();
    notifyListeners();
  }

  String generateId() => _uuid();

  // Ingredient CRUD
  String addIngredient(Ingredient ing) {
    final id = ing.id.isEmpty ? _uuid() : ing.id;
    ingredients[id] = ing.copyWith(id: id, updatedAt: DateTime.now());
    _save();
    notifyListeners();
    return id;
  }

  void updateIngredient(Ingredient ing) {
    if (!ingredients.containsKey(ing.id)) return;
    ingredients[ing.id] = ing.copyWith(updatedAt: DateTime.now());
    _save();
    notifyListeners();
  }

  void removeIngredient(String id) {
    ingredients.remove(id);
    _save();
    notifyListeners();
  }

  String addMeal(MealDef meal) {
    final id = meal.id.isEmpty ? _uuid() : meal.id;
    meals[id] = meal.copyWith(id: id, updatedAt: DateTime.now());
    _save();
    notifyListeners();
    return id;
  }

  void updateMeal(MealDef meal) {
    if (!meals.containsKey(meal.id)) return;
    meals[meal.id] = meal.copyWith(updatedAt: DateTime.now());
    _save();
    notifyListeners();
  }

  void removeMeal(String id) {
    meals.remove(id);
    _save();
    notifyListeners();
  }

  void importExportJson(Map<String, dynamic> data, {bool replace = false}) {
    try {
      if (replace) {
        entriesByDay.clear();
        weights.clear();
        ingredients.clear();
        meals.clear();
      }
      // goals
      final g = data['goals'];
      if (g is Map) {
        goals = Goals.fromJson(Map<String, dynamic>.from(g));
        goals.kcal = (goals.protein * 4 + goals.carbs * 4 + goals.fat * 9)
            .round();
      }
      // weights
      final wList = data['weights'];
      if (wList is List) {
        for (final w in wList) {
          try {
            final we = WeightEntry.fromJson(Map<String, dynamic>.from(w));
            if (!weights.any((e) => e.loggedAt == we.loggedAt)) {
              weights.add(we);
            }
          } catch (_) {}
        }
      }
      // days / entries
      final days = data['days'];
      if (days is Map) {
        days.forEach((key, value) {
          if (value is Map && value['entries'] is List) {
            final list = (value['entries'] as List)
                .map((e) => MacroEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            final target = (entriesByDay[key] ??= []);
            for (final entry in list) {
              if (!target.any((e) => e.id == entry.id)) {
                target.add(entry);
              }
            }
          }
        });
      }
      _save();
      notifyListeners();
    } catch (e) {
      // swallow errors; caller will surface generic failure via UI
    }
  }

  // ===== Barcode / OFF Integration =====
  static bool _offConfigured = false;
  void _ensureOffConfig() {
    if (_offConfigured) return;
    off.OpenFoodAPIConfiguration.userAgent = off.UserAgent(
      name: 'MacroMate',
      version: '1.0.0',
    );
    _offConfigured = true;
  }

  Ingredient ingredientFromOFF(off.Product p) {
    final n = p.nutriments; // Nutriments?
    double safe(double? v) => (v ?? 0).toDouble();
    int kcal() {
      // Try direct energy kcal per 100g
      final kcalVal = n?.getValue(
        off.Nutrient.energyKCal,
        off.PerSize.oneHundredGrams,
      );
      if (kcalVal != null) return kcalVal.round();
      // Try energy kJ then convert
      final kjVal = n?.getValue(
        off.Nutrient.energyKJ,
        off.PerSize.oneHundredGrams,
      );
      if (kjVal != null) return (kjVal * 0.239006).round();
      // Derive from macros if available
      final pr = safe(
        n?.getValue(off.Nutrient.proteins, off.PerSize.oneHundredGrams),
      );
      final ca = safe(
        n?.getValue(off.Nutrient.carbohydrates, off.PerSize.oneHundredGrams),
      );
      final fa = safe(
        n?.getValue(off.Nutrient.fat, off.PerSize.oneHundredGrams),
      );
      return (pr * 4 + ca * 4 + fa * 9).round();
    }

    return Ingredient(
      name: p.productName ?? 'Unknown',
      protein100: safe(
        n?.getValue(off.Nutrient.proteins, off.PerSize.oneHundredGrams),
      ),
      carbs100: safe(
        n?.getValue(off.Nutrient.carbohydrates, off.PerSize.oneHundredGrams),
      ),
      fat100: safe(n?.getValue(off.Nutrient.fat, off.PerSize.oneHundredGrams)),
      fiber100: safe(
        n?.getValue(off.Nutrient.fiber, off.PerSize.oneHundredGrams),
      ),
      kcal100: kcal(),
      barcode: p.barcode,
      brand: (p.brandsTags?.isNotEmpty ?? false)
          ? p.brandsTags!.first
          : p.brands,
      imageUrl: p.imageFrontUrl,
      source: 'openfoodfacts',
      lastFetchedAt: DateTime.now(),
    );
  }

  Future<Ingredient?> lookupIngredientByBarcode(String barcode) async {
    // 1. Local cache direct match
    final localId = barcodeCache[barcode];
    if (localId != null) {
      final ing = ingredients[localId];
      if (ing != null) return ing;
    }
    // 2. Search existing ingredients metadata
    for (final ing in ingredients.values) {
      if (ing.barcode == barcode) {
        barcodeCache[barcode] = ing.id;
        return ing;
      }
    }
    // 3. OFF lookup
    try {
      _ensureOffConfig();
      final cfg = off.ProductQueryConfiguration(
        barcode,
        version: off.ProductQueryVersion.v3,
        language: off.OpenFoodFactsLanguage.ENGLISH,
        fields: [
          off.ProductField.BARCODE,
          off.ProductField.NAME,
          off.ProductField.BRANDS_TAGS,
          off.ProductField.BRANDS,
          off.ProductField.NUTRIMENTS,
          off.ProductField.IMAGE_FRONT_URL,
        ],
      );
      final result = await off.OpenFoodAPIClient.getProductV3(cfg);
      if (result.product != null) {
        return ingredientFromOFF(result.product!);
      }
      return null; // not found
    } catch (_) {
      return null; // network / parsing failure
    }
  }

  Future<Ingredient> upsertIngredientFromBarcode(String barcode) async {
    Ingredient? existing;
    for (final ing in ingredients.values) {
      if (ing.barcode == barcode) {
        existing = ing;
        break;
      }
    }
    Ingredient? fetched;
    try {
      _ensureOffConfig();
      final cfg = off.ProductQueryConfiguration(
        barcode,
        version: off.ProductQueryVersion.v3,
        language: off.OpenFoodFactsLanguage.ENGLISH,
        fields: [
          off.ProductField.BARCODE,
          off.ProductField.NAME,
          off.ProductField.BRANDS,
          off.ProductField.QUANTITY,
          off.ProductField.NUTRIMENTS,
        ],
      );
      final resp = await off.OpenFoodAPIClient.getProductV3(cfg);
      final p = resp.product;
      if (p != null) {
        final nutr = p.nutriments; // may be null
        double gv(off.Nutrient ntr) =>
            nutr?.getValue(ntr, off.PerSize.oneHundredGrams)?.toDouble() ?? 0;
        final protein = gv(off.Nutrient.proteins);
        final carbs = gv(off.Nutrient.carbohydrates);
        final fat = gv(off.Nutrient.fat);
        final fiber = gv(off.Nutrient.fiber);
        int kcal;
        final kcalDirect = nutr?.getValue(
          off.Nutrient.energyKCal,
          off.PerSize.oneHundredGrams,
        );
        if (kcalDirect != null) {
          kcal = kcalDirect.round();
        } else {
          final kjVal = nutr?.getValue(
            off.Nutrient.energyKJ,
            off.PerSize.oneHundredGrams,
          );
          if (kjVal != null) {
            kcal = (kjVal / 4.184).round();
          } else {
            kcal = (protein * 4 + carbs * 4 + fat * 9).round();
          }
        }
        final parts = <String>[];
        if ((p.productName ?? '').trim().isNotEmpty) {
          parts.add(p.productName!.trim());
        } else if ((p.brands ?? '').trim().isNotEmpty) {
          parts.add(p.brands!.split(',').first.trim());
        }
        if ((p.quantity ?? '').trim().isNotEmpty) parts.add(p.quantity!.trim());
        final name = parts.isEmpty ? 'Product $barcode' : parts.join(' – ');
        fetched = Ingredient(
          id: existing?.id ?? '',
          name: name,
          protein100: protein,
          carbs100: carbs,
          fat100: fat,
          fiber100: fiber,
          kcal100: kcal,
          barcode: barcode,
          brand: p.brands,
          source: 'openfoodfacts',
          lastFetchedAt: DateTime.now(),
        );
      }
    } catch (_) {
      // swallow
    }
    final toSave =
        fetched ??
        existing ??
        Ingredient(
          id: '',
          name: 'Product $barcode',
          protein100: 0,
          carbs100: 0,
          fat100: 0,
          fiber100: 0,
          kcal100: 0,
          barcode: barcode,
          source: 'manual',
        );
    final id = upsertIngredient(toSave);
    return ingredients[id]!;
  }

  String upsertIngredient(Ingredient i) {
    // If barcode exists, update existing
    if (i.barcode != null) {
      final existing = ingredients.values.firstWhere(
        (ing) => ing.barcode == i.barcode,
        orElse: () => i,
      );
      if (existing.id.isNotEmpty && existing != i) {
        final updated = existing.copyWith(
          name: i.name,
          protein100: i.protein100,
          carbs100: i.carbs100,
          fat100: i.fat100,
          fiber100: i.fiber100,
          kcal100: i.kcal100,
          brand: i.brand ?? existing.brand,
          imageUrl: i.imageUrl ?? existing.imageUrl,
          source: i.source,
          barcode: i.barcode,
          lastFetchedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        ingredients[existing.id] = updated;
        barcodeCache[i.barcode!] = existing.id;
        _save();
        notifyListeners();
        return existing.id;
      }
    }
    final id = i.id.isEmpty ? _uuid() : i.id;
    ingredients[id] = i.copyWith(
      id: id,
      lastFetchedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (i.barcode != null) {
      barcodeCache[i.barcode!] = id;
    }
    _save();
    notifyListeners();
    return id;
  }

  // Convenience wrapper used by UI (alias for upsertIngredient)
  String addOrUpdateIngredientByBarcode(Ingredient ing) =>
      upsertIngredient(ing);
  Ingredient? ingredientByBarcode(String barcode) {
    for (final ing in ingredients.values) {
      if (ing.barcode == barcode) return ing;
    }
    return null;
  }

  Future<void> addScannedIngredientToToday({
    required Ingredient ingredient,
    required double grams,
    Meal meal = Meal.snack,
  }) async {
    final dayKey = dayKeyFrom(DateTime.now());
    final m = ingredient.forGrams(grams);
    addEntry(
      MacroEntry(
        id: _uuid(),
        dayKey: dayKey,
        createdAt: DateTime.now(),
        meal: meal,
        protein: m.protein,
        carbs: m.carbs,
        fat: m.fat,
        fiber: m.fiber,
        kcal: m.kcal,
        title: ingredient.name,
      ),
    );
  }

  Future<Ingredient?> addIngredientFromBarcode(String barcode) async {
    // Try existing ingredient by barcode
    for (final ing in ingredients.values) {
      if (ing.barcode == barcode) return ing;
    }
    // Fetch (will not persist) using existing lookup method
    final fetched = await lookupIngredientByBarcode(barcode);
    if (fetched == null) return null; // not found on OFF
    final id = upsertIngredient(fetched.copyWith(barcode: barcode));
    return ingredients[id];
  }

  Future<Ingredient> ensureIngredientFromBarcode(String barcode) async {
    final existing = ingredients.values.firstWhere(
      (i) => i.barcode == barcode,
      orElse: () => const Ingredient(
        id: '',
        name: '',
        protein100: 0,
        carbs100: 0,
        fat100: 0,
        fiber100: 0,
        kcal100: 0,
      ),
    );
    if (existing.barcode == barcode && existing.id.isNotEmpty) {
      return existing;
    }
    final added = await addIngredientFromBarcode(barcode);
    if (added != null) return added;
    // Fallback manual stub so flows can continue
    final fallback = Ingredient(
      id: '',
      name: 'Product $barcode',
      protein100: 0,
      carbs100: 0,
      fat100: 0,
      fiber100: 0,
      kcal100: 0,
      barcode: barcode,
      source: 'manual',
    );
    final id = upsertIngredient(fallback);
    return ingredients[id]!;
  }

  FoodsTab get foodsTab => _foodsTab;
  void setFoodsTab(FoodsTab tab) {
    if (_foodsTab == tab) return;
    _foodsTab = tab;
    notifyListeners();
  }

  // Added: reset state after logout
  void resetForLogout() {
    goals = Goals();
    entriesByDay.clear();
    weights.clear();
    foods.clear();
    ingredients.clear();
    meals.clear();
    goalPresets.clear();
    activeGoalPresetId = null;
    barcodeCache.clear();
    _rollTimer?.cancel();
    _lastDayKey = null;
    _save();
    notifyListeners();
  }
}
