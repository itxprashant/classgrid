import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/course.dart';

/// Full course catalog for the explorer: current semester + historical-only codes.
class ExplorerCatalogProvider extends ChangeNotifier {
  ExplorerCatalogProvider(this._client);

  final ApiClient _client;

  List<Course> _courses = [];
  Map<String, Course> _index = {};
  bool _loading = true;
  String? _error;
  String? _semesterCode;
  int _offeredCount = 0;

  List<Course> get courses => _courses;
  bool get loading => _loading;
  String? get error => _error;
  String? get semesterCode => _semesterCode;
  int get offeredCount => _offeredCount;
  bool get isReady => _courses.isNotEmpty;

  Course? byCode(String code) => _index[code.toUpperCase()];

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _client.dio.get<dynamic>('/api/catalog/explorer');
      if (res.statusCode == null || res.statusCode! < 200 || res.statusCode! >= 300) {
        throw ApiException('explorer_catalog_load_failed', status: res.statusCode);
      }
      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final raw = map['courses'];
        if (raw is List) {
          _ingest(raw, map['semesterCode']?.toString(), map['offeredCount']);
        }
      }
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not load course catalog';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _ingest(List<dynamic> raw, String? semesterCode, dynamic offeredCount) {
    final list = raw
        .whereType<Map>()
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.courseCode.isNotEmpty)
        .toList();
    _courses = list;
    _index = {for (final c in list) c.courseCode.toUpperCase(): c};
    _semesterCode = semesterCode;
    _offeredCount = offeredCount is num ? offeredCount.toInt() : list.where((c) => c.offeredThisSemester).length;
  }
}
