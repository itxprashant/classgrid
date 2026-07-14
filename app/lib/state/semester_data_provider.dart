import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../core/semester_schedule.dart';
import '../storage/local_store.dart';

/// Loads academic calendar + legacy extra-occupied overlay from the API.
class SemesterDataProvider extends ChangeNotifier {
  SemesterDataProvider(this._client, this._store);

  final ApiClient _client;
  final LocalStore _store;

  bool _loading = true;
  String? _error;
  SemesterScheduleConfig? _schedule;
  List<Map<String, dynamic>> _extraOccupied = [];
  List<String> _campusRooms = [];

  bool get loading => _loading;
  String? get error => _error;
  SemesterScheduleConfig? get schedule => _schedule;
  List<Map<String, dynamic>> get extraOccupied => _extraOccupied;
  List<String> get campusRooms => _campusRooms;
  bool get isReady => _schedule != null;

  static Future<List<String>> _loadCampusRoomsAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/campus_rooms.json');
      final data = jsonDecode(raw);
      if (data is Map && data['rooms'] is List) {
        return data['rooms'].whereType<String>().toList();
      }
    } catch (_) {
      // Non-fatal — rooms page falls back to catalog-only list.
    }
    return const [];
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    _campusRooms = await _loadCampusRoomsAsset();

    final cachedSchedule = _store.loadScheduleCache();
    final cachedExtra = _store.loadExtraOccupiedCache();
    if (cachedSchedule != null) {
      _schedule = SemesterScheduleConfig.fromJson(cachedSchedule);
      setActiveSemesterSchedule(_schedule);
    }
    if (cachedExtra != null) {
      _extraOccupied = cachedExtra;
    }

    try {
      final scheduleData = await _client.requestJson('/api/semester/schedule');
      _schedule = SemesterScheduleConfig.fromJson(scheduleData);
      setActiveSemesterSchedule(_schedule);
      await _store.saveScheduleCache(scheduleData);

      final extraData = await _client.requestJson('/api/extra-occupied');
      final slots = extraData['slots'];
      if (slots is List) {
        _extraOccupied = slots
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _store.saveExtraOccupiedCache(_extraOccupied);
      }
    } catch (e) {
      if (_schedule == null) {
        _error = e is ApiException ? e.message : 'Could not load semester data';
        setActiveSemesterSchedule(null);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
