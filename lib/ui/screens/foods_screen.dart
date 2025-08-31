import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/models/ingredient.dart';
import 'package:flutter_fitness_app/models/meal_def.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fitness_app/ui/layout.dart';
import 'package:flutter_fitness_app/ui/widgets/animated_center_fab.dart';
import 'package:flutter_fitness_app/ui/widgets/vision_nav_bar.dart'; // import full to ensure constant is visible
import 'barcode_scan_screen.dart';

class DecimalTextInputFormatter extends TextInputFormatter {
  final bool allowNegative;
  DecimalTextInputFormatter({this.allowNegative = false});
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final reg = RegExp(allowNegative ? r'^-?[0-9.,]*$' : r'^[0-9.,]*$');
    if (!reg.hasMatch(raw)) return oldValue;
    final normalized = raw.replaceAll(',', '.');
    if (normalized == newValue.text) return newValue;
    return newValue.copyWith(text: normalized, selection: newValue.selection);
  }
}

double _parseNumLoose(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

enum ScanTarget { ingredient, meal }

class FoodsScreen extends StatefulWidget {
  final void Function([Meal?])? openQuickAdd; // retained but unused here
  final int? initialTab; // 0 = ingredients, 1 = meals
  const FoodsScreen({super.key, this.openQuickAdd, this.initialTab});
  @override
  State<FoodsScreen> createState() => FoodsScreenState();
}

enum _Filter { all, favorites, highProtein }

class FoodsScreenState extends State<FoodsScreen> {
  _Filter filter = _Filter.all;
  String query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 1) {
      // set global tab to meals on first open if requested
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppState>().setFoodsTab(FoodsTab.meals);
      });
    }
  }

  void setTabIndex(int idx) {
    final app = context.read<AppState>();
    final target = idx == 1 ? FoodsTab.meals : FoodsTab.ingredients;
    app.setFoodsTab(target);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tab = state.foodsTab; // global source of truth
    final ingredients = state.ingredients.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final meals = state.meals.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final filteredIngredients = ingredients.where((i) {
      if (query.isNotEmpty &&
          !i.name.toLowerCase().contains(query.toLowerCase()))
        return false;
      switch (filter) {
        case _Filter.all:
          return true;
        case _Filter.favorites:
          return i.favorite;
        case _Filter.highProtein:
          return i.protein100 >= 20;
      }
    }).toList();

    final filteredMeals = meals.where((m) {
      if (query.isNotEmpty &&
          !m.name.toLowerCase().contains(query.toLowerCase()))
        return false;
      switch (filter) {
        case _Filter.all:
          return true;
        case _Filter.favorites:
          return m.favorite;
        case _Filter.highProtein:
          final t = m.totals(state.ingredients);
          final sum = (t.protein + t.carbs + t.fat);
          return sum == 0 ? false : (t.protein / sum) >= 0.3;
      }
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      floatingActionButton: null,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomReserve(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchField(onChanged: (v) => setState(() => query = v)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: filter == _Filter.all,
                        onTap: () => setState(() => filter = _Filter.all),
                      ),
                      _FilterChip(
                        label: 'Favorites',
                        selected: filter == _Filter.favorites,
                        onTap: () => setState(() => filter = _Filter.favorites),
                      ),
                      _FilterChip(
                        label: 'High Protein',
                        selected: filter == _Filter.highProtein,
                        onTap: () =>
                            setState(() => filter = _Filter.highProtein),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TabSwitch(
                    value: tab,
                    onChanged: (t) => context.read<AppState>().setFoodsTab(t),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: tab == FoodsTab.ingredients
                        ? _ingredientsList(filteredIngredients)
                        : _mealsList(filteredMeals, state),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCenterFab(
            onPressed: () => _openCreateChoice(context),
            bottomOffset: kVisionNavBarHeight, // position above nav bar
            size: 64,
          ),
        ],
      ),
    );
  }

  Widget _ingredientsList(List<Ingredient> data) {
    if (data.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: EdgeInsets.only(bottom: bottomReserve(context)),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final ing = data[i];
        return _IngredientCard(
          ingredient: ing,
          onEdit: () => _showAddIngredientSheet(context, initial: ing),
          onDelete: () => context.read<AppState>().removeIngredient(ing.id),
        );
      },
    );
  }

  Widget _mealsList(List<MealDef> data, AppState state) {
    if (data.isEmpty) return const _EmptyState();
    return ListView.separated(
      padding: EdgeInsets.only(bottom: bottomReserve(context)),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final meal = data[i];
        final totals = meal.totals(state.ingredients);
        return _MealCard(
          meal: meal,
          totals: totals,
          onEdit: () => _showAddMealSheet(context, initial: meal),
          onDelete: () => context.read<AppState>().removeMeal(meal.id),
        );
      },
    );
  }

  // Removed unused _openAddMealWizard helper (scan flow now builds meal inline)

  void _openCreateChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.qr_code_scanner,
                label: 'Scan Barcode',
                onTap: () async {
                  Navigator.pop(c);
                  final code = await BarcodeScanScreen.pick(context);
                  if (code == null || !mounted) return;
                  // Show loading while fetching from OFF or cache
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );
                  final app = context.read<AppState>();
                  final currentTab = app.foodsTab; // determine active tab at action time
                  Ingredient? fetched;
                  try {
                    if (currentTab == FoodsTab.ingredients) {
                      // Persisting path
                      fetched = await app.upsertIngredientFromBarcode(code);
                    } else {
                      // Non-persisting path. Try local first then OFF without saving.
                      fetched = await app.lookupIngredientByBarcode(code);
                    }
                  } catch (_) {}
                  if (!mounted) return;
                  Navigator.of(context).pop(); // dismiss loading
                  if (fetched == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Product not found.')),
                    );
                    return;
                  }
                  if (currentTab == FoodsTab.ingredients) {
                    await _showAddIngredientSheet(context, initial: fetched);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${fetched.name}')),
                    );
                  } else {
                    // Build meal draft. Use ingredientId only if existing persisted ingredient (id not empty & present in state)
                    final persisted =
                        fetched.id.isNotEmpty &&
                        app.ingredients.containsKey(fetched.id);
                    final part = persisted
                        ? MealPart(ingredientId: fetched.id, grams: 100)
                        : MealPart(
                            ingredientId: '',
                            grams: 100,
                            name: fetched.name,
                            protein100: fetched.protein100,
                            carbs100: fetched.carbs100,
                            fat100: fetched.fat100,
                            fiber100: fetched.fiber100,
                            kcal100: fetched.kcal100,
                          );
                    final meal = MealDef(
                      id: AppState.newId(),
                      name: fetched.name,
                      parts: [part],
                    );
                    await _showAddMealSheet(
                      context,
                      initial: meal,
                      isDraft: true,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${fetched.name} to meal draft'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.kitchen,
                label: 'Add Ingredient',
                onTap: () {
                  Navigator.pop(c);
                  _showAddIngredientSheet(context);
                },
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.restaurant_menu,
                label: 'Add Meal',
                onTap: () {
                  Navigator.pop(c);
                  _showAddMealSheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Removed unused _askForGrams helper (no longer used)

  Future<void> _showAddIngredientSheet(
    BuildContext context, {
    Ingredient? initial,
  }) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: initial?.name ?? '');
    final p = TextEditingController(
      text: (initial?.protein100 ?? 0).toString(),
    );
    final c = TextEditingController(text: (initial?.carbs100 ?? 0).toString());
    final f = TextEditingController(text: (initial?.fat100 ?? 0).toString());
    final fi = TextEditingController(text: (initial?.fiber100 ?? 0).toString());
    int kcalFrom() {
      final pv = _parseNumLoose(p.text);
      final cv = _parseNumLoose(c.text);
      final fv = _parseNumLoose(f.text);
      return (pv * 4 + cv * 4 + fv * 9).round();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (cxt) {
        final insets = MediaQuery.of(cxt).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: p,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Protein (g/100g)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: c,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Carbs (g/100g)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: f,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Fat (g/100g)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: fi,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Fiber (g/100g)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (initial?.barcode != null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Barcode',
                        hintText: initial!.barcode,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: Listenable.merge([p, c, f]),
                    builder: (_, __) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Calories (auto): ${kcalFrom()} kcal',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final ing = Ingredient(
                          id: initial?.id ?? '',
                          name: name.text.trim(),
                          protein100: _parseNumLoose(p.text),
                          carbs100: _parseNumLoose(c.text),
                          fat100: _parseNumLoose(f.text),
                          fiber100: _parseNumLoose(fi.text),
                          kcal100: kcalFrom(),
                          favorite: initial?.favorite ?? false,
                          barcode: initial?.barcode,
                          brand: initial?.brand,
                          imageUrl: initial?.imageUrl,
                          source: initial?.source ?? 'manual',
                          lastFetchedAt: initial?.lastFetchedAt,
                        );
                        if (initial == null) {
                          state.addIngredient(ing);
                        } else {
                          state.updateIngredient(ing.copyWith(id: initial.id));
                        }
                        Navigator.pop(cxt);
                      },
                      child: Text(
                        initial == null ? 'Save Ingredient' : 'Save Changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddMealSheet(
    BuildContext context, {
    MealDef? initial,
    bool isDraft = false, // true when initial meal not yet persisted
  }) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: initial?.name ?? '');
    final parts = <MealPart>[...(initial?.parts ?? [])];

    Macros totals() =>
        MealDef(id: 'tmp', name: 'tmp', parts: parts).totals(state.ingredients);

    void addPart() {
      final first = state.ingredients.values.isEmpty
          ? null
          : state.ingredients.values.first;
      if (first == null) return;
      parts.add(MealPart(ingredientId: first.id, grams: 100));
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (cxt) {
        final insets = MediaQuery.of(cxt).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: StatefulBuilder(
            builder: (c, setSt) => SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Meal name'),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < parts.length; i++) ...[
                      _MealPartRow(
                        key: ValueKey('part_$i'),
                        part: parts[i],
                        ingredients: state.ingredients.values.toList(),
                        onChanged: (np) => setSt(() => parts[i] = np),
                        onRemove: () => setSt(() => parts.removeAt(i)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextButton.icon(
                      onPressed: () {
                        setSt(addPart);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Ingredient'),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (_) {
                        final t = totals();
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 10,
                            children: [
                              _MacroBadge(
                                'P',
                                '${t.protein.toStringAsFixed(0)}g',
                              ),
                              _MacroBadge(
                                'C',
                                '${t.carbs.toStringAsFixed(0)}g',
                              ),
                              _MacroBadge('F', '${t.fat.toStringAsFixed(0)}g'),
                              _MacroBadge(
                                'Fi',
                                '${t.fiber.toStringAsFixed(0)}g',
                              ),
                              _MacroBadge('kcal', '${t.kcal}'),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(cxt),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: parts.isEmpty
                                ? null
                                : () {
                                    final meal = MealDef(
                                      id: initial?.id ?? '',
                                      name: name.text.trim(),
                                      parts: parts.toList(),
                                      favorite: initial?.favorite ?? false,
                                    );
                                    final exists =
                                        meal.id.isNotEmpty &&
                                        state.meals.containsKey(meal.id);
                                    if (initial == null || isDraft || !exists) {
                                      state.addMeal(meal);
                                    } else {
                                      state.updateMeal(
                                        meal.copyWith(id: initial.id),
                                      );
                                    }
                                    Navigator.pop(cxt);
                                  },
                            child: Text(
                              (initial == null || isDraft)
                                  ? 'Save Meal'
                                  : 'Save Changes',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: 'Search foods',
      prefixIcon: const Icon(Icons.search),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.black12,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(46),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.check, size: 16, color: Colors.white),
              ),
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  final FoodsTab value;
  final ValueChanged<FoodsTab> onChanged;
  const _TabSwitch({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _TabPill(
        label: 'Ingredients',
        selected: value == FoodsTab.ingredients,
        onTap: () => onChanged(FoodsTab.ingredients),
      ),
      const SizedBox(width: 8),
      _TabPill(
        label: 'Meals',
        selected: value == FoodsTab.meals,
        onTap: () => onChanged(FoodsTab.meals),
      ),
    ],
  );
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : Colors.black87,
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(child: Text('No foods'));
}

class _IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _IngredientCard({
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  void _quickAdd(BuildContext context) {
    final state = context.read<AppState>();
    final gramsCtl = TextEditingController(text: '100');
    Meal mealType = Meal.lunch;
    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setSt) => AlertDialog(
            title: Text('Add ${ingredient.name}'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: gramsCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [DecimalTextInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Grams'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Meal>(
                    value: mealType,
                    decoration: const InputDecoration(labelText: 'Meal'),
                    items: Meal.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.name[0].toUpperCase() + m.name.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => mealType = v ?? mealType),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (_) {
                      final g = _parseNumLoose(gramsCtl.text);
                      final factor = g / 100.0;
                      final p = ingredient.protein100 * factor;
                      final ca = ingredient.carbs100 * factor;
                      final fa = ingredient.fat100 * factor;
                      final fi = ingredient.fiber100 * factor;
                      final kcal = (ingredient.kcal100 * factor).round();
                      return Text(
                        '${g.toStringAsFixed(0)}g => ${kcal} kcal  P ${p.toStringAsFixed(0)} C ${ca.toStringAsFixed(0)} F ${fa.toStringAsFixed(0)} Fi ${fi.toStringAsFixed(0)}',
                        style: Theme.of(c).textTheme.bodySmall,
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final g = _parseNumLoose(gramsCtl.text);
                  final factor = g / 100.0;
                  final p = ingredient.protein100 * factor;
                  final ca = ingredient.carbs100 * factor;
                  final fa = ingredient.fat100 * factor;
                  final fi = ingredient.fiber100 * factor;
                  final kcal = (ingredient.kcal100 * factor).round();
                  final dayKey = AppState.dayKeyFrom(DateTime.now());
                  state.addEntry(
                    MacroEntry(
                      id: state.generateId(),
                      dayKey: dayKey,
                      createdAt: DateTime.now(),
                      meal: mealType,
                      protein: p,
                      carbs: ca,
                      fat: fa,
                      fiber: fi,
                      kcal: kcal,
                      title: ingredient.name,
                    ),
                  );
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added ${ingredient.name}')),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: appCardDecoration(),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.kitchen, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ingredient.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _MacroBadge(
                    'P',
                    '${ingredient.protein100.toStringAsFixed(0)}g',
                  ),
                  _MacroBadge(
                    'C',
                    '${ingredient.carbs100.toStringAsFixed(0)}g',
                  ),
                  _MacroBadge('F', '${ingredient.fat100.toStringAsFixed(0)}g'),
                  _MacroBadge(
                    'Fi',
                    '${ingredient.fiber100.toStringAsFixed(0)}g',
                  ),
                  _MacroBadge('kcal', '${ingredient.kcal100}'),
                  const Text('/100g', style: TextStyle(color: Colors.black45)),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _quickAdd(context),
          icon: const Icon(Icons.playlist_add),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (c) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
  );
}

class _MealCard extends StatelessWidget {
  final MealDef meal;
  final Macros totals;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MealCard({
    required this.meal,
    required this.totals,
    required this.onEdit,
    required this.onDelete,
  });
  void _quickAdd(BuildContext context) {
    final state = context.read<AppState>();
    final mealTotals = totals;
    final multCtl = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (c) {
        Meal mealType = Meal.lunch;
        return StatefulBuilder(
          builder: (c, setSt) => AlertDialog(
            title: Text('Add ${meal.name}'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: multCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [DecimalTextInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Portions'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Meal>(
                    initialValue: mealType,
                    decoration: const InputDecoration(labelText: 'Meal'),
                    items: Meal.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.name[0].toUpperCase() + m.name.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSt(() => mealType = v ?? mealType),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Base: ${mealTotals.kcal} kcal  P ${mealTotals.protein.toStringAsFixed(0)} C ${mealTotals.carbs.toStringAsFixed(0)} F ${mealTotals.fat.toStringAsFixed(0)} Fi ${mealTotals.fiber.toStringAsFixed(0)}',
                    style: Theme.of(c).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final mult = _parseNumLoose(multCtl.text);
                  final p = mealTotals.protein * mult;
                  final ca = mealTotals.carbs * mult;
                  final fa = mealTotals.fat * mult;
                  final fi = mealTotals.fiber * mult;
                  final kcal = (p * 4 + ca * 4 + fa * 9).round();
                  final dayKey = AppState.dayKeyFrom(DateTime.now());
                  state.addEntry(
                    MacroEntry(
                      id: state.generateId(),
                      dayKey: dayKey,
                      createdAt: DateTime.now(),
                      meal: mealType,
                      protein: p,
                      carbs: ca,
                      fat: fa,
                      fiber: fi,
                      kcal: kcal,
                      title: meal.name,
                    ),
                  );
                  Navigator.pop(c);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Added ${meal.name}')));
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: appCardDecoration(),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant_menu, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _MacroBadge('P', '${totals.protein.toStringAsFixed(0)}g'),
                  _MacroBadge('C', '${totals.carbs.toStringAsFixed(0)}g'),
                  _MacroBadge('F', '${totals.fat.toStringAsFixed(0)}g'),
                  _MacroBadge('Fi', '${totals.fiber.toStringAsFixed(0)}g'),
                  _MacroBadge('kcal', '${totals.kcal}'),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _quickAdd(context),
          icon: const Icon(Icons.playlist_add),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (c) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
  );
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final String value;
  const _MacroBadge(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$label $value',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _MealPartRow extends StatefulWidget {
  final MealPart part;
  final List<Ingredient> ingredients;
  final ValueChanged<MealPart> onChanged;
  final VoidCallback onRemove;
  const _MealPartRow({
    super.key,
    required this.part,
    required this.ingredients,
    required this.onChanged,
    required this.onRemove,
  });
  @override
  State<_MealPartRow> createState() => _MealPartRowState();
}

class _MealPartRowState extends State<_MealPartRow> {
  late TextEditingController gramsCtrl;
  late String ingredientId;
  @override
  void initState() {
    super.initState();
    ingredientId = widget.part.ingredientId;
    gramsCtrl = TextEditingController(
      text: widget.part.grams == 0 ? '' : widget.part.grams.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    gramsCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final grams = _parseNumLoose(gramsCtrl.text);
    widget.onChanged(
      widget.part.copyWith(ingredientId: ingredientId, grams: grams),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.part.isEmbedded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.part.name ?? 'Scanned item',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '/100g  P ${((widget.part.protein100) ?? 0).toStringAsFixed(0)}  C ${((widget.part.carbs100) ?? 0).toStringAsFixed(0)}  F ${((widget.part.fat100) ?? 0).toStringAsFixed(0)}  Fi ${((widget.part.fiber100) ?? 0).toStringAsFixed(0)}  ${widget.part.kcal100 ?? (((widget.part.protein100 ?? 0) * 4 + (widget.part.carbs100 ?? 0) * 4 + (widget.part.fat100 ?? 0) * 9).round())} kcal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: gramsCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'g'),
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.onRemove,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: ingredientId.isEmpty ? null : ingredientId,
            items: [
              for (final ing in widget.ingredients)
                DropdownMenuItem(
                  value: ing.id,
                  child: Text(ing.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              if (id != null) {
                setState(() => ingredientId = id);
                _emit();
              }
            },
            decoration: const InputDecoration(labelText: 'Ingredient'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextFormField(
            controller: gramsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'g'),
            onChanged: (_) => _emit(),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.delete_outline),
          onPressed: widget.onRemove,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withAlpha(30),
      child: Icon(icon, color: AppColors.primary),
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    tileColor: Colors.white,
  );
}
