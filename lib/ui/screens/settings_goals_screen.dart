import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_fitness_app/providers/app_state.dart';
// TODO: replace with actual goals editor widget (extracted from GoalsScreen) if different
import 'goals_screen.dart' show GoalsScreen, GoalsPanel; // added for embedded goals panel

class SettingsGoalsScreen extends StatefulWidget {
  const SettingsGoalsScreen({super.key});
  @override
  State<SettingsGoalsScreen> createState() => _SettingsGoalsScreenState();
}

class _SettingsGoalsScreenState extends State<SettingsGoalsScreen> {
  final _newPass = TextEditingController();
  final _newPass2 = TextEditingController();
  bool _busy = false;
  SupabaseClient get _sb => Supabase.instance.client;

  Future<void> _changePassword() async {
    if (_newPass.text.trim().length < 6 || _newPass.text != _newPass2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords must match (min 6 chars).')),
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
          'This permanently deletes your account and data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
            FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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

  @override
  Widget build(BuildContext context) {
    final user = _sb.auth.currentUser;
    return Scaffold(
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 12,
                20,
                120 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? 'Anonymous',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        const Divider(height: 32),
                        const Text('Change password'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newPass,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'New password',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newPass2,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Confirm new password',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: _changePassword,
                              child: const Text('Update password'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _signOut,
                              child: const Text('Sign out'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _deleteAccount,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Goals panel (compact)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: GoalsPanel(compact: true),
                  ),
                ),
              ],
            ),
            if (_busy)
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
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
