// filepath: lib/data/local_store_interface.dart
// One interface + platform factory via conditional imports.

import 'local_store_stub.dart'
    if (dart.library.html) 'local_store_web.dart'
    if (dart.library.io) 'local_store_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_store.dart';
import 'syncing_store.dart';

abstract class LocalStore {
  /// Optional init hook (file path prep, etc.)
  Future<void> init() async {}

  /// Persist the full app blob.
  Future<void> saveJson(Map<String, dynamic> blob);

  /// Load the full app blob (return {} if nothing).
  Future<Map<String, dynamic>> loadJson();
}

LocalStore createPlatformLocalStore() => createLocalStoreImpl();

/// Returns the platform-specific implementation.
// Implemented in *_web.dart / *_io.dart / stub.
LocalStore createLocalStore() {
  try {
    final authUser = Supabase.instance.client.auth.currentUser;
    final base = createPlatformLocalStore();
    if (authUser != null) {
      return SyncingStore(local: base, cloud: CloudStore());
    }
    return base;
  } catch (_) {
    // Supabase not initialized yet; fall back to local.
    return createPlatformLocalStore();
  }
}
