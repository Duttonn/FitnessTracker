// filepath: lib/data/syncing_store.dart
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_store_interface.dart';
import 'cloud_store.dart';

/// SyncingStore composes a local store (offline cache) with a CloudStore.
/// It loads local immediately, then merges with cloud (if signed in) using
/// deterministic union rules. Cloud writes are debounced to reduce chatter.
class SyncingStore implements LocalStore {
  final LocalStore local;
  final CloudStore cloud;
  final _uuid = const Uuid();
  Timer? _debounce;
  Map<String, dynamic>? _pending; // last blob queued for cloud write
  bool get _signedIn => Supabase.instance.client.auth.currentUser != null;

  SyncingStore({required this.local, required this.cloud});

  @override
  Future<void> init() async {
    await local.init();
    if (_signedIn) {
      await cloud.init();
    }
  }

  @override
  Future<Map<String, dynamic>> loadJson() async {
    // 1. Local fast path
    final localData = await local.loadJson();
    if (!_signedIn) return localData;

    // 2. Cloud fetch (best effort)
    Map<String, dynamic> cloudData = {};
    try {
      cloudData = await cloud.loadJson();
    } catch (_) {
      // offline or auth issue; stay local
      return localData;
    }

    if (cloudData.isEmpty && localData.isNotEmpty) {
      // First sync: seed cloud with existing local snapshot.
      _queueCloud(localData);
      return localData;
    }
    if (localData.isEmpty && cloudData.isNotEmpty) {
      // New device: hydrate local
      await local.saveJson(cloudData);
      return cloudData;
    }
    if (localData.isEmpty && cloudData.isEmpty) return {};

    final merged = _merge(localData, cloudData);
    await local.saveJson(merged);
    _queueCloud(merged);
    return merged;
  }

  @override
  Future<void> saveJson(Map<String, dynamic> blob) async {
    await local.saveJson(blob);
    if (_signedIn) _queueCloud(blob);
  }

