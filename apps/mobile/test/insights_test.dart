import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/insights.dart';

/// These guard the rule that matters most: this text appears on a care
/// record, so it must never claim a trend that the data does not support.

Map<String, dynamic> summaryWith({
  List<double>? food,
  List<double>? sleep,
  List<double>? mood,
}) =>
    {
      'trendSeries': {
        if (food != null) 'food': food,
        if (sleep != null) 'sleep': sleep,
        if (mood != null) 'mood': mood,
      },
    };

void main() {
  test('says nothing when there is no summary at all', () {
    expect(deriveInsights(null), isEmpty);
    expect(deriveInsights({}), isEmpty);
  });

  test('days with no observations are not read as average', () {
    // 0.5 is the rollup's no-data default. A week of silence must produce
    // no claims whatsoever.
    expect(deriveInsights(summaryWith(food: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5])), isEmpty);
  });

  test('too few real days produces nothing', () {
    // Three real days either side of a big drop is still not enough.
    expect(deriveInsights(summaryWith(food: [0.9, 0.9, 0.1, 0.5, 0.5, 0.5, 0.5])), isEmpty);
  });

  test('a small wobble is not reported as a trend', () {
    final insights = deriveInsights(summaryWith(food: [0.60, 0.58, 0.62, 0.57, 0.59, 0.61]));
    expect(insights, isEmpty);
  });

  test('a real decline in eating is reported as a concern', () {
    final insights = deriveInsights(summaryWith(food: [0.9, 0.85, 0.8, 0.3, 0.25, 0.2]));
    expect(insights, hasLength(1));
    expect(insights.single.isConcern, isTrue);
    expect(insights.single.text, contains('eating less'));
  });

  test('a real improvement is reported too, not just bad news', () {
    final insights = deriveInsights(summaryWith(sleep: [0.2, 0.25, 0.3, 0.8, 0.85, 0.9]));
    expect(insights, hasLength(1));
    expect(insights.single.isConcern, isFalse);
    expect(insights.single.text, contains('sleeping better'));
  });

  test('concerns are listed before good news', () {
    final insights = deriveInsights(summaryWith(
      food: [0.2, 0.25, 0.3, 0.8, 0.85, 0.9], // improving
      mood: [0.9, 0.85, 0.8, 0.2, 0.25, 0.3], // declining
    ));
    expect(insights, hasLength(2));
    expect(insights.first.isConcern, isTrue);
    expect(insights.last.isConcern, isFalse);
  });

  test('insights never diagnose', () {
    final insights = deriveInsights(summaryWith(
      food: [0.9, 0.85, 0.8, 0.1, 0.1, 0.15],
      sleep: [0.9, 0.85, 0.8, 0.1, 0.1, 0.15],
      mood: [0.9, 0.85, 0.8, 0.1, 0.1, 0.15],
    ));
    expect(insights, isNotEmpty);
    for (final insight in insights) {
      for (final word in ['dehydrat', 'infection', 'depress', 'diagnos', 'disease']) {
        expect(insight.text.toLowerCase(), isNot(contains(word)));
      }
    }
  });
}
