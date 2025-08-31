import 'package:flutter/foundation.dart';

@immutable
class Ingredient {
  final String id;
  final String name;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double fiber100;
  final int kcal100;
  final bool favorite;
  // New metadata
  final String? barcode; // EAN/UPC
  final String? brand;
  final String? imageUrl;
  final String source; // 'manual' | 'openfoodfacts'
  final DateTime? lastFetchedAt;
  final DateTime? updatedAt; // last local modification (for sync)
  const Ingredient({
    this.id = '',
    required this.name,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.fiber100,
    required this.kcal100,
    this.favorite = false,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.source = 'manual',
    this.lastFetchedAt,
    this.updatedAt,
  });
  Ingredient copyWith({
    String? id,
    String? name,
    double? protein100,
    double? carbs100,
    double? fat100,
    double? fiber100,
    int? kcal100,
    bool? favorite,
    String? barcode,
    String? brand,
    String? imageUrl,
    String? source,
    DateTime? lastFetchedAt,
    DateTime? updatedAt,
  }) => Ingredient(
    id: id ?? this.id,
    name: name ?? this.name,
    protein100: protein100 ?? this.protein100,
    carbs100: carbs100 ?? this.carbs100,
    fat100: fat100 ?? this.fat100,
    fiber100: fiber100 ?? this.fiber100,
    kcal100: kcal100 ?? this.kcal100,
    favorite: favorite ?? this.favorite,
    barcode: barcode ?? this.barcode,
    brand: brand ?? this.brand,
    imageUrl: imageUrl ?? this.imageUrl,
    source: source ?? this.source,
    lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protein100': protein100,
    'carbs100': carbs100,
    'fat100': fat100,
    'fiber100': fiber100,
    'kcal100': kcal100,
    'favorite': favorite,
    'barcode': barcode,
    'brand': brand,
    'imageUrl': imageUrl,
    'source': source,
    'lastFetchedAt': lastFetchedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  factory Ingredient.fromJson(Map<String, dynamic> m) => Ingredient(
    id: m['id'] ?? '',
    name: m['name'] ?? 'Unknown',
    protein100: (m['protein100'] ?? 0).toDouble(),
    carbs100: (m['carbs100'] ?? 0).toDouble(),
    fat100: (m['fat100'] ?? 0).toDouble(),
    fiber100: (m['fiber100'] ?? 0).toDouble(),
    kcal100: (m['kcal100'] ?? 0).toInt(),
    favorite: (m['favorite'] ?? false) as bool,
    barcode: m['barcode'] as String?,
    brand: m['brand'] as String?,
    imageUrl: m['imageUrl'] as String?,
    source: (m['source'] ?? 'manual') as String,
    lastFetchedAt: m['lastFetchedAt'] != null
        ? DateTime.tryParse(m['lastFetchedAt'])
        : null,
    updatedAt: m['updatedAt'] != null
        ? DateTime.tryParse(m['updatedAt'])
        : null,
  );
  // Convenience macro scaling
  Macros forGrams(double grams) {
    final factor = grams / 100.0;
    return Macros(
      protein: protein100 * factor,
      carbs: carbs100 * factor,
      fat: fat100 * factor,
      fiber: fiber100 * factor,
      kcal: (kcal100 * factor).round(),
    );
  }
}

class Macros {
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int kcal;
  const Macros({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.kcal,
  });
  static const zero = Macros(protein: 0, carbs: 0, fat: 0, fiber: 0, kcal: 0);
  Macros operator +(Macros o) => Macros(
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
    fiber: fiber + o.fiber,
    kcal: kcal + o.kcal,
  );
}
