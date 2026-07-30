import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/profile_service.dart';
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

  @override
  void initState() {
    super.initState();
    _dataFuture = _resolve();
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

        // ── Alert card ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3C4),
            border: Border.all(color: _amber, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle),
              child: const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('睡眠時間下降', style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
              const SizedBox(height: 4),
              Text('三天平均少一小時。照顧者已回報膝蓋疼痛。',
                  style: AppTextStyles.body(fontSize: 13).copyWith(color: Colors.grey.shade700, height: 1.5)),
            ])),
          ]),
        ),

        const SizedBox(height: 24),

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

        // ── Back button ─────────────────────────────────────────────
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
