import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_fitness_app/theme.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
import 'goals_screen.dart' show GoalsPanel;

class SettingsGoalsScreen extends StatefulWidget {
  const SettingsGoalsScreen({super.key});
  @override
  State<SettingsGoalsScreen> createState() => _SettingsGoalsScreenState();
}

class _SettingsGoalsScreenState extends State<SettingsGoalsScreen> {
  final _newPass = TextEditingController();
  final _newPass2 = TextEditingController();
  bool _busy = false;
  bool _showPass1 = false;
  bool _showPass2 = false;
  SupabaseClient get _sb => Supabase.instance.client;

  // ── Account actions ────────────────────────────────────────────────────────

  Future<void> _changePassword() async {
    if (_newPass.text.trim().length < 6 || _newPass.text != _newPass2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords must match (min 6 characters).'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final resp = await _sb.auth.updateUser(
        UserAttributes(password: _newPass.text.trim()),
      );
      if (resp.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated.')),
        );
        _newPass.clear();
        _newPass2.clear();
      } else {
        throw Exception('Password update failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await _sb.auth.signOut();
      if (mounted) context.read<AppState>().resetForLogout();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'This permanently deletes your account and all data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final res = await _sb.functions.invoke('delete_user');
      if (res.status == 200) {
        await _sb.auth.signOut();
        if (mounted) context.read<AppState>().resetForLogout();
      } else {
        throw Exception('Delete failed (${res.status})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _initials(String? email) {
    if (email == null || email.isEmpty) return '?';
    return email[0].toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = _sb.auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 16,
                    20,
                    120 + MediaQuery.of(context).padding.bottom,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Page title
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 20),

                      // ── Account card
                      _SectionCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar + email row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: .15),
                                  child: Text(
                                    _initials(user?.email),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Account',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user?.email ?? 'Anonymous',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: _signOut,
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 16),

                            // Change password section
                            Text(
                              'Change Password',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _newPass,
                              obscureText: !_showPass1,
                              decoration: InputDecoration(
                                hintText: 'New password',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _showPass1
                                      ? 'Hide password'
                                      : 'Show password',
                                  icon: Icon(
                                    _showPass1
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _showPass1 = !_showPass1),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _newPass2,
                              obscureText: !_showPass2,
                              decoration: InputDecoration(
                                hintText: 'Confirm new password',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _showPass2
                                      ? 'Hide password'
                                      : 'Show password',
                                  icon: Icon(
                                    _showPass2
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _showPass2 = !_showPass2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _changePassword,
                                child: const Text('Update Password'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Goals panel
                      _SectionCard(
                        isDark: isDark,
                        child: const GoalsPanel(compact: true),
                      ),

                      const SizedBox(height: 16),

                      // ── Macro Profiles (calorie cycling)
                      _SectionCard(
                        isDark: isDark,
                        child: const _MacroProfilesPanel(),
                      ),

                      const SizedBox(height: 32),

                      // ── Danger zone  (visually separated, at the bottom)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: .25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Danger Zone',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Deleting your account permanently removes all data. This action cannot be reversed.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _deleteAccount,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(
                                    color: AppColors.danger,
                                  ),
                                ),
                                child: const Text('Delete Account'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            if (_busy)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPass.dispose();
    _newPass2.dispose();
    super.dispose();
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SectionCard({required this.child, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        decoration: appCardDecoration(isDark: isDark),
        padding: const EdgeInsets.all(20),
        child: child,
      );
}

// ── Macro Presets Panel ───────────────────────────────────────────────────────

class _MacroProfilesPanel extends StatelessWidget {
  const _MacroProfilesPanel();

  static Color _colorForIndex(int i) {
    const palette = [
      Color(0xFF48CAE4),
      AppColors.primary,
      AppColors.danger,
      Color(0xFF38B2AC),
      Color(0xFF9F7AEA),
      Color(0xFFED8936),
    ];
    return palette[i % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final theme = Theme.of(context);
    final presets = appState.macroPresets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Day Presets',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => _createPreset(context, appState),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to edit macros, name or emoji. Long-press to set as today.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < presets.length; i++) ...[
          _PresetRow(
            preset: presets[i],
            isToday: appState.todayPresetId == presets[i].id,
            color: _colorForIndex(i),
            onTap: () => _editPreset(context, appState, presets[i]),
            onSetToday: () => appState.setPreset(presets[i].id),
            onDelete: presets.length > 1 ? () => _confirmDelete(context, appState, presets[i]) : null,
          ),
          if (i < presets.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _editPreset(BuildContext context, AppState appState, MacroPreset preset) {
    showDialog<void>(
      context: context,
      builder: (_) => _PresetDialog(
        preset: preset,
        onSave: (updated) => appState.updatePreset(updated),
      ),
    );
  }

  void _createPreset(BuildContext context, AppState appState) {
    final newPreset = MacroPreset(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: 'New Preset',
      emoji: '📋',
      protein: 150,
      carbs: 200,
      fat: 60,
      fiber: 25,
      kcal: 1980,
    );
    showDialog<void>(
      context: context,
      builder: (_) => _PresetDialog(
        preset: newPreset,
        isNew: true,
        onSave: (p) => appState.addPreset(p),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState, MacroPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('Delete "${preset.emoji} ${preset.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) appState.deletePreset(preset.id);
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.isToday,
    required this.color,
    required this.onTap,
    required this.onSetToday,
    this.onDelete,
  });

  final MacroPreset preset;
  final bool isToday;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onSetToday;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onSetToday,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isToday ? .5 : .2)),
        ),
        child: Row(
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('TODAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${preset.kcal} kcal  ·  ${preset.protein.toInt()}p  ${preset.carbs.toInt()}c  ${preset.fat.toInt()}f  ${preset.fiber.toInt()}fib',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.black26),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            Icon(Icons.edit_rounded, size: 16, color: color.withValues(alpha: .6)),
          ],
        ),
      ),
    );
  }
}

class _PresetDialog extends StatefulWidget {
  const _PresetDialog({required this.preset, required this.onSave, this.isNew = false});
  final MacroPreset preset;
  final ValueChanged<MacroPreset> onSave;
  final bool isNew;

  @override
  State<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<_PresetDialog> {
  late final TextEditingController _name;
  late final TextEditingController _emoji;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _name = TextEditingController(text: p.name);
    _emoji = TextEditingController(text: p.emoji);
    _protein = TextEditingController(text: p.protein.toInt().toString());
    _carbs = TextEditingController(text: p.carbs.toInt().toString());
    _fat = TextEditingController(text: p.fat.toInt().toString());
    _fiber = TextEditingController(text: p.fiber.toInt().toString());
  }

  @override
  void dispose() {
    _name.dispose(); _emoji.dispose();
    _protein.dispose(); _carbs.dispose(); _fat.dispose(); _fiber.dispose();
    super.dispose();
  }

  int get _kcal {
    final p = double.tryParse(_protein.text) ?? 0;
    final c = double.tryParse(_carbs.text) ?? 0;
    final f = double.tryParse(_fat.text) ?? 0;
    return (p * 4 + c * 4 + f * 9).round();
  }

  void _save() {
    final p = double.tryParse(_protein.text);
    final c = double.tryParse(_carbs.text);
    final f = double.tryParse(_fat.text);
    final fib = double.tryParse(_fiber.text);
    if (p == null || c == null || f == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid numbers')));
      return;
    }
    widget.onSave(widget.preset.copyWith(
      name: _name.text.trim().isEmpty ? widget.preset.name : _name.text.trim(),
      emoji: _emoji.text.trim().isEmpty ? widget.preset.emoji : _emoji.text.trim(),
      protein: p,
      carbs: c,
      fat: f,
      fiber: fib ?? widget.preset.fiber,
      kcal: _kcal,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'New Preset' : 'Edit Preset'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: _emoji,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22),
                    decoration: const InputDecoration(labelText: 'Icon'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Per day targets:', style: TextStyle(fontSize: 12, color: Colors.black54))),
            const SizedBox(height: 10),
            _MacroField(label: 'Protein (g)', controller: _protein, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            _MacroField(label: 'Carbs (g)', controller: _carbs, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            _MacroField(label: 'Fat (g)', controller: _fat, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            _MacroField(label: 'Fiber (g)', controller: _fiber, onChanged: () => setState(() {})),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated kcal', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('$_kcal kcal', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _MacroField extends StatelessWidget {
  const _MacroField({required this.label, required this.controller, required this.onChanged});
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(labelText: label),
    );
  }
}
