import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import 'auth_token.dart';

/// F2/F3 · Labeled reminders and their check-ins.
///
/// Backed by the schema's existing tasks/taskEvents pair — the same
/// definition + materialized-occurrence split the medication reminders use.
/// See apps/api/src/routes/tasks.js.

/// The labels a caregiver picks from. `category` is the schema's
/// TaskCategory value; `label` is what she reads. "Other" lets her type her
/// own title, which is why the list isn't just the enum.
class ReminderLabel {
  final String category;
  final String label;
  final bool custom;

  const ReminderLabel({required this.category, required this.label, this.custom = false});
}

const kReminderLabels = <ReminderLabel>[
  ReminderLabel(category: 'meal', label: 'Eating'),
  ReminderLabel(category: 'exercise', label: 'Exercise'),
  ReminderLabel(category: 'medication', label: 'Medication'),
  ReminderLabel(category: 'hydration', label: 'Drinking water'),
  ReminderLabel(category: 'other', label: 'Something else', custom: true),
];

class Reminder {
  final String id;
  final String title;
  final String category;
  final List<String> times;

  const Reminder({required this.id, required this.title, required this.category, required this.times});

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? 'other',
        times: List<String>.from((json['schedule']?['times'] as List?) ?? const []),
      );
}

class ReminderEvent {
  final String id;
  final String taskId;
  final String taskTitle;
  final String taskCategory;
  final DateTime scheduledAt;
  final String status;

  const ReminderEvent({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.taskCategory,
    required this.scheduledAt,
    required this.status,
  });

  bool get isDone => status == 'completed' || status == 'skipped';

  /// Whether this reminder opens a structured question set when completed
  /// (F3). Mirrors CHECKIN_FORMS on the server.
  bool get hasCheckin => taskCategory == 'meal' || taskCategory == 'exercise';

  factory ReminderEvent.fromJson(Map<String, dynamic> json) => ReminderEvent(
        id: json['id'] as String,
        taskId: json['taskId'] as String? ?? '',
        taskTitle: json['taskTitle'] as String? ?? 'Reminder',
        taskCategory: json['taskCategory'] as String? ?? 'other',
        scheduledAt: DateTime.parse(json['scheduledAt'] as String).toLocal(),
        status: json['status'] as String? ?? 'pending',
      );
}

/// One question in a reminder check-in, mirrored from reminderCheckin.js.
class CheckinQuestion {
  final String id;
  final String text;
  final List<({String id, String label})> options;

  const CheckinQuestion({required this.id, required this.text, required this.options});
}

const _mealForm = <CheckinQuestion>[
  CheckinQuestion(id: 'howMuch', text: 'How much did she eat?', options: [
    (id: 'all', label: 'All of it'),
    (id: 'most', label: 'Most'),
    (id: 'half', label: 'About half'),
    (id: 'little', label: 'A little'),
    (id: 'none', label: 'Nothing'),
  ]),
  CheckinQuestion(id: 'refused', text: 'Did she refuse or push the food away?', options: [
    (id: 'no', label: 'No'),
    (id: 'yes', label: 'Yes'),
  ]),
];

const _exerciseForm = <CheckinQuestion>[
  CheckinQuestion(id: 'activity', text: 'What did she do?', options: [
    (id: 'walk', label: 'Walked'),
    (id: 'chair', label: 'Chair exercises'),
    (id: 'stand', label: 'Stood up and moved'),
    (id: 'none', label: 'Nothing today'),
  ]),
  CheckinQuestion(id: 'duration', text: 'For how long?', options: [
    (id: 'long', label: 'More than 30 minutes'),
    (id: 'medium', label: '10 to 30 minutes'),
    (id: 'short', label: 'Less than 10 minutes'),
    (id: 'none', label: 'Did not move'),
  ]),
  CheckinQuestion(id: 'difficulty', text: 'Was it harder for her than usual?', options: [
    (id: 'no', label: 'No, the same'),
    (id: 'yes', label: 'Yes, harder'),
  ]),
];

List<CheckinQuestion> checkinFormFor(String category) => switch (category) {
      'meal' => _mealForm,
      'exercise' => _exerciseForm,
      _ => const [],
    };

class ReminderService {
  const ReminderService();

  String _base(String householdId, String careRecipientId) =>
      '$apiBaseUrl/households/$householdId/care-recipients/$careRecipientId';

  Future<String> create({
    required String householdId,
    required String careRecipientId,
    required String title,
    required String category,
    required List<String> times,
  }) async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse('${_base(householdId, careRecipientId)}/tasks'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'category': category, 'times': times}),
    );
    if (res.statusCode != 200) throw Exception('Could not save the reminder: ${res.body}');
    return (jsonDecode(res.body) as Map<String, dynamic>)['taskId'] as String;
  }

  Future<List<Reminder>> list({
    required String householdId,
    required String careRecipientId,
  }) async {
    final token = await getIdToken();
    final res = await http.get(
      Uri.parse('${_base(householdId, careRecipientId)}/tasks'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Could not load reminders: ${res.body}');
    return ((jsonDecode(res.body) as Map<String, dynamic>)['tasks'] as List)
        .map((t) => Reminder.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete({
    required String householdId,
    required String careRecipientId,
    required String taskId,
  }) async {
    final token = await getIdToken();
    final res = await http.delete(
      Uri.parse('${_base(householdId, careRecipientId)}/tasks/$taskId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Could not remove the reminder: ${res.body}');
  }

  /// Generates today's occurrences and returns the full list in one call —
  /// same single-round-trip pattern as the medication schedule.
  Future<List<ReminderEvent>> todaysEvents({
    required String householdId,
    required String careRecipientId,
  }) async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse('${_base(householdId, careRecipientId)}/task-events/generate-today'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    if (res.statusCode != 200) throw Exception('Could not load today\'s reminders: ${res.body}');
    return ((jsonDecode(res.body) as Map<String, dynamic>)['events'] as List)
        .map((e) => ReminderEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Completing a reminder. When [answers] are present the server records
  /// them as an observation feeding the same trend charts as the voice log.
  Future<void> complete({
    required String householdId,
    required String careRecipientId,
    required String eventId,
    Map<String, String> answers = const {},
    String? note,
    String status = 'completed',
  }) async {
    final token = await getIdToken();
    final res = await http.post(
      Uri.parse('${_base(householdId, careRecipientId)}/task-events/$eventId/complete'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status,
        if (answers.isNotEmpty) 'answers': answers,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'locale': demoLocale,
      }),
    );
    if (res.statusCode != 200) throw Exception('Could not save: ${res.body}');
  }
}
