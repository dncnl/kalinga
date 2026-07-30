// Mirrors apps/mobile/lib/week_key.dart exactly — both the write side
// (here, now that the background observation job triggers its own rollup)
// and the read side (the chart, still computing this client-side) must
// agree on which weeklySummaries doc a given date belongs to.
//
// "Week starting most recent Sunday, UTC" — not a true ISO week number, by
// design (see week_key.dart for why).

function currentWeekStartUtc(now = new Date()) {
  const n = new Date(now);
  const dateOnly = new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()));
  const day = dateOnly.getUTCDay(); // Sunday=0 ... Saturday=6
  dateOnly.setUTCDate(dateOnly.getUTCDate() - day);
  return dateOnly;
}

function dateKeyOf(d) {
  return d.toISOString().slice(0, 10);
}

function currentWeekKey(now = new Date()) {
  return `week-${dateKeyOf(currentWeekStartUtc(now))}`;
}

module.exports = { currentWeekStartUtc, dateKeyOf, currentWeekKey };
