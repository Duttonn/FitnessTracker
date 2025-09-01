import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// removed provider import
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'package:flutter_fitness_app/ui/widgets/segmented_meal_selector.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuickAddSheet extends StatefulWidget {
  final Meal initialMeal;
  final AppState appState; // injected
  const QuickAddSheet({
    super.key,
    required this.initialMeal,
    required this.appState,
  });
  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  late Meal meal = widget.initialMeal;
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _title = TextEditingController();

  double _parse(TextEditingController c) => double.tryParse(c.text) ?? 0;

  int get estimatedCalories {
    final p = _parse(_protein);
    final c = _parse(_carbs);
    final f = _parse(_fat);
    return (p * 4 + c * 4 + f * 9).round();
  }

  @override
  void dispose() {
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _fiber.dispose();
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _parse(_protein);
    final c = _parse(_carbs);
    final f = _parse(_fat);
    final fi = _parse(_fiber);
    final kcal = (p * 4 + c * 4 + f * 9).round();
    // Use injected AppState; if user logged out meanwhile, session null => block
    if (Supabase.instance.client.auth.currentSession == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }
    final state = widget.appState;
    final dayKey = AppState.dayKeyFrom(DateTime.now());
    final id = state.generateId();
    final entry = MacroEntry(
      id: id,
      dayKey: dayKey,
      createdAt: DateTime.now(),
      meal: meal,
      protein: p,
      carbs: c,
      fat: f,
      fiber: fi,
      kcal: kcal,
      title: _title.text.trim().isEmpty ? 'Quick Add' : _title.text.trim(),
    );
    state.addEntry(entry);
    HapticFeedback.lightImpact();
    Navigator.pop(context, meal);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Added. UNDO'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => state.deleteEntry(id, dayKey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Quick Add',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedMealSelector(
                      value: meal,
                      onChanged: (m) => setState(() => meal = m),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _title,
                      decoration: InputDecoration(
                        labelText: 'Title (optional)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _numberField('Protein (g)', _protein)),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField('Carbs (g)', _carbs)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _numberField('Fat (g)', _fat)),
                        const SizedBox(width: 12),
                        Expanded(child: _numberField('Fiber (g)', _fiber)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_protein, _carbs, _fat]),
                        builder: (context, _) => Text(
                          'Estimated calories: $estimatedCalories',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Log Macros'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
