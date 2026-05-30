import '../models/calendar_event.dart';
import 'api_client.dart';

class CalendarEventsApi {
  CalendarEventsApi(this._client);
  final ApiClient _client;

  /// `GET /api/events?from=&to=&courses=` — shared course events.
  Future<List<CalendarEvent>> fetchEvents({
    required String from,
    required String to,
    required List<String> courses,
  }) async {
    final query = <String, dynamic>{'from': from, 'to': to};
    final unique = courses.where((c) => c.isNotEmpty).toSet().toList();
    if (unique.isNotEmpty) query['courses'] = unique.join(',');
    final data = await _client.requestJson('/api/events', query: query);
    final raw = data['events'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => CalendarEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<CalendarEvent> createEvent(Map<String, dynamic> payload) async {
    final data =
        await _client.requestJson('/api/events', method: 'POST', body: payload);
    return CalendarEvent.fromJson(Map<String, dynamic>.from(data['event']));
  }

  Future<CalendarEvent> patchEvent(String id, Map<String, dynamic> payload) async {
    final data = await _client.requestJson('/api/events/$id',
        method: 'PATCH', body: payload);
    return CalendarEvent.fromJson(Map<String, dynamic>.from(data['event']));
  }

  Future<void> removeEvent(String id) async {
    await _client.requestJson('/api/events/$id', method: 'DELETE');
  }
}
