const { Router } = require('express');

const { requireAuth } = require('../middleware/auth');
const { isCaregiverAssigned } = require('../lib/authorizeCaregiver');
const { computeAndSaveDailySummary } = require('../lib/rollupDailySummary');
const { computeAndSaveWeeklySummary } = require('../lib/rollupWeeklySummary');

const router = Router();

// No scheduler wired up yet (see PLAN.md) — these are called on demand for
// now, gated the same way every other household-scoped route is.
router.post(
  '/households/:householdId/care-recipients/:careRecipientId/rollup/daily',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { dateKey } = req.body || {};

    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey || '')) {
      return res.status(400).json({ error: 'dateKey must be an ISO date, e.g. "2026-07-29"' });
    }

    const assigned = await isCaregiverAssigned({ householdId, careRecipientId, uid: req.uid });
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }

    const doc = await computeAndSaveDailySummary({ householdId, careRecipientId, dateKey });
    res.json(doc);
  },
);

router.post(
  '/households/:householdId/care-recipients/:careRecipientId/rollup/weekly',
  requireAuth,
  async (req, res) => {
    const { householdId, careRecipientId } = req.params;
    const { weekKey, periodStart } = req.body || {};

    if (!weekKey || !periodStart) {
      return res.status(400).json({ error: 'weekKey and periodStart are required' });
    }

    const assigned = await isCaregiverAssigned({ householdId, careRecipientId, uid: req.uid });
    if (!assigned) {
      return res.status(403).json({ error: 'Not an active caregiver for this care recipient' });
    }

    const doc = await computeAndSaveWeeklySummary({ householdId, careRecipientId, weekKey, periodStart });
    res.json(doc);
  },
);

module.exports = router;
