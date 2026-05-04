import 'ingredient.dart';

// Nutritional values are per 100g, approximate averages
final kSeedIngredients = <Ingredient>[
  // Proteins
  Ingredient(id: 'seed_chicken_breast', name: 'Chicken Breast', protein100: 31, carbs100: 0, fat100: 3.6, fiber100: 0, kcal100: 165, source: 'seed'),
  Ingredient(id: 'seed_chicken_thigh', name: 'Chicken Thigh', protein100: 26, carbs100: 0, fat100: 9, fiber100: 0, kcal100: 209, source: 'seed'),
  Ingredient(id: 'seed_ground_beef', name: 'Ground Beef (5% fat)', protein100: 26, carbs100: 0, fat100: 5, fiber100: 0, kcal100: 149, source: 'seed'),
  Ingredient(id: 'seed_salmon', name: 'Salmon', protein100: 25, carbs100: 0, fat100: 13, fiber100: 0, kcal100: 208, source: 'seed'),
  Ingredient(id: 'seed_tuna_canned', name: 'Tuna (canned in water)', protein100: 26, carbs100: 0, fat100: 1, fiber100: 0, kcal100: 116, source: 'seed'),
  Ingredient(id: 'seed_eggs', name: 'Eggs (whole)', protein100: 13, carbs100: 1.1, fat100: 11, fiber100: 0, kcal100: 155, source: 'seed'),
  Ingredient(id: 'seed_egg_whites', name: 'Egg Whites', protein100: 11, carbs100: 0.7, fat100: 0.2, fiber100: 0, kcal100: 52, source: 'seed'),
  Ingredient(id: 'seed_cottage_cheese', name: 'Cottage Cheese (low-fat)', protein100: 11, carbs100: 3.4, fat100: 1, fiber100: 0, kcal100: 72, source: 'seed'),
  Ingredient(id: 'seed_greek_yogurt', name: 'Greek Yogurt (0%)', protein100: 10, carbs100: 4, fat100: 0.4, fiber100: 0, kcal100: 59, source: 'seed'),
  Ingredient(id: 'seed_whey_protein', name: 'Whey Protein Powder', protein100: 80, carbs100: 8, fat100: 4, fiber100: 0, kcal100: 390, source: 'seed'),

  // Carbs
  Ingredient(id: 'seed_white_rice', name: 'White Rice (cooked)', protein100: 2.7, carbs100: 28, fat100: 0.3, fiber100: 0.4, kcal100: 130, source: 'seed'),
  Ingredient(id: 'seed_brown_rice', name: 'Brown Rice (cooked)', protein100: 2.6, carbs100: 23, fat100: 0.9, fiber100: 1.8, kcal100: 111, source: 'seed'),
  Ingredient(id: 'seed_pasta', name: 'Pasta (cooked)', protein100: 5, carbs100: 31, fat100: 1.1, fiber100: 1.8, kcal100: 158, source: 'seed'),
  Ingredient(id: 'seed_oats', name: 'Oats (dry)', protein100: 13, carbs100: 67, fat100: 7, fiber100: 10, kcal100: 389, source: 'seed'),
  Ingredient(id: 'seed_sweet_potato', name: 'Sweet Potato', protein100: 1.6, carbs100: 20, fat100: 0.1, fiber100: 3, kcal100: 86, source: 'seed'),
  Ingredient(id: 'seed_bread_whole_wheat', name: 'Bread (whole wheat)', protein100: 9, carbs100: 41, fat100: 4, fiber100: 7, kcal100: 247, source: 'seed'),
  Ingredient(id: 'seed_potato', name: 'Potato (boiled)', protein100: 2, carbs100: 17, fat100: 0.1, fiber100: 1.8, kcal100: 77, source: 'seed'),

  // Vegetables
  Ingredient(id: 'seed_broccoli', name: 'Broccoli', protein100: 2.8, carbs100: 7, fat100: 0.4, fiber100: 2.6, kcal100: 34, source: 'seed'),
  Ingredient(id: 'seed_spinach', name: 'Spinach', protein100: 2.9, carbs100: 3.6, fat100: 0.4, fiber100: 2.2, kcal100: 23, source: 'seed'),
  Ingredient(id: 'seed_mixed_veggies', name: 'Mixed Vegetables', protein100: 2, carbs100: 8, fat100: 0.2, fiber100: 3, kcal100: 40, source: 'seed'),
  Ingredient(id: 'seed_green_beans', name: 'Green Beans', protein100: 1.8, carbs100: 7, fat100: 0.1, fiber100: 2.7, kcal100: 31, source: 'seed'),

  // Fats & dairy
  Ingredient(id: 'seed_olive_oil', name: 'Olive Oil', protein100: 0, carbs100: 0, fat100: 100, fiber100: 0, kcal100: 884, source: 'seed'),
  Ingredient(id: 'seed_avocado', name: 'Avocado', protein100: 2, carbs100: 9, fat100: 15, fiber100: 6.7, kcal100: 160, source: 'seed'),
  Ingredient(id: 'seed_almonds', name: 'Almonds', protein100: 21, carbs100: 22, fat100: 49, fiber100: 12, kcal100: 579, source: 'seed'),
  Ingredient(id: 'seed_milk', name: 'Milk (whole)', protein100: 3.4, carbs100: 4.8, fat100: 3.7, fiber100: 0, kcal100: 61, source: 'seed'),
];
