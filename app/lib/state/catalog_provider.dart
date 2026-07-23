import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/course.dart';
import '../models/plan.dart';
import '../storage/local_store.dart';

/// Loads and caches the course catalog from `GET /api/catalog` with offline
/// SharedPreferences cache fallback and ETag revalidation.
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

  /// Fill empty [SelectedCourse.lectureHall] from the live catalog (stale plans).
  List<SelectedCourse> enrichSelectedCourses(List<SelectedCourse> courses) {
    return courses.map((c) {
      if (c.lectureHall != null && c.lectureHall!.isNotEmpty) return c;
      final hall = byCode(c.courseCode)?.lectureHall;
      if (hall == null || hall.isEmpty) return c;
      return SelectedCourse(
        courseCode: c.courseCode,
        courseName: c.courseName,
        instructor: c.instructor,
        lecture: c.lecture,
        tutorial: c.tutorial,
        lab: c.lab,
        lectureTiming: c.lectureTiming,
        tutorialTiming: c.tutorialTiming,
        labTiming: c.labTiming,
        creditStructure: c.creditStructure,
        totalCredits: c.totalCredits,
        lectureHall: hall,
      );
    }).toList();
  }

  bool get _cacheHasAnyHall =>
      _courses.any((c) => (c.lectureHall ?? '').trim().isNotEmpty);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final cached = _store.loadCatalogCache();
    if (cached != null && _courses.isEmpty) {
      _ingest(cached);
    }

    try {
      await _fetchCatalog(useEtag: true);

      // Venue sync used to update halls without bumping catalog_etag, so a
      // 304 could leave the app on a hall-less cache. Refetch once without
      // If-None-Match when the local catalog has no venues at all.
      if (_courses.isNotEmpty && !_cacheHasAnyHall) {
        await _fetchCatalog(useEtag: false);
      }
    } catch (e) {
      if (_courses.isEmpty) {
        _error = e is ApiException ? e.message : 'Could not load catalog';
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCatalog({required bool useEtag}) async {
    final headers = <String, dynamic>{};
    if (useEtag) {
      final etag = _store.loadCatalogEtag();
      if (etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }
    }

    final res = await _client.dio.get<dynamic>(
      '/api/catalog',
      options: Options(headers: headers),
    );

    if (res.statusCode == 304) {
      // Cached catalog is still current.
      return;
    }
    if (res.statusCode != null &&
        res.statusCode! >= 200 &&
        res.statusCode! < 300) {
      final data = res.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final raw = map['courses'];
        if (raw is List) {
          _ingest(raw);
          final newEtag = res.headers.value('etag') ?? res.headers.value('ETag');
          await _store.saveCatalogCache(raw, newEtag);
        }
      }
      return;
    }
    throw ApiException(
      'catalog_load_failed',
      status: res.statusCode,
    );
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
