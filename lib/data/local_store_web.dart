// filepath: lib/data/local_store_web.dart
import 'dart:convert';
import 'dart:html' as html;
import 'local_store_interface.dart';

class WebLocalStore implements LocalStore {
  static const _k = 'app_state_json';

  @override
  Future<void> init() async {
    // nothing needed for web
  }

  @override
  Future<void> saveJson(Map<String, dynamic> blob) async {
    try {
      html.window.localStorage[_k] = jsonEncode(blob);
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> loadJson() async {
    try {
      final s = html.window.localStorage[_k];
      if (s == null || s.isEmpty) return {};
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : {};
    } catch (_) {
      return {};
    }
  }
}

LocalStore createLocalStoreImpl() => WebLocalStore();
