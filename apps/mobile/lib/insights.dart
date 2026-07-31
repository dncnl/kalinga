/// F5 · Insights derived from the rollups that already exist.
///
/// This is not an analytics system. It reads the `trendSeries` the weekly
/// rollup already writes (`{days, sleep, food, mood}`, each a 7-slot list of
/// 0..1 values) and states, in plain words, what a caregiver would see if
/// she stared at the chart.
///
/// Three rules keep it honest, because this text sits on a care record:
///
/// 1. **Never invent data.** The rollup writes a neutral 0.5 for days with
///    no observations (`NO_DATA_DEFAULT` in rollupWeeklySummary.js). Those
///    days are skipped, not read as "average" — otherwise a week with two
///    logs would produce confident trends about five days that never
///    happened.
/// 2. **Say nothing rather than something weak.** Fewer than
///    [_minDaysForTrend] real days, or a change smaller than
///    [_meaningfulDelta], produces no insight at all.
/// 3. **Describe, don't diagnose.** "Eating less than earlier this week",
///    never "possible dehydration".
library;

class Insight {
  /// 'concern' — worth telling the family. 'positive' — worth saying out
  /// loud, since a caregiver rarely hears that anything went right.
  final String tone;
  final String text;

  const Insight({required this.tone, required this.text});

  bool get isConcern => tone == 'concern';
}

const _noDataValue = 0.5;
const _minDaysForTrend = 4;

/// Below this, a change is noise. 0..1 scale, so 0.15 is a 15-point move.
const _meaningfulDelta = 0.15;

/// A day counts as real if it isn't exactly the rollup's no-data default.
/// Exact equality is correct here: a real average landing on precisely
/// 0.5000 is possible but rare, and treating that one day as missing is a
/// far cheaper mistake than treating five missing days as real.
bool _isRealDay(num value) => value != _noDataValue;

({double? earlier, double? recent, int days}) _split(List<double> series) {
  final real = series.where(_isRealDay).toList();
  if (real.length < _minDaysForTrend) return (earlier: null, recent: null, days: real.length);

  final half = real.length ~/ 2;
  final earlierPart = real.sublist(0, half);
  final recentPart = real.sublist(real.length - half);

  double mean(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
  return (earlier: mean(earlierPart), recent: mean(recentPart), days: real.length);
}

Insight? _trendFor({
  required List<double> series,
  required String fallingText,
  required String risingText,
}) {
  final split = _split(series);
  final earlier = split.earlier;
  final recent = split.recent;
  if (earlier == null || recent == null) return null;

  final delta = recent - earlier;
  if (delta.abs() < _meaningfulDelta) return null;

  return delta < 0
      ? Insight(tone: 'concern', text: fallingText)
      : Insight(tone: 'positive', text: risingText);
}

/// Reads a `weeklySummaries/{weekKey}` document's data and returns what is
/// worth saying. Empty list means "not enough to say anything yet", which
/// the UI should show as exactly that rather than as reassurance.
List<Insight> deriveInsights(Map<String, dynamic>? summary) {
  if (summary == null) return const [];

  final trend = summary['trendSeries'] as Map<String, dynamic>?;
  if (trend == null) return const [];

  List<double> series(String key) {
    final raw = trend[key] as List?;
    if (raw == null) return const [];
    return raw.map((v) => (v as num).toDouble()).toList();
  }

  final insights = <Insight>[];

  final food = _trendFor(
    series: series('food'),
    fallingText: 'She is eating less than earlier this week.',
    risingText: 'She is eating better than earlier this week.',
  );
  if (food != null) insights.add(food);

  final sleep = _trendFor(
    series: series('sleep'),
    fallingText: 'She is sleeping less well than earlier this week.',
    risingText: 'She is sleeping better than earlier this week.',
  );
  if (sleep != null) insights.add(sleep);

  final mood = _trendFor(
    series: series('mood'),
    fallingText: 'Her mood has been lower than earlier this week.',
    risingText: 'Her mood has been better than earlier this week.',
  );
  if (mood != null) insights.add(mood);

  // Concerns first: if there is one thing she reads, it should be the thing
  // that might need acting on.
  insights.sort((a, b) => (a.isConcern ? 0 : 1).compareTo(b.isConcern ? 0 : 1));
  return insights;
}
