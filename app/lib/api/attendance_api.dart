import '../core/attendance.dart';
import 'api_client.dart';

/// Syncs attendance buckets with `GET/PUT/PATCH /api/me/attendance`.
class AttendanceApi {
  AttendanceApi(this._client);

  final ApiClient _client;

  Future<List<AttendanceBucket>> fetchBuckets() async {
    final data = await _client.requestJson('/api/me/attendance');
    final raw = data['buckets'];
    if (raw is! List) return const [];
    final out = <AttendanceBucket>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(AttendanceBucket.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
    return out;
  }

  Future<List<AttendanceBucket>> replaceBuckets(List<AttendanceBucket> buckets) async {
    final data = await _client.requestJson(
      '/api/me/attendance',
      method: 'PUT',
      body: {
        'buckets': buckets.map((b) => b.toJson()).toList(),
      },
    );
    final raw = data['buckets'];
    if (raw is! List) return const [];
    final out = <AttendanceBucket>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(AttendanceBucket.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
    return out;
  }

  Future<AttendanceBucket> patchMark({
    required String courseCode,
    required String sessionKind,
    required String date,
    String? status,
  }) async {
    final data = await _client.requestJson(
      '/api/me/attendance',
      method: 'PATCH',
      body: {
        'courseCode': courseCode,
        'sessionKind': sessionKind,
        'date': date,
        if (status != null) 'status': status,
      },
    );
    final raw = data['bucket'];
    if (raw is! Map) {
      throw ApiException('invalid_response');
    }
    return AttendanceBucket.fromJson(Map<String, dynamic>.from(raw));
  }
}
