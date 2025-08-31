import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/macromate_state.json');
  }

  static Future<Map<String, dynamic>?> readState() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeState(Map<String, dynamic> m) async {
    final f = await _file();
    await f.create(recursive: true);
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(m));
  }
}
