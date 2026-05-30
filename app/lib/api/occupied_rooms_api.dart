import '../models/occupied_room.dart';
import 'api_client.dart';

class OccupiedRoomsApi {
  OccupiedRoomsApi(this._client);
  final ApiClient _client;

  /// `GET /api/rooms/occupied?date=&time=` — active markings at a date+time.
  /// [time] is an integer HHMM (e.g. 1430).
  Future<List<OccupiedRoom>> fetchOccupiedRooms({
    required String date,
    required int time,
  }) async {
    final data = await _client.requestJson('/api/rooms/occupied',
        query: {'date': date, 'time': time});
    final raw = data['markings'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => OccupiedRoom.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<OccupiedRoom> createOccupiedRoom({
    required String room,
    required String date,
    required String start,
    required String end,
    String? note,
  }) async {
    final data = await _client.requestJson('/api/rooms/occupied',
        method: 'POST',
        body: {
          'room': room,
          'date': date,
          'start': start,
          'end': end,
          if (note != null && note.isNotEmpty) 'note': note,
        });
    return OccupiedRoom.fromJson(Map<String, dynamic>.from(data['marking']));
  }

  Future<void> removeOccupiedRoom(String id) async {
    await _client.requestJson('/api/rooms/occupied/$id', method: 'DELETE');
  }
}
