// filepath: lib/data/local_store_io.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'local_store_interface.dart';

class FileLocalStore implements LocalStore {
  late final File _file;

  @override
  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/app_state.json');
    if (!await _file.exists()) {
      await _file.create(recursive: true);
      await _file.writeAsString('{}');
    }
  }

  @override
  Future<void> saveJson(Map<String, dynamic> blob) async {
    await _file.writeAsString(jsonEncode(blob));
  }

  @override
  Future<Map<String, dynamic>> loadJson() async {
    try {
      final s = await _file.readAsString();
      if (s.isEmpty) return {};
      final j = jsonDecode(s);
      return j is Map<String, dynamic> ? j : {};
    } catch (_) {
      return {};
    }
  }
}

LocalStore createLocalStoreImpl() => FileLocalStore();
