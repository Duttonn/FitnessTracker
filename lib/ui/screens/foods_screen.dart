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
enum _Sort { alphabetical, recentlyAdded, favorites }

class FoodsScreenState extends State<FoodsScreen> {
  _Filter filter = _Filter.all;
  _Sort sort = _Sort.alphabetical;
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
      ..sort((a, b) {
        switch (sort) {
          case _Sort.alphabetical:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case _Sort.recentlyAdded:
            final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          case _Sort.favorites:
            if (a.favorite == b.favorite) return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return a.favorite ? -1 : 1;
        }
      });
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
                  if (tab == FoodsTab.ingredients) ...[
                    const SizedBox(height: 10),
                    _SortRow(
                      value: sort,
                      onChanged: (s) => setState(() => sort = s),
                    ),
                  ],
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
          onQuickAdd: () => _showIngredientQuickAdd(context, ing),
          onToggleFavorite: () => context.read<AppState>().toggleIngredientFavorite(ing.id),
        );
      },
    );
  }


  void _showIngredientQuickAdd(BuildContext context, Ingredient ingredient) {
    final state = context.read<AppState>();
    final gramsCtl = TextEditingController(text: '100');
    Meal mealType = Meal.lunch;
    DateTime targetDate = DateTime.now();

    String dayLabel(DateTime dt) {
      final today = AppState.dayKeyFrom(DateTime.now());
      final tomorrow = AppState.dayKeyFrom(DateTime.now().add(const Duration(days: 1)));
      final key = AppState.dayKeyFrom(dt);
      if (key == today) return 'Today';
      if (key == tomorrow) return 'Tomorrow';
      return '${dt.month}/${dt.day}';
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: Text('Add ${ingredient.name}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gramsCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalTextInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Grams'),
                  onChanged: (_) => setSt(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Meal>(
                  value: mealType,
                  decoration: const InputDecoration(labelText: 'Meal'),
                  items: Meal.values.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m.name[0].toUpperCase() + m.name.substring(1)),
                  )).toList(),
                  onChanged: (v) => setSt(() => mealType = v ?? mealType),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(dayLabel(targetDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: c,
                        initialDate: targetDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setSt(() => targetDate = picked);
                    },
                    child: const Text('Change'),
                  ),
                ]),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final g = _parseNumLoose(gramsCtl.text);
                  final factor = g / 100.0;
                  final p = ingredient.protein100 * factor;
                  final ca = ingredient.carbs100 * factor;
                  final fa = ingredient.fat100 * factor;
                  return Text(
                    '${g.toStringAsFixed(0)}g → ${(ingredient.kcal100 * factor).round()} kcal  P ${p.toStringAsFixed(0)} C ${ca.toStringAsFixed(0)} F ${fa.toStringAsFixed(0)}',
                    style: Theme.of(c).textTheme.bodySmall,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final g = _parseNumLoose(gramsCtl.text);
                final factor = g / 100.0;
                final dayKey = AppState.dayKeyFrom(targetDate);
                state.addEntry(MacroEntry(
                  id: state.generateId(),
                  dayKey: dayKey,
                  createdAt: DateTime.now(),
                  meal: mealType,
                  protein: ingredient.protein100 * factor,
                  carbs: ingredient.carbs100 * factor,
                  fat: ingredient.fat100 * factor,
                  fiber: ingredient.fiber100 * factor,
                  kcal: (ingredient.kcal100 * factor).round(),
                  title: ingredient.name,
                ));
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added ${ingredient.name} to ${dayLabel(targetDate)}')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
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
                  String? lookupError;
                  try {
                    if (currentTab == FoodsTab.ingredients) {
                      fetched = await app.upsertIngredientFromBarcode(code);
                    } else {
                      fetched = await app.lookupIngredientByBarcode(code);
                    }
                  } catch (e) {
                    lookupError = e.toString();
                  }
                  if (!mounted) return;
                  Navigator.of(context).pop(); // dismiss loading
                  if (fetched == null) {
                    // Show error with option to enter manually
                    final doManual = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Product not found'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Barcode: $code'),
                            if (lookupError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                lookupError,
                                style: Theme.of(c).textTheme.bodySmall
                                    ?.copyWith(color: Colors.black45),
                              ),
                            ] else ...[
                              const SizedBox(height: 6),
                              const Text(
                                'This product isn\'t in the OpenFoodFacts database.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Text('Would you like to enter the nutritional info manually?'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Enter manually'),
                          ),
                        ],
                      ),
                    );
                    if (doManual == true && mounted) {
                      await _showAddIngredientSheet(
                        context,
                        initial: Ingredient(
                          id: '',
                          name: 'Product $code',
                          protein100: 0,
                          carbs100: 0,
                          fat100: 0,
                          fiber100: 0,
                          kcal100: 0,
                          barcode: code,
                          source: 'manual',
                        ),
                      );
                    }
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
    // When editing, go straight to the form. When adding new, show search first.
    if (initial == null) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => _AddIngredientSheet(
          state: context.read<AppState>(),
          onManualEntry: (query) => _showIngredientForm(
            context,
            initial: query.isEmpty
                ? null
                : Ingredient(
                    id: '',
                    name: query,
                    protein100: 0,
                    carbs100: 0,
                    fat100: 0,
                    fiber100: 0,
                    kcal100: 0,
                    source: 'manual',
                  ),
          ),
        ),
      );
    } else {
      await _showIngredientForm(context, initial: initial);
    }
  }

  Future<void> _showIngredientForm(BuildContext context, {Ingredient? initial}) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: initial?.name ?? '');
    final p = TextEditingController(text: (initial?.protein100 ?? 0).toString());
    final c = TextEditingController(text: (initial?.carbs100 ?? 0).toString());
    final f = TextEditingController(text: (initial?.fat100 ?? 0).toString());
    final fi = TextEditingController(text: (initial?.fiber100 ?? 0).toString());
    final portionRows = <List<TextEditingController>>[
      for (final pt in (initial?.portions ?? []))
        [
          TextEditingController(text: pt.label),
          TextEditingController(text: pt.grams % 1 == 0 ? pt.grams.toInt().toString() : pt.grams.toStringAsFixed(1)),
        ],
    ];
    int kcalFrom() {
      return (_parseNumLoose(p.text) * 4 + _parseNumLoose(c.text) * 4 + _parseNumLoose(f.text) * 9).round();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (cxt) => StatefulBuilder(
        builder: (ctx2, setSt) {
          final insets = MediaQuery.of(ctx2).viewInsets;
          return Padding(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      initial == null ? 'Add Ingredient' : 'Edit Ingredient',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: Text('Per 100g:', style: TextStyle(fontSize: 12, color: Colors.black54))),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextFormField(controller: p, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], decoration: const InputDecoration(labelText: 'Protein (g)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], decoration: const InputDecoration(labelText: 'Carbs (g)'))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(controller: f, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], decoration: const InputDecoration(labelText: 'Fat (g)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: fi, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], decoration: const InputDecoration(labelText: 'Fiber (g)'))),
                    ]),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: Listenable.merge([p, c, f]),
                      builder: (_, __) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Calories (auto): ${kcalFrom()} kcal', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('Portions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setSt(() {
                            portionRows.add([TextEditingController(), TextEditingController()]);
                          }),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    for (int i = 0; i < portionRows.length; i++) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: portionRows[i][0],
                              decoration: const InputDecoration(
                                labelText: 'Label (e.g. slice)',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: portionRows[i][1],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                              decoration: const InputDecoration(
                                labelText: 'g',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setSt(() {
                              portionRows[i][0].dispose();
                              portionRows[i][1].dispose();
                              portionRows.removeAt(i);
                            }),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final portions = [
                            for (final row in portionRows)
                              if (row[0].text.trim().isNotEmpty && _parseNumLoose(row[1].text) > 0)
                                Portion(label: row[0].text.trim(), grams: _parseNumLoose(row[1].text)),
                          ];
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
                            portions: portions,
                          );
                          if (initial == null) { state.addIngredient(ing); } else { state.updateIngredient(ing.copyWith(id: initial.id)); }
                          Navigator.pop(cxt);
                        },
                        child: Text(initial == null ? 'Save Ingredient' : 'Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    name.dispose(); p.dispose(); c.dispose(); f.dispose(); fi.dispose();
    for (final row in portionRows) { row[0].dispose(); row[1].dispose(); }
  }

  Future<MealPart?> _showIngredientPickerSheet(BuildContext context, AppState state) {
    return showModalBottomSheet<MealPart>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _IngredientPickerSheet(state: state),
    );
  }

  Future<MealPart?> _showInlineMacroDialog(BuildContext context) async {
    final nameCtl = TextEditingController();
    final p100 = TextEditingController(text: '0');
    final c100 = TextEditingController(text: '0');
    final f100 = TextEditingController(text: '0');
    final fi100 = TextEditingController(text: '0');
    final gramsCtl = TextEditingController(text: '100');

    int kcalAuto() {
      final pv = _parseNumLoose(p100.text);
      final cv = _parseNumLoose(c100.text);
      final fv = _parseNumLoose(f100.text);
      return (pv * 4 + cv * 4 + fv * 9).round();
    }

    final result = await showDialog<MealPart>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: const Text('Add by macros'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
                const SizedBox(height: 6),
                const Text('Per 100g:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _macroField('Protein', p100, setSt)),
                  const SizedBox(width: 8),
                  Expanded(child: _macroField('Carbs', c100, setSt)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _macroField('Fat', f100, setSt)),
                  const SizedBox(width: 8),
                  Expanded(child: _macroField('Fiber', fi100, setSt)),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: gramsCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalTextInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Grams to use'),
                  onChanged: (_) => setSt(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'Auto kcal/100g: ${kcalAuto()} kcal',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  c,
                  MealPart(
                    ingredientId: '',
                    grams: _parseNumLoose(gramsCtl.text),
                    name: nameCtl.text.trim().isEmpty ? 'Custom item' : nameCtl.text.trim(),
                    protein100: _parseNumLoose(p100.text),
                    carbs100: _parseNumLoose(c100.text),
                    fat100: _parseNumLoose(f100.text),
                    fiber100: _parseNumLoose(fi100.text),
                    kcal100: kcalAuto(),
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameCtl.dispose();
    p100.dispose(); c100.dispose(); f100.dispose(); fi100.dispose(); gramsCtl.dispose();
    return result;
  }

  Widget _macroField(String label, TextEditingController ctl, StateSetter setSt) =>
      TextField(
        controller: ctl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [DecimalTextInputFormatter()],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setSt(() {}),
      );

  Future<void> _showAddMealSheet(
    BuildContext context, {
    MealDef? initial,
    bool isDraft = false, // true when initial meal not yet persisted
  }) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: initial?.name ?? '');
    final parts = <MealPart>[...(initial?.parts ?? [])];
    final recurrenceDays = <int>{...?(initial?.recurrenceDays)};

    Macros totals() =>
        MealDef(id: 'tmp', name: 'tmp', parts: parts).totals(state.ingredients);

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
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final part = await _showIngredientPickerSheet(cxt, state);
                              if (part != null) setSt(() => parts.add(part));
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Ingredient'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final part = await _showInlineMacroDialog(cxt);
                              if (part != null) setSt(() => parts.add(part));
                            },
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('By macros'),
                          ),
                        ),
                      ],
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Repeat on', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final entry in const {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'}.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: recurrenceDays.contains(entry.key),
                            onSelected: (v) => setSt(() {
                              if (v) recurrenceDays.add(entry.key); else recurrenceDays.remove(entry.key);
                            }),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                      ],
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
                                      recurrenceDays: recurrenceDays.toList()..sort(),
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

