// filepath: lib/data/cloud_store.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_store_interface.dart';

/// CloudStore persists a single JSON blob per user in table `user_blobs`.
/// Schema (SQL example):
///   create table if not exists user_blobs (
///     user_id uuid primary key references auth.users(id) on delete cascade,
///     data jsonb not null default '{}'::jsonb,
///     updated_at timestamptz not null default now()
///   );
/// The blob shape matches the local export we already use.
class CloudStore implements LocalStore {
  final SupabaseClient _client = Supabase.instance.client;

  void _ensureAuthed() {
    if (_client.auth.currentUser == null) {
      throw StateError('Not signed in');
    }
  }

  @override
  Future<void> init() async {
    // no-op; table assumed created.
  }

  @override
  Future<Map<String, dynamic>> loadJson() async {
    _ensureAuthed();
    final uid = _client.auth.currentUser!.id;
    final resp = await _client
        .from('user_blobs')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (resp == null) return {};
    final map = Map<String, dynamic>.from(resp as Map);
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  @override
  Future<void> saveJson(Map<String, dynamic> blob) async {
    _ensureAuthed();
    final uid = _client.auth.currentUser!.id;
    await _client.from('user_blobs').upsert({
      'user_id': uid,
      'data': blob,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
