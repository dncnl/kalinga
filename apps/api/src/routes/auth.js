const express = require('express');
const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');
const { verifyToken } = require('../middleware/auth');
const { registerSchema } = require('../validators/auth');

const router = express.Router();

router.post('/register', verifyToken, async (req, res) => {
  try {
    // 1. Validate request body
    const validationResult = registerSchema.safeParse(req.body);
    if (!validationResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: validationResult.error.flatten()
      });
    }

    const { displayName, householdName } = validationResult.data;
    const { uid, email } = req.user;

    // 2. Idempotency Check
    const userDocRef = db.collection('users').doc(uid);
    const userSnapshot = await userDocRef.get();
    
    if (userSnapshot.exists) {
      return res.status(409).json({ error: 'User already registered' });
    }

    // 3. Prepare Batch Write
    const batch = db.batch();
    const now = FieldValue.serverTimestamp();

    // Document A: /users/{uid}
    batch.set(userDocRef, {
      uid,
      email,
      displayName,
      createdAt: now,
      updatedAt: now
    });

    // Document B: /households/{householdId}
    const householdDocRef = db.collection('households').doc();
    const householdId = householdDocRef.id;

    batch.set(householdDocRef, {
      householdId,
      name: householdName,
      createdByUid: uid,
      status: 'active',
      createdAt: now,
      updatedAt: now
    });

    // Document C: /households/{householdId}/members/{uid}
    const memberDocRef = db
      .collection('households')
      .doc(householdId)
      .collection('members')
      .doc(uid);

    batch.set(memberDocRef, {
      uid,
      email,
      displayName,
      role: 'householdAdmin',
      status: 'active',
      joinedAt: now
    });

    // 4. Commit batch
    await batch.commit();

    return res.status(201).json({
      uid,
      householdId
    });

  } catch (error) {
    console.error('Error during registration endpoint processing:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