class _SortRow extends StatelessWidget {
  final _Sort value;
  final ValueChanged<_Sort> onChanged;
  const _SortRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('Sort:', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      _SortChip(label: 'A–Z', selected: value == _Sort.alphabetical, onTap: () => onChanged(_Sort.alphabetical)),
      const SizedBox(width: 6),
      _SortChip(label: 'Recent', selected: value == _Sort.recentlyAdded, onTap: () => onChanged(_Sort.recentlyAdded)),
      const SizedBox(width: 6),
      _SortChip(label: '★ First', selected: value == _Sort.favorites, onTap: () => onChanged(_Sort.favorites)),
    ],
  );
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : Colors.black12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.black54,
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.kitchen_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing here yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add ingredients manually or scan a barcode',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


class _IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQuickAdd;
  final VoidCallback onToggleFavorite;
  const _IngredientCard({
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
    required this.onQuickAdd,
    required this.onToggleFavorite,
  });

  void showQuickAdd(BuildContext context) => onQuickAdd();

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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _MacroBadge('P', '${ingredient.protein100.toStringAsFixed(0)}g'),
                  _MacroBadge('C', '${ingredient.carbs100.toStringAsFixed(0)}g'),
                  _MacroBadge('F', '${ingredient.fat100.toStringAsFixed(0)}g'),
                  _MacroBadge('kcal', '${ingredient.kcal100}'),
                  const Text('/100g', style: TextStyle(color: Colors.black45)),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: ingredient.favorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: onToggleFavorite,
          icon: Icon(
            ingredient.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: ingredient.favorite ? Colors.amber : Colors.black38,
          ),
        ),
        IconButton(
          tooltip: 'Add to log',
          onPressed: onQuickAdd,
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
                  if (meal.recurrenceDays.isNotEmpty)
                    _RecurrenceBadge(days: meal.recurrenceDays),
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

class _RecurrenceBadge extends StatelessWidget {
  final List<int> days;
  const _RecurrenceBadge({required this.days});
  static const _labels = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};
  @override
  Widget build(BuildContext context) {
    final sorted = [...days]..sort();
    final text = sorted.map((d) => _labels[d] ?? '').join('');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _AddIngredientSheet extends StatefulWidget {
  final AppState state;
  final void Function(String query)? onManualEntry;
  const _AddIngredientSheet({required this.state, this.onManualEntry});
  @override
  State<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends State<_AddIngredientSheet> {
  String _query = '';
  List<Ingredient>? _offResults = [];
  bool _searching = false;
  DateTime _lastSearch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _search(String q) async {
    setState(() => _query = q);
    if (q.trim().length < 2) { setState(() { _offResults = []; }); return; }
    final now = DateTime.now();
    _lastSearch = now;
    await Future.delayed(const Duration(milliseconds: 500));
    if (_lastSearch != now || !mounted) return;
    setState(() { _searching = true; _offResults = []; });
    final results = await widget.state.searchIngredientsByName(q);
    if (!mounted) return;
    setState(() { _offResults = results; _searching = false; });
  }

  void _save(Ingredient ing) {
    widget.state.addIngredient(ing);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ing.name} added to your library')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Ingredient', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search OpenFoodFacts or enter manually…',
                    prefixIcon: _searching
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: .04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _search,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // Manual entry button always at top
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Enter macros manually', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_query.isNotEmpty ? 'Create "${_query}"' : 'Fill in nutrition info yourself', style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    final q = _query;
                    Navigator.pop(context);
                    widget.onManualEntry?.call(q);
                  },
                ),
                if (_offResults == null && !_searching) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 4),
                    child: Text('OpenFoodFacts results', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Search unavailable right now', style: TextStyle(fontSize: 12, color: Colors.black38)),
                  ),
                ],
                if (_offResults != null && _offResults!.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text('OpenFoodFacts results', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5)),
                  ),
                  for (final ing in _offResults!)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .07), borderRadius: BorderRadius.circular(10)),
                        child: const Center(child: Text('OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary))),
                      ),
                      title: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${ing.brand != null && ing.brand!.isNotEmpty ? "${ing.brand} · " : ""}P ${ing.protein100.toStringAsFixed(0)}  C ${ing.carbs100.toStringAsFixed(0)}  F ${ing.fat100.toStringAsFixed(0)}  ${ing.kcal100} kcal /100g',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      onTap: () => _save(ing),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientPickerSheet extends StatefulWidget {
  final AppState state;
  const _IngredientPickerSheet({required this.state});
  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  String _query = '';
  List<Ingredient>? _offResults = [];
  bool _searching = false;
  bool _hasSearched = false;

  // Debounce timer
  DateTime _lastSearch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _search(String q) async {
    setState(() { _query = q; });
    if (q.trim().length < 2) {
      setState(() { _offResults = []; _hasSearched = false; });
      return;
    }
    final now = DateTime.now();
    _lastSearch = now;
    await Future.delayed(const Duration(milliseconds: 500));
    if (_lastSearch != now) return; // debounce
    setState(() { _searching = true; _offResults = []; });
    final results = await widget.state.searchIngredientsByName(q);
    if (!mounted) return;
    setState(() { _offResults = results; _searching = false; _hasSearched = true; });
  }

  void _pick(Ingredient ing, {double grams = 100}) {
    if (ing.id.isNotEmpty) {
      Navigator.pop(context, MealPart(ingredientId: ing.id, grams: grams));
    } else {
      // OFF result not yet saved — save it first
      final savedId = widget.state.addIngredient(ing);
      Navigator.pop(context, MealPart(ingredientId: savedId, grams: grams));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.state.ingredients.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final local = _query.isEmpty
        ? all
        : all.where((i) => i.name.toLowerCase().contains(_query.toLowerCase())).toList();

    // Remove OFF results already in local library (same barcode or name match)
    final localNames = local.map((i) => i.name.toLowerCase()).toSet();
    final offFiltered = (_offResults ?? []).where((r) => !localNames.contains(r.name.toLowerCase())).toList();
    final offUnavailable = _offResults == null && _hasSearched && !_searching;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search foods (local + OpenFoodFacts)…',
                        prefixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: .04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: _search,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  // Local results
                  if (local.isNotEmpty) ...[
                    if (_query.isNotEmpty || offFiltered.isNotEmpty)
                      _SectionHeader('My Ingredients (${local.length})'),
                    for (final ing in local)
                      _IngredientTile(
                        ingredient: ing,
                        onTap: (g) => _pick(ing, grams: g),
                      ),
                  ],
                  // OFF results
                  if (offUnavailable) ...[
                    _SectionHeader('OpenFoodFacts results'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Search unavailable right now', style: TextStyle(fontSize: 12, color: Colors.black38)),
                    ),
                  ] else if (offFiltered.isNotEmpty) ...[
                    _SectionHeader('OpenFoodFacts results'),
                    for (final ing in offFiltered)
                      _IngredientTile(
                        ingredient: ing,
                        isRemote: true,
                        onTap: (g) => _pick(ing, grams: g),
                      ),
                  ],
                  if (local.isEmpty && _hasSearched && offFiltered.isEmpty && !offUnavailable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No results for "$_query"',
                          style: const TextStyle(color: Colors.black45),
                        ),
                      ),
                    ),
                  if (local.isEmpty && !_hasSearched && _query.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Type to search foods in OpenFoodFacts\nor your local library',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5),
    ),
  );
}

