import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_hbb/models/platform_model.dart';

const kAuditLogOptionKey = 'no-clients-audit';
const _kMaxEntries = 200;

class AuditEntry {
  AuditEntry({
    required this.when,
    required this.client,
    required this.machine,
    required this.id,
    required this.online,
  });

  final DateTime when;
  final String client;
  final String machine;
  final String id;
  final bool online;
  int? durationSeconds;

  Map<String, dynamic> toJson() => {
        'when': when.toIso8601String(),
        'client': client,
        'machine': machine,
        'id': id,
        'online': online,
        'duration': durationSeconds,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        when: DateTime.tryParse((json['when'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        client: (json['client'] ?? '').toString(),
        machine: (json['machine'] ?? '').toString(),
        id: (json['id'] ?? '').toString(),
        online: json['online'] == true,
      )..durationSeconds = (json['duration'] as num?)?.toInt();
}

/// Local connection history: when a machine was connected, from which client,
/// and how long the session lasted.
class AuditLog {
  final List<AuditEntry> entries = <AuditEntry>[];
  final Map<String, DateTime> _starts = <String, DateTime>{};

  void load() {
    entries.clear();
    final raw = bind.mainGetLocalOption(key: kAuditLogOptionKey);
    if (raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        for (final entry in data) {
          if (entry is Map) {
            entries.add(AuditEntry.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
      }
    } catch (e) {
      debugPrint('load audit log failed: $e');
    }
  }

  Future<void> save() async {
    await bind.mainSetLocalOption(
      key: kAuditLogOptionKey,
      value: jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  void recordStart({
    required String client,
    required String machine,
    required String id,
    required bool online,
  }) {
    final now = DateTime.now();
    _starts[id] = now;
    entries.insert(
      0,
      AuditEntry(
        when: now,
        client: client,
        machine: machine,
        id: id,
        online: online,
      ),
    );
    if (entries.length > _kMaxEntries) {
      entries.removeRange(_kMaxEntries, entries.length);
    }
    save().catchError((e) => debugPrint('save audit log failed: $e'));
  }

  /// Marks the newest open session for [id] as finished.
  void recordEnd(String id) {
    final start = _starts.remove(id);
    if (start == null) return;
    final duration = DateTime.now().difference(start).inSeconds;
    for (final entry in entries) {
      if (entry.id == id && entry.durationSeconds == null) {
        entry.durationSeconds = duration;
        break;
      }
    }
    save().catchError((e) => debugPrint('save audit log failed: $e'));
  }

  void clear() {
    entries.clear();
    _starts.clear();
    save().catchError((e) => debugPrint('save audit log failed: $e'));
  }
}
