/// Week key convention shared between the mobile app and apps/api.
///
/// apps/api's rollup endpoints accept whatever weekKey/periodStart string
/// the caller sends — nothing server-side enforces true ISO week numbers
/// (the schema's "ISOWeek" doc-id strategy is just a naming hint). To avoid
/// ISO week-number/year-boundary edge cases, this uses a simpler
/// "week starting most recent Sunday, UTC" convention instead. Both the
/// write (rollup trigger) and read (chart) sides must use this same
/// function or they'll disagree on which doc to look at.
library;

DateTime currentWeekStartUtc([DateTime? now]) {
  final n = (now ?? DateTime.now()).toUtc();
  final dateOnly = DateTime.utc(n.year, n.month, n.day);
  // DateTime.weekday: Monday=1 ... Sunday=7. Sunday % 7 == 0, so this walks
  // back to the most recent Sunday (or stays put if today is Sunday).
  return dateOnly.subtract(Duration(days: dateOnly.weekday % 7));
}

String dateKeyOf(DateTime d) {
  final utc = d.toUtc();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}-${pad(utc.month)}-${pad(utc.day)}';
}

String currentWeekKey([DateTime? now]) => 'week-${dateKeyOf(currentWeekStartUtc(now))}';
