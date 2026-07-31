import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../insights.dart';
import '../services/profile_service.dart';
import '../state/selected_profile.dart';
import '../theme.dart';
import '../week_key.dart';

/// F5 · "Must remember" — the standing facts a caregiver should never have
/// to hold in her head, and that a replacement caregiver would otherwise
/// never learn: an allergy, a DNR, a hearing aid, a trigger, a preference.
///
/// Human-entered only. Nothing here is model-generated, because this is the
/// part of the record where being confidently wrong is most dangerous.
class MustRememberSection extends StatefulWidget {
  final CareRecipient recipient;
  const MustRememberSection({super.key, required this.recipient});

  @override
  State<MustRememberSection> createState() => _MustRememberSectionState();
}

class _MustRememberSectionState extends State<MustRememberSection> {
  static const _amber = Color(0xFFFBBF24);
  static const _red = Color(0xFFEF3E23);

  final _service = const ProfileService();
  bool _saving = false;

  Future<void> _persist(List<MustRememberItem> items) async {
    final householdId = SelectedProfile.instance.householdId;
    if (householdId == null) return;

    setState(() => _saving = true);
    try {
      await _service.updateMustRemember(householdId, widget.recipient.id, items);
      // Re-read so the rest of the app sees the change too — this list is
      // owned by SelectedProfile, not by this widget.
      await SelectedProfile.instance.initialize();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final item = await showModalBottomSheet<MustRememberItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddMustRememberSheet(),
    );
    if (item == null) return;
    await _persist([...widget.recipient.mustRemember, item]);
  }

  Future<void> _remove(int index) async {
    final items = [...widget.recipient.mustRemember]..removeAt(index);
    await _persist(items);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.recipient.mustRemember;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('MUST REMEMBER',
            style: AppTextStyles.bodyMedium(fontSize: 11)
                .copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
        if (_saving)
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
        else
          GestureDetector(
            onTap: _add,
            child: Text('Add', style: AppTextStyles.bodyMedium(fontSize: 12).copyWith(color: _red)),
          ),
      ]),
      const SizedBox(height: 10),

      if (items.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Allergies, medical wishes, things that upset her, things she likes.\n'
            'Anything the next caregiver would need to know.',
            style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500, height: 1.5),
          ),
        )
      else
        ...List.generate(items.length, (i) {
          final item = items[i];
          // Allergies and directives are the two that can hurt someone if
          // missed, so they carry the warning colour; the rest stay calm.
          final isCritical = item.category == 'allergy' || item.category == 'directive';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isCritical ? const Color(0xFFFFF8E1) : Colors.white,
                border: Border.all(color: isCritical ? _amber : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kMustRememberCategories[item.category] ?? 'Other',
                      style: AppTextStyles.bodyMedium(fontSize: 11)
                          .copyWith(color: Colors.grey.shade600, letterSpacing: 0.5)),
                  const SizedBox(height: 3),
                  Text(item.text,
                      style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                ])),
                IconButton(
                  onPressed: _saving ? null : () => _remove(i),
                  icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
          );
        }),
    ]);
  }
}

class _AddMustRememberSheet extends StatefulWidget {
  const _AddMustRememberSheet();

  @override
  State<_AddMustRememberSheet> createState() => _AddMustRememberSheetState();
}

class _AddMustRememberSheetState extends State<_AddMustRememberSheet> {
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  final _controller = TextEditingController();
  String _category = 'allergy';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Must remember', style: AppTextStyles.heading(fontSize: 24).copyWith(color: Colors.black)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in kMustRememberCategories.entries)
            GestureDetector(
              onTap: () => setState(() => _category = entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _category == entry.key ? Colors.black87 : Colors.white,
                  border: Border.all(color: _category == entry.key ? Colors.black87 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(entry.value,
                    style: AppTextStyles.bodyMedium(fontSize: 14)
                        .copyWith(color: _category == entry.key ? Colors.white : Colors.black87)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          maxLines: 2,
          style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'e.g. Allergic to peanuts',
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
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop(MustRememberItem(category: _category, text: text));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 0,
            ),
            child: Text('Save', style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

/// F5 · Auto-surfaced insights, read from the weekly rollup that already
/// exists. No new analytics: this streams the same `weeklySummaries` doc the
/// trend chart and the family viewer read, and [deriveInsights] turns it
/// into sentences. See insights.dart for the honesty rules.
class InsightsSection extends StatelessWidget {
  final String careRecipientId;
  const InsightsSection({super.key, required this.careRecipientId});

  static const _amber = Color(0xFFFBBF24);
  static const _teal = Color(0xFF2BBFB3);

  @override
  Widget build(BuildContext context) {
    final householdId = SelectedProfile.instance.householdId;
    if (householdId == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('WHAT WE ARE NOTICING',
          style: AppTextStyles.bodyMedium(fontSize: 11)
              .copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
      const SizedBox(height: 10),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .doc('households/$householdId/careRecipients/$careRecipientId/weeklySummaries/${currentWeekKey()}')
            .snapshots(),
        builder: (context, snapshot) {
          final insights = deriveInsights(snapshot.data?.data());

          if (insights.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(14),
              ),
              // Says "not enough yet", never "everything is fine" — the
              // second would be a claim the data doesn't support.
              child: Text('Not enough logs yet to see a pattern. Keep logging each day.',
                  style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500, height: 1.5)),
            );
          }

          return Column(
            children: insights
                .map((insight) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: insight.isConcern ? const Color(0xFFFFF8E1) : const Color(0xFFE6F7F5),
                          border: Border.all(color: insight.isConcern ? _amber : _teal),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Icon(
                            insight.isConcern
                                ? Icons.trending_down_rounded
                                : Icons.trending_up_rounded,
                            size: 20,
                            color: insight.isConcern ? const Color(0xFFB45309) : _teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(insight.text,
                                style: AppTextStyles.body(fontSize: 14)
                                    .copyWith(color: Colors.black87, height: 1.4)),
                          ),
                        ]),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    ]);
  }
}
