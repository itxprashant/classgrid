import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/course.dart';
import '../storage/local_store.dart';

/// Loads and caches the course catalog. Mirrors the web app's static
/// `courses.json` import, but sourced from `GET /api/catalog` with an offline
/// SharedPreferences cache fallback.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._client, this._store);

  final ApiClient _client;
  final LocalStore _store;

  List<Course> _courses = [];
  Map<String, Course> _index = {};
  bool _loading = true;
  String? _error;

  List<Course> get courses => _courses;
  bool get loading => _loading;
  String? get error => _error;
  bool get isReady => _courses.isNotEmpty;

  Course? byCode(String code) => _index[code.toUpperCase()];

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    // Seed from cache first for instant render / offline support.
    final cached = _store.loadCatalogCache();
    if (cached != null && _courses.isEmpty) {
      _ingest(cached);
    }

    try {
      final data = await _client.requestJson('/api/catalog');
      final raw = data['courses'];
      if (raw is List) {
        _ingest(raw);
        await _store.saveCatalogCache(raw, data['etag']?.toString());
      }
    } catch (e) {
      // Keep any cached data; only surface an error if we have nothing.
      if (_courses.isEmpty) {
        _error = e is ApiException ? e.message : 'Could not load catalog';
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _ingest(List<dynamic> raw) {
    final list = raw
        .whereType<Map>()
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.courseCode.isNotEmpty)
        .toList();
    _courses = list;
    _index = {for (final c in list) c.courseCode.toUpperCase(): c};
  }
}
