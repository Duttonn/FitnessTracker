import 'ingredient.dart';

class MealPart {
  final String ingredientId; // empty when using embedded snapshot
  final double grams; // weight of this ingredient in the meal
  // Embedded snapshot (used when ingredient not persisted)
  final String? name; // display name when embedded
  final double? protein100;
  final double? carbs100;
  final double? fat100;
  final double? fiber100;
  final int? kcal100;
  const MealPart({
    required this.ingredientId,
    required this.grams,
    this.name,
    this.protein100,
    this.carbs100,
    this.fat100,
    this.fiber100,
    this.kcal100,
  });
  bool get isEmbedded => ingredientId.isEmpty;
  MealPart copyWith({
    String? ingredientId,
    double? grams,
    String? name,
    double? protein100,
    double? carbs100,
    double? fat100,
    double? fiber100,
    int? kcal100,
  }) => MealPart(
    ingredientId: ingredientId ?? this.ingredientId,
    grams: grams ?? this.grams,
    name: name ?? this.name,
    protein100: protein100 ?? this.protein100,
    carbs100: carbs100 ?? this.carbs100,
    fat100: fat100 ?? this.fat100,
    fiber100: fiber100 ?? this.fiber100,
    kcal100: kcal100 ?? this.kcal100,
  );
  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'grams': grams,
    'name': name,
    'protein100': protein100,
    'carbs100': carbs100,
    'fat100': fat100,
    'fiber100': fiber100,
    'kcal100': kcal100,
  };
  factory MealPart.fromJson(Map<String, dynamic> m) => MealPart(
    ingredientId: m['ingredientId'] ?? '',
    grams: (m['grams'] ?? 0).toDouble(),
    name: m['name'] as String?,
    protein100: (m['protein100'] != null) ? (m['protein100']).toDouble() : null,
    carbs100: (m['carbs100'] != null) ? (m['carbs100']).toDouble() : null,
    fat100: (m['fat100'] != null) ? (m['fat100']).toDouble() : null,
    fiber100: (m['fiber100'] != null) ? (m['fiber100']).toDouble() : null,
    kcal100: (m['kcal100'] != null) ? (m['kcal100']).toInt() : null,
  );
}

class MealDef {
  final String id;
  final String name;
  final List<MealPart> parts;
  final bool favorite;
  MealDef({
    this.id = '',
    required this.name,
    required this.parts,
    this.favorite = false,
  });
  MealDef copyWith({
    String? id,
    String? name,
    List<MealPart>? parts,
    bool? favorite,
  }) => MealDef(
    id: id ?? this.id,
    name: name ?? this.name,
    parts: parts ?? this.parts,
    favorite: favorite ?? this.favorite,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parts': parts.map((p) => p.toJson()).toList(),
    'favorite': favorite,
  };
  factory MealDef.fromJson(Map<String, dynamic> m) => MealDef(
    id: m['id'],
    name: m['name'],
    parts: ((m['parts'] ?? []) as List)
        .map((e) => MealPart.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    favorite: (m['favorite'] ?? false) as bool,
  );

  Macros totals(Map<String, Ingredient> ingredients) {
    double p = 0, c = 0, f = 0, fi = 0;
    int kcal = 0;
    for (final part in parts) {
      if (part.ingredientId.isNotEmpty) {
        final ing = ingredients[part.ingredientId];
        if (ing == null) continue;
        final factor = part.grams / 100.0;
        p += ing.protein100 * factor;
        c += ing.carbs100 * factor;
        f += ing.fat100 * factor;
        fi += ing.fiber100 * factor;
        kcal += (ing.kcal100 * factor).round();
      } else {
        // Embedded snapshot path
        final factor = part.grams / 100.0;
        final ep = (part.protein100 ?? 0) * factor;
        final ec = (part.carbs100 ?? 0) * factor;
        final ef = (part.fat100 ?? 0) * factor;
        final efi = (part.fiber100 ?? 0) * factor;
        final ekcal =
            ((part.kcal100 ?? ((ep * 4 + ec * 4 + ef * 9).round())) * factor)
                .round();
        p += ep;
        c += ec;
        f += ef;
        fi += efi;
        kcal += ekcal;
      }
    }
    return Macros(protein: p, carbs: c, fat: f, fiber: fi, kcal: kcal);
  }
}