  void _queueCloud(Map<String, dynamic> blob) {
    _pending = blob;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final data = _pending;
      if (data == null) return;
      try {
        await cloud.saveJson(data);
      } catch (_) {
        // offline; will retry with next mutation
      }
    });
  }

  Map<String, dynamic> _merge(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final result = <String, dynamic>{};

    // entriesByDay union / dedupe by id
    final Map<String, dynamic> localDays = Map<String, dynamic>.from(
      local['entriesByDay'] ?? {},
    );
    final Map<String, dynamic> cloudDays = Map<String, dynamic>.from(
      cloud['entriesByDay'] ?? {},
    );
    final mergedDays = <String, dynamic>{};
    for (final day in {...localDays.keys, ...cloudDays.keys}) {
      final lList = (localDays[day] as List?) ?? const [];
      final cList = (cloudDays[day] as List?) ?? const [];
      final combined = <Map<String, dynamic>>[...lList.cast(), ...cList.cast()];
      final byId = <String, Map<String, dynamic>>{};
      for (final raw in combined) {
        final entry = Map<String, dynamic>.from(raw);
        var id = entry['id'] as String?;
        id ??= _deriveEntryId(entry);
        entry['id'] = id;
        final existing = byId[id];
        if (existing == null) {
          byId[id] = entry;
        } else {
          final exUpdated =
              _parseDt(existing['updatedAt']) ??
              _parseDt(existing['createdAt']);
          final enUpdated =
              _parseDt(entry['updatedAt']) ?? _parseDt(entry['createdAt']);
          if (exUpdated == null && enUpdated == null) {
            // Prefer cloud variant if ambiguous
            if (cList.contains(raw)) byId[id] = entry;
          } else if (exUpdated == null) {
            byId[id] = entry; // new has timestamp
          } else if (enUpdated == null) {
            // keep existing
          } else if (enUpdated.isAfter(exUpdated)) {
            byId[id] = entry;
          }
        }
      }
      mergedDays[day] = byId.values.toList();
    }
    result['entriesByDay'] = mergedDays;

    // weights union by truncated minute
    final lWeights = (local['weights'] as List?) ?? const [];
    final cWeights = (cloud['weights'] as List?) ?? const [];
    final wMap = <String, Map<String, dynamic>>{};
    for (final raw in [...lWeights, ...cWeights]) {
      final w = Map<String, dynamic>.from(raw as Map);
      final loggedAt = w['loggedAt'] as String?;
      if (loggedAt == null) continue;
      final key = _truncateMinute(loggedAt);
      final existing = wMap[key];
      if (existing == null) {
        wMap[key] = w;
      } else {
        final exDt = _parseDt(existing['loggedAt']);
        final nwDt = _parseDt(loggedAt);
        if (exDt == null || (nwDt?.isAfter(exDt) ?? false)) {
          wMap[key] = w;
        }
      }
    }
    result['weights'] = wMap.values.toList();

    // goals prefer newer updatedAt else cloud
    final lGoals = local['goals'];
    final cGoals = cloud['goals'];
    if (lGoals == null) {
      result['goals'] = cGoals ?? {};
    } else if (cGoals == null) {
      result['goals'] = lGoals;
    } else {
      final lU = _parseDt(lGoals['updatedAt']);
      final cU = _parseDt(cGoals['updatedAt']);
      if (lU == null && cU == null) {
        result['goals'] = cGoals; // prefer cloud
      } else if (lU != null && cU != null) {
        result['goals'] = cU.isAfter(lU) ? cGoals : lGoals;
      } else if (cU != null) {
        result['goals'] = cGoals;
      } else {
        result['goals'] = lGoals;
      }
    }

    // ingredients & meals maps
    result['ingredients'] = _mergeEntityMap(
      local['ingredients'] as Map?,
      cloud['ingredients'] as Map?,
    );
    result['meals'] = _mergeEntityMap(
      local['meals'] as Map?,
      cloud['meals'] as Map?,
    );

    // activeWeekdays: prefer cloud if set
    result['activeWeekdays'] =
        cloud['activeWeekdays'] ??
        local['activeWeekdays'] ??
        List.generate(7, (i) => i);

    // Carry forward unknown future keys (cloud wins)
    for (final k in {...local.keys, ...cloud.keys}) {
      if (!result.containsKey(k)) {
        result[k] = cloud[k] ?? local[k];
      }
    }

    return result;
  }

  Map<String, dynamic> _mergeEntityMap(Map? lRaw, Map? cRaw) {
    final l = lRaw != null
        ? Map<String, dynamic>.from(lRaw)
        : <String, dynamic>{};
    final c = cRaw != null
        ? Map<String, dynamic>.from(cRaw)
        : <String, dynamic>{};
    final out = <String, dynamic>{};
    for (final id in {...l.keys, ...c.keys}) {
      final li = l[id];
      final ci = c[id];
      if (li == null) {
        out[id] = ci;
        continue;
      }
      if (ci == null) {
        out[id] = li;
        continue;
      }
      final lU = _parseDt(li['updatedAt']) ?? _parseDt(li['lastFetchedAt']);
      final cU = _parseDt(ci['updatedAt']) ?? _parseDt(ci['lastFetchedAt']);
      if (lU == null && cU == null) {
        out[id] = ci; // prefer cloud when ambiguous
      } else if (lU != null && cU != null) {
        out[id] = cU.isAfter(lU) ? ci : li;
      } else if (cU != null) {
        out[id] = ci;
      } else {
        out[id] = li;
      }
    }
    return out;
  }

  String _truncateMinute(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateTime(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
      ).toIso8601String();
    } catch (_) {
      return iso;
    }
  }

  DateTime? _parseDt(dynamic v) {
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _deriveEntryId(Map<String, dynamic> e) {
    final created = e['createdAt'];
    final title = e['title'] ?? '';
    return 'auto_${created ?? _uuid.v4()}_${title.hashCode}';
  }
}
