import 'package:flutter/material.dart';
import '../theme.dart';

/// Read-only family/doctor view — separate surface, all text in Mandarin.
class ViewerPage extends StatelessWidget {
  final String viewerId;
  const ViewerPage({super.key, required this.viewerId});

  static const _amber = Color(0xFFFBBF24);
  static const _teal  = Color(0xFF2BBFB3);

  static const _sleepData = [0.7, 0.9, 0.6, 0.8, 0.7, 0.5, 0.75];
  static const _foodData  = [0.5, 0.8, 0.4, 0.6, 0.3, 0.7, 0.5];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
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
                    style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(
                        color: Colors.grey.shade500, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text('Family and doctor see this in Mandarin. They\ncannot edit or write.',
                    style: AppTextStyles.body(fontSize: 13).copyWith(
                        color: Colors.grey.shade600, height: 1.4)),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Chinese title ───────────────────────────────────────────
            Text('羅莎奶奶・本週',
                style: AppTextStyles.heading(fontSize: 28).copyWith(color: Colors.black)),

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
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle),
                  child: const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('睡眠時間下降',
                      style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('三天平均少一小時。照顧者已回報膝蓋疼痛。',
                      style: AppTextStyles.body(fontSize: 13).copyWith(
                          color: Colors.grey.shade700, height: 1.5)),
                ])),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Charts ──────────────────────────────────────────────────
            _ChartRowZh(label: '睡眠', unit: '小時', value: '6', data: _sleepData, color: _amber),
            const SizedBox(height: 14),
            _ChartRowZh(label: '進食', unit: '比例', value: '0.5', data: _foodData, color: _teal),

            const SizedBox(height: 32),

            // ── Back button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text('Back to caregiver app',
                    style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(color: Colors.black87)),
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
        ),
      ),
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
      Expanded(child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (i) {
          final isLast = i == data.length - 1;
          return Expanded(child: Padding(
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
