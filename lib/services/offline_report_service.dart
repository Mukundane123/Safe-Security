import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/repository.dart';

/// Holds incident reports created while the device is offline and replays them
/// through the repository once connectivity is back (or the user hits "retry").
class OfflineReportService {
  static const _queueKey = 'offline.reports';

  final IRepository _repo;

  OfflineReportService(this._repo);

  Future<List<Map<String, Object?>>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, Object?>>();
  }

  Future<int> pendingCount() async => (await pending()).length;

  Future<void> enqueue({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required String locationLabel,
    List<String> photoPaths = const [],
    String? subCategory,
    String? voiceNotePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await pending();
    queue.insert(
      0,
      {
        'category': category,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'locationLabel': locationLabel,
        'photoPaths': photoPaths,
        'subCategory': subCategory,
        'voiceNotePath': voiceNotePath,
        'queuedAt': DateTime.now().toIso8601String(),
      },
    );
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Removes the first pending report (retry or discard). Returns whether any
  /// report was removed.
  Future<bool> dequeue() async {
    final queue = await pending();
    if (queue.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final remaining = queue.sublist(1);
    await prefs.setString(
        _queueKey, remaining.isEmpty ? '' : jsonEncode(remaining));
    return true;
  }

  /// Attempts to submit every queued report. Returns the number successfully
  /// sent; failed ones stay in the queue.
  Future<int> flush() async {
    var sent = 0;
    while (true) {
      final queue = await pending();
      if (queue.isEmpty) break;
      final report = queue.first;
      try {
        await _repo.reportIncident(
          category: report['category'] as String,
          description: report['description'] as String,
          latitude: (report['latitude'] as num).toDouble(),
          longitude: (report['longitude'] as num).toDouble(),
          locationLabel: report['locationLabel'] as String,
          photoPaths: (report['photoPaths'] as List).cast<String>(),
          subCategory: report['subCategory'] as String?,
        );
        await dequeue();
        sent++;
      } catch (_) {
        break; // Still offline / error — stop and keep the queue for retry.
      }
    }
    return sent;
  }
}