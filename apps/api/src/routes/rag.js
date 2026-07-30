const { Router } = require('express');

const { requireAuth } = require('../middleware/auth');
const { answerQuestion } = require('../rag/answer');

const router = Router();

// Not household-scoped — this is shared reference knowledge (health
// authority guidelines), not care-record data — so just requireAuth (stop
// anonymous abuse of the LLM call), no assignment check.
router.post('/rag/ask', requireAuth, async (req, res) => {
  const { question } = req.body || {};

  if (!question || typeof question !== 'string' || !question.trim()) {
    return res.status(400).json({ error: 'question is required' });
  }

  try {
    const result = await answerQuestion(question.trim());
    res.json(result);
  } catch (err) {
    console.error('rag ask failed:', err);
    res.status(502).json({ error: 'Failed to answer question', detail: err.message });
  }
});

module.exports = router;