class _IngredientTile extends StatefulWidget {
  final Ingredient ingredient;
  final bool isRemote;
  final void Function(double grams) onTap;
  const _IngredientTile({required this.ingredient, required this.onTap, this.isRemote = false});
  @override
  State<_IngredientTile> createState() => _IngredientTileState();
}

class _IngredientTileState extends State<_IngredientTile> {
  final _amountCtl = TextEditingController(text: '100');
  Portion? _selectedPortion;

  @override
  void dispose() { _amountCtl.dispose(); super.dispose(); }

  double _resolvedGrams() {
    final amount = _parseNumLoose(_amountCtl.text);
    if (_selectedPortion != null) return (amount * _selectedPortion!.grams).clamp(1.0, 9999.0);
    return amount.clamp(1.0, 9999.0);
  }

  @override
  Widget build(BuildContext context) {
    final ing = widget.ingredient;
    final hasPortion = ing.portions.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 0,
      color: widget.isRemote
          ? AppColors.primary.withValues(alpha: .04)
          : Colors.black.withValues(alpha: .03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onTap(_resolvedGrams()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ing.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isRemote)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                        if (ing.brand != null && ing.brand!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(ing.brand!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'P ${ing.protein100.toStringAsFixed(0)}  C ${ing.carbs100.toStringAsFixed(0)}  F ${ing.fat100.toStringAsFixed(0)}  ${ing.kcal100} kcal /100g',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: hasPortion ? 52 : 64,
                child: TextField(
                  controller: _amountCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalTextInputFormatter()],
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: _selectedPortion == null ? 'g' : '×',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => widget.onTap(_resolvedGrams()),
                ),
              ),
              if (hasPortion) ...[
                const SizedBox(width: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<Portion?>(
                    value: _selectedPortion,
                    isDense: true,
                    items: [
                      const DropdownMenuItem<Portion?>(value: null, child: Text('g', style: TextStyle(fontSize: 13))),
                      for (final pt in ing.portions)
                        DropdownMenuItem<Portion?>(
                          value: pt,
                          child: Text(pt.label, style: const TextStyle(fontSize: 13)),
                        ),
                    ],
                    onChanged: (pt) => setState(() => _selectedPortion = pt),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.black26, size: 20),
            ],
          ),
        ),
      ),
    );
  }
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
  Portion? _selectedPortion;

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

  double _currentGrams() {
    final val = _parseNumLoose(gramsCtrl.text);
    if (_selectedPortion != null && _selectedPortion!.grams > 0) {
      return val * _selectedPortion!.grams;
    }
    return val;
  }

  void _changeUnit(Portion? newPortion) {
    final currentGrams = _currentGrams();
    setState(() {
      _selectedPortion = newPortion;
      if (newPortion != null && newPortion.grams > 0) {
        final qty = currentGrams / newPortion.grams;
        gramsCtrl.text = qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(1);
      } else {
        gramsCtrl.text = currentGrams.toStringAsFixed(0);
      }
    });
  }

  void _emit() {
    widget.onChanged(
      widget.part.copyWith(ingredientId: ingredientId, grams: _currentGrams()),
    );
  }

  @override
  Widget build(BuildContext context) {
    Ingredient? ing;
    for (final i in widget.ingredients) {
      if (i.id == ingredientId) { ing = i; break; }
    }
    final portions = ing?.portions ?? const <Portion>[];

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
                setState(() {
                  ingredientId = id;
                  _selectedPortion = null;
                });
                _emit();
              }
            },
            decoration: const InputDecoration(labelText: 'Ingredient'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: portions.isEmpty ? 90 : 70,
          child: TextFormField(
            controller: gramsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textAlign: TextAlign.right,
            decoration: InputDecoration(labelText: _selectedPortion == null ? 'g' : '×'),
            onChanged: (_) => _emit(),
          ),
        ),
        if (portions.isNotEmpty) ...[
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<Portion?>(
              value: _selectedPortion,
              isDense: true,
              items: [
                const DropdownMenuItem<Portion?>(value: null, child: Text('g', style: TextStyle(fontSize: 13))),
                for (final pt in portions)
                  DropdownMenuItem<Portion?>(
                    value: pt,
                    child: Text(pt.label, style: const TextStyle(fontSize: 13)),
                  ),
              ],
              onChanged: _changeUnit,
            ),
          ),
        ],
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
