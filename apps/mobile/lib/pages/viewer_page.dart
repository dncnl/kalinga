import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/profile_service.dart';
import '../state/session_role.dart';
import '../theme.dart';
import '../week_key.dart';

/// Read-only family/doctor view — separate surface, all text in Mandarin.
/// Resolves the household from [viewerId] itself (via
/// ProfileService.resolveHouseholdForCareRecipient) rather than reading the
/// caregiver-only SelectedProfile singleton, so this renders correctly for
/// a real family member as well as for the caregiver's own "preview what
/// family sees" link.
class ViewerPage extends StatefulWidget {
  final String viewerId;
  const ViewerPage({super.key, required this.viewerId});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerData {
  final String householdId;
  final String displayName;
  const _ViewerData({required this.householdId, required this.displayName});
}

class _ViewerPageState extends State<ViewerPage> {
  static const _amber = Color(0xFFFBBF24);
  static const _teal = Color(0xFF2BBFB3);

  // Neutral placeholder while loading / before any data exists for the week.
  static const _neutralWeek = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];

  final _profileService = const ProfileService();
  late final Future<_ViewerData> _dataFuture;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _resolve();
  }

  // Family members have no other screen with a sign-out — the viewer is
  // their entire surface (see the footer-action comment below).
  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await SessionRole.instance.clear();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法登出，請再試一次 · Could not sign out. Try again.')),
      );
    }
  }

  Future<_ViewerData> _resolve() async {
    final householdId = await _profileService.resolveHouseholdForCareRecipient(widget.viewerId);
    final doc = await FirebaseFirestore.instance.doc('households/$householdId/careRecipients/${widget.viewerId}').get();
    final displayName = doc.data()?['displayName'] as String? ?? '';
    return _ViewerData(householdId: householdId, displayName: displayName);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _weeklySummaryStream(String householdId) {
    return FirebaseFirestore.instance
        .doc('households/$householdId/careRecipients/${widget.viewerId}/weeklySummaries/${currentWeekKey()}')
        .snapshots();
  }

  // The sleep/food bars above are the only thing this page showed for a
  // while — real, but just numbers. Every voice log, symptom check-in, and
  // chat exchange already carries a Mandarin translation of what was
  // actually said (translations['zh-TW'], written specifically for this
  // audience — see buildObservationDocument.js), and none of it reached
  // family until now.
  Stream<QuerySnapshot<Map<String, dynamic>>> _recentObservationsStream(String householdId) {
    return FirebaseFirestore.instance
        .collection('households/$householdId/careRecipients/${widget.viewerId}/observations')
        .where('status', isEqualTo: 'ready')
        .orderBy('observedAt', descending: true)
        .limit(8)
        .snapshots();
  }

  static List<double> _series(Map<String, dynamic>? trendSeries, String key) {
    final raw = trendSeries?[key] as List?;
    if (raw == null || raw.isEmpty) return _neutralWeek;
    return raw.map((v) => (v as num).toDouble()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: FutureBuilder<_ViewerData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _buildError(context);
            }
            return _buildContent(context, snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Couldn\'t load this record.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: const BorderSide(color: Colors.black87, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
            child: Text('Back', style: AppTextStyles.bodyMedium(fontSize: 15)),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _ViewerData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),

        // ── Read-only banner ────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SEPARATE SURFACE · READ ONLY',
                style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(color: Colors.grey.shade500, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text('Family and doctor see this in Mandarin. They\ncannot edit or write.',
                style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600, height: 1.4)),
          ]),
        ),

        const SizedBox(height: 28),

        // ── Chinese title ───────────────────────────────────────────
        // Not actually translated — showing the raw displayName here
        // rather than the old hardcoded "羅莎奶奶" is at least correct
        // per-profile, though a real Mandarin honorific/name would need
        // real translation, not just interpolation.
        Text('${data.displayName}・本週', style: AppTextStyles.heading(fontSize: 28).copyWith(color: Colors.black)),

        const SizedBox(height: 20),

        // No alert/insight card yet: the one that used to sit here was
        // hardcoded fixture text ("sleep declining… caregiver reported knee
        // pain") — fabricated medical claims on the family surface, exactly
        // what the "never alarm without cause" constraint forbids. F5 will
        // reintroduce it fed by real rollup data.

        // ── Charts ──────────────────────────────────────────────────
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _weeklySummaryStream(data.householdId),
          builder: (context, snapshot) {
            final trendSeries = snapshot.data?.data()?['trendSeries'] as Map<String, dynamic>?;
            final sleepData = _series(trendSeries, 'sleep');
            final foodData = _series(trendSeries, 'food');

            return Column(children: [
              _ChartRowZh(
                label: '睡眠',
                unit: '%',
                value: '${(sleepData.last * 100).round()}',
                data: sleepData,
                color: _amber,
              ),
              const SizedBox(height: 14),
              _ChartRowZh(
                label: '進食',
                unit: '%',
                value: '${(foodData.last * 100).round()}',
                data: foodData,
                color: _teal,
              ),
            ]);
          },
        ),

        const SizedBox(height: 32),

        // ── Recent notes, translated ───────────────────────────────
        Text('最新記錄', style: AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _recentObservationsStream(data.householdId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('本週還沒有記錄 · No records yet this week.',
                    style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade500)),
              );
            }
            return Column(
              children: [
                for (final doc in docs) ...[
                  _RecentNoteCard(data: doc.data()),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Footer action ───────────────────────────────────────────
        // Two different users land here: the caregiver previewing "what
        // family sees" (wants a way back into her app) and a real family
        // member (this IS their whole app — "back to caregiver app" would
        // be meaningless, and they need sign-out since no Settings screen
        // is reachable from here).
        if (SessionRole.instance.isFamily)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signingOut ? null : _signOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text('登出 · Sign out', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text('Back to caregiver app', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.black87, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _RecentNoteCard extends StatelessWidget {
  static const _red = Color(0xFFEF3E23);
  static const _amber = Color(0xFFD97706);

  final Map<String, dynamic> data;
  const _RecentNoteCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final translations = data['translations'] as Map<String, dynamic>?;
    final zhText = (translations?['zh-TW'] as Map<String, dynamic>?)?['text'] as String?;
    // A translation can fail (see routes/observations.js, routes/rag.js —
    // the record is still saved so nothing is lost) — this is the one
    // audience that can't read the untranslated original, so say so
    // plainly instead of showing English/Tagalog/etc. text as if it were
    // Mandarin.
    final text = (zhText != null && zhText.trim().isNotEmpty) ? zhText : '（翻譯失敗 · Translation unavailable）';

    final safety = data['safetyAssessment'] as Map<String, dynamic>?;
    final concernLevel = safety?['concernLevel'] as String?;
    final isUrgent = concernLevel == 'high' || concernLevel == 'medium';
    final urgentColor = concernLevel == 'high' ? _red : _amber;

    final observedAt = data['observedAt'];
    final date = observedAt is Timestamp ? observedAt.toDate() : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent ? urgentColor.withValues(alpha: 0.06) : Colors.grey.shade50,
        border: Border.all(color: isUrgent ? urgentColor.withValues(alpha: 0.4) : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isUrgent) ...[
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: urgentColor),
            const SizedBox(width: 6),
            Text(concernLevel == 'high' ? '緊急' : '請留意', style: AppTextStyles.bodyMedium(fontSize: 12).copyWith(color: urgentColor)),
          ]),
          const SizedBox(height: 6),
        ],
        Text(text, style: AppTextStyles.body(fontSize: 14).copyWith(color: Colors.black87, height: 1.5)),
        if (date != null) ...[
          const SizedBox(height: 8),
          Text(
            '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
            style: AppTextStyles.body(fontSize: 11).copyWith(color: Colors.grey.shade500),
          ),
        ],
      ]),
    );
  }
}

class _ChartRowZh extends StatelessWidget {
  final String label, unit, value;
  final List<double> data;
  final Color color;
  const _ChartRowZh({required this.label, required this.unit, required this.value, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      SizedBox(width: 36, child: Text(label, style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade600))),
      Expanded(
          child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (i) {
          final isLast = i == data.length - 1;
          return Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: 40 * data[i],
              decoration: BoxDecoration(
                color: isLast ? color : color.withValues(alpha: 0.35 + i * 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ));
        }),
      )),
      const SizedBox(width: 8),
      Text('$value$unit', style: AppTextStyles.body(fontSize: 12).copyWith(color: Colors.grey.shade600)),
    ]);
  }
}
