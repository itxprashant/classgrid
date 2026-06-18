import 'package:flutter/foundation.dart';

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

  bool get loading => _loading;
  String? get error => _error;
  SemesterScheduleConfig? get schedule => _schedule;
  List<Map<String, dynamic>> get extraOccupied => _extraOccupied;
  bool get isReady => _schedule != null;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

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
