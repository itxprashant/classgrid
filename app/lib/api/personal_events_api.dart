import '../models/calendar_event.dart';
import 'api_client.dart';

class PersonalEventsApi {
  PersonalEventsApi(this._client);
  final ApiClient _client;

  /// `GET /api/me/events?from=&to=` — private events for the signed-in user.
  Future<List<CalendarEvent>> fetchPersonalEvents({
    required String from,
    required String to,
  }) async {
    final data = await _client
        .requestJson('/api/me/events', query: {'from': from, 'to': to});
    final raw = data['events'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => CalendarEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<CalendarEvent> createPersonalEvent(Map<String, dynamic> payload) async {
    final data = await _client.requestJson('/api/me/events',
        method: 'POST', body: payload);
    return CalendarEvent.fromJson(Map<String, dynamic>.from(data['event']));
  }

  Future<CalendarEvent> patchPersonalEvent(
      String id, Map<String, dynamic> payload) async {
    final data = await _client.requestJson('/api/me/events/$id',
        method: 'PATCH', body: payload);
    return CalendarEvent.fromJson(Map<String, dynamic>.from(data['event']));
  }

  Future<void> removePersonalEvent(String id) async {
    await _client.requestJson('/api/me/events/$id', method: 'DELETE');
  }
}
