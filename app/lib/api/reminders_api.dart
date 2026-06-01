import '../storage/reminder_store.dart';
import 'api_client.dart';

/// Syncs class/event reminder subscriptions with `GET/POST/PUT/DELETE /api/me/reminders`.
class RemindersApi {
  RemindersApi(this._client);

  final ApiClient _client;

  Future<List<ReminderEntry>> fetchReminders() async {
    final data = await _client.requestJson('/api/me/reminders');
    final raw = data['reminders'];
    if (raw is! List) return const [];
    final out = <ReminderEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(ReminderEntry.fromApiJson(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
    return out;
  }

  Future<ReminderEntry> upsertReminder(ReminderEntry entry) async {
    final data = await _client.requestJson(
      '/api/me/reminders',
      method: 'POST',
      body: entry.toApiJson(),
    );
    final raw = data['reminder'];
    if (raw is! Map) {
      throw ApiException('invalid_response');
    }
    return ReminderEntry.fromApiJson(Map<String, dynamic>.from(raw));
  }

  Future<List<ReminderEntry>> replaceReminders(List<ReminderEntry> entries) async {
    final data = await _client.requestJson(
      '/api/me/reminders',
      method: 'PUT',
      body: {
        'reminders': entries.map((e) => e.toApiJson()).toList(),
      },
    );
    final raw = data['reminders'];
    if (raw is! List) return const [];
    final out = <ReminderEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(ReminderEntry.fromApiJson(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
    return out;
  }

  Future<void> deleteReminder(String key) async {
    await _client.requestJson(
      '/api/me/reminders/${Uri.encodeComponent(key)}',
      method: 'DELETE',
    );
  }
}
