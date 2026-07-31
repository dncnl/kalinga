import 'package:flutter/material.dart';

import '../services/reminder_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';
import '../widgets/back_button.dart';

/// F2 · Reminders for one care recipient (`/patients/:id/schedules`).
///
/// Replaces the hardcoded schedule list that used to live here. Every
/// reminder is scoped to the selected elder (F0) and stored as a `task`
/// with its occurrences materialized as `taskEvents` — the same pair the
/// medication reminders already use, not a new data model.
class RemindersPage extends StatefulWidget {
  final String patientId;
  const RemindersPage({super.key, required this.patientId});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  static const _red = Color(0xFFEF3E23);

  final _service = const ReminderService();
  late Future<List<Reminder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Reminder>> _load() async {
    final profile = SelectedProfile.instance;
    await profile.ready;
    final householdId = profile.householdId;
    if (householdId == null) throw Exception('No household yet');
    return _service.list(householdId: householdId, careRecipientId: widget.patientId);
  }

  // Block body, not an arrow: `setState(() => _future = _load())` returns
  // the assigned Future out of the lambda, which Flutter rejects at runtime
  // ("setState() callback argument returned a Future").
  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _delete(Reminder reminder) async {
    final householdId = SelectedProfile.instance.householdId;
    if (householdId == null) return;
    try {
      await _service.delete(
        householdId: householdId,
        careRecipientId: widget.patientId,
        taskId: reminder.id,
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove it. Try again.')),
      );
    }
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddReminderSheet(patientId: widget.patientId),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final name = SelectedProfile.instance.careRecipient?.displayName ?? 'her';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            const AppBackButton(),
            const SizedBox(height: 16),
            Text('Reminders', style: AppTextStyles.heading(fontSize: 32).copyWith(color: Colors.black)),
            const SizedBox(height: 6),
            Text('For $name. You will be asked how it went.',
                style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Reminder>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(onRetry: _reload);
                  }
                  final reminders = snapshot.data ?? const [];
                  if (reminders.isEmpty) {
                    return _EmptyState(onAdd: _add);
                  }
                  return ListView.separated(
                    itemCount: reminders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ReminderCard(
                      reminder: reminders[i],
                      onDelete: () => _delete(reminders[i]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text('Add a reminder',
                    style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onDelete;

  const _ReminderCard({required this.reminder, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reminder.title, style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
          const SizedBox(height: 2),
          Text(reminder.times.join('  ·  '),
              style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600)),
        ])),
        IconButton(
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade500, size: 22),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.alarm_outlined, size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 14),
        Text('No reminders yet.',
            style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
        const SizedBox(height: 6),
        Text('Add one for eating, exercise, or anything\nyou need to remember.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500, height: 1.5)),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded, size: 36, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('Could not load reminders.',
            style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
        const SizedBox(height: 4),
        Text('Check your connection.',
            style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500)),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ]),
    );
  }
}

// ── Add sheet ───────────────────────────────────────────────────────────────

class _AddReminderSheet extends StatefulWidget {
  final String patientId;
  const _AddReminderSheet({required this.patientId});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _service = const ReminderService();
  final _customTitleController = TextEditingController();
  ReminderLabel _label = kReminderLabels.first;
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _customTitleController.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(context: context, initialTime: _times[index]);
    if (picked != null) setState(() => _times[index] = picked);
  }

  Future<void> _save() async {
    final title = _label.custom ? _customTitleController.text.trim() : _label.label;
    if (title.isEmpty) {
      setState(() => _error = 'Give the reminder a name.');
      return;
    }

    final profile = SelectedProfile.instance;
    final householdId = profile.householdId;
    if (householdId == null) {
      setState(() => _error = 'No household yet. Try again in a moment.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.create(
        householdId: householdId,
        careRecipientId: widget.patientId,
        title: title,
        category: _label.category,
        times: _times.map(_fmt).toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save it. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('New reminder', style: AppTextStyles.heading(fontSize: 24).copyWith(color: Colors.black)),
        const SizedBox(height: 16),

        Text('What is it for?', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final label in kReminderLabels)
            GestureDetector(
              onTap: () => setState(() => _label = label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _label == label ? Colors.black87 : Colors.white,
                  border: Border.all(color: _label == label ? Colors.black87 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(label.label,
                    style: AppTextStyles.bodyMedium(fontSize: 14)
                        .copyWith(color: _label == label ? Colors.white : Colors.black87)),
              ),
            ),
        ]),

        if (_label.custom) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _customTitleController,
            style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'e.g. Change position in bed',
              hintStyle: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _teal, width: 1.5)),
            ),
          ),
        ],

        const SizedBox(height: 20),
        Text('What time?', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < _times.length; i++)
            GestureDetector(
              onTap: () => _pickTime(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_fmt(_times[i]),
                      style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                  if (_times.length > 1) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _times.removeAt(i)),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade600),
                    ),
                  ],
                ]),
              ),
            ),
          GestureDetector(
            onTap: () => setState(() => _times.add(const TimeOfDay(hour: 12, minute: 0))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 16),
                const SizedBox(width: 4),
                Text('Add time', style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(color: Colors.black87)),
              ]),
            ),
          ),
        ]),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: AppTextStyles.body(fontSize: 13).copyWith(color: _red)),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _red.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text('Save reminder',
                    style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
