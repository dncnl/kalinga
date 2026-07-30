const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const firebase = require('../../src/firebase');
const app = require('../../src/app');

const BASE = '/households/h1/care-recipients/r1';

function mockAuthedUser(t, uid) {
  t.mock.method(firebase.auth, 'verifyIdToken', async () => ({ uid }));
}

function mockAssignment(t, data) {
  t.mock.method(firebase.db, 'doc', () => ({
    get: async () => ({ exists: data !== null, data: () => data }),
    set: async () => {},
  }));
}

// ── Manual entry CRUD ───────────────────────────────────────────────────────

test('POST /medications rejects requests with no auth token', async () => {
  const res = await request(app).post(`${BASE}/medications`).send({ name: 'x', dosageText: 'x' });
  assert.equal(res.status, 401);
});

test('POST /medications rejects a caregiver with no active assignment', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, null);

  const res = await request(app)
    .post(`${BASE}/medications`)
    .set('Authorization', 'Bearer token')
    .send({ name: 'Amlodipine', dosageText: '1 tablet · 5 mg' });

  assert.equal(res.status, 403);
});

test('POST /medications rejects a missing name/dosageText', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  const res = await request(app)
    .post(`${BASE}/medications`)
    .set('Authorization', 'Bearer token')
    .send({ name: 'Amlodipine' });

  assert.equal(res.status, 400);
});

test('POST /medications creates a familyEntry medication already confirmed', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  let saved;
  t.mock.method(firebase.db, 'collection', () => ({
    doc: () => ({ id: 'med-1', set: async (data) => { saved = data; } }),
  }));

  const res = await request(app)
    .post(`${BASE}/medications`)
    .set('Authorization', 'Bearer token')
    .send({ name: 'Amlodipine', dosageText: '1 tablet · 5 mg · 09:00' });

  assert.equal(res.status, 200);
  assert.equal(res.body.medicationId, 'med-1');
  assert.equal(saved.sourceType, 'familyEntry');
  assert.equal(saved.verificationStatus, 'familyConfirmed');
  assert.equal(saved.name, 'Amlodipine');
});

test('GET /medications lists only active medications', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) }));
  t.mock.method(firebase.db, 'collection', () => ({
    where: () => ({
      get: async () => ({
        docs: [{ id: 'med-1', data: () => ({ name: 'Amlodipine', status: 'active' }) }],
      }),
    }),
  }));

  const res = await request(app).get(`${BASE}/medications`).set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.medications.length, 1);
  assert.equal(res.body.medications[0].id, 'med-1');
});

test('PATCH /medications/:id 404s when the medication does not exist', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return { get: async () => ({ exists: false }) };
  });

  const res = await request(app)
    .patch(`${BASE}/medications/med-1`)
    .set('Authorization', 'Bearer token')
    .send({ name: 'New name' });

  assert.equal(res.status, 404);
});

test('DELETE /medications/:id soft-deletes with status cancelled', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  let updated;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return {
      get: async () => ({ exists: true }),
      update: async (data) => { updated = data; },
    };
  });

  const res = await request(app).delete(`${BASE}/medications/med-1`).set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(updated.status, 'cancelled');
  assert.equal(updated.deletedBy, 'caregiver-1');
});

// ── Photo scan ───────────────────────────────────────────────────────────────

test('POST /medications/upload-url rejects an unsupported content type', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  const res = await request(app)
    .post(`${BASE}/medications/upload-url`)
    .set('Authorization', 'Bearer token')
    .send({ contentType: 'video/mp4' });

  assert.equal(res.status, 400);
});

test('POST /medications/upload-url returns a signed write URL', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockAssignment(t, { status: 'active' });

  t.mock.method(firebase.db, 'collection', () => ({ doc: () => ({ id: 'med-1' }) }));
  t.mock.method(firebase, 'getBucket', () => ({
    file: (path) => ({
      getSignedUrl: async (opts) => {
        assert.equal(opts.action, 'write');
        return [`https://signed.example.com/write?path=${path}`];
      },
    }),
  }));

  const res = await request(app)
    .post(`${BASE}/medications/upload-url`)
    .set('Authorization', 'Bearer token')
    .send({ contentType: 'image/jpeg' });

  assert.equal(res.status, 200);
  assert.equal(res.body.medicationId, 'med-1');
  assert.match(res.body.uploadUrl, /^https:\/\/signed\.example\.com\/write/);
});

function mockVisionSuccess(t, draftOverrides = {}) {
  t.mock.method(firebase, 'getBucket', () => ({
    file: () => ({ getSignedUrl: async () => ['https://signed.example.com/read'] }),
  }));
  t.mock.method(global, 'fetch', async () => ({
    ok: true,
    json: async () => ({
      choices: [
        {
          message: {
            content: JSON.stringify({
              name: 'Metformin',
              strength: '500 mg',
              dosageText: '2 tablets twice daily',
              route: 'oral',
              specialInstructions: 'take with food',
              times: ['08:00', '20:00'],
              confidence: 'high',
              ...draftOverrides,
            }),
          },
        },
      ],
    }),
  }));
}

test('POST /medications/:id/process 404s when no upload was recorded', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return { get: async () => ({ exists: false }) };
  });

  const res = await request(app)
    .post(`${BASE}/medications/med-1/process`)
    .set('Authorization', 'Bearer token')
    .send({});

  assert.equal(res.status, 404);
});

test('POST /medications/:id/process saves an unverified labelOcrDraft', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  mockVisionSuccess(t);

  let saved;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return {
      get: async () => ({ exists: true, data: () => ({ status: 'pendingUpload', photoExtension: 'jpg' }) }),
      set: async (data) => { saved = data; },
    };
  });

  const res = await request(app)
    .post(`${BASE}/medications/med-1/process`)
    .set('Authorization', 'Bearer token')
    .send({});

  assert.equal(res.status, 200);
  assert.equal(res.body.medicationId, 'med-1');
  assert.equal(res.body.draft.name, 'Metformin');

  assert.equal(saved.sourceType, 'labelOcrDraft');
  assert.equal(saved.verificationStatus, 'unverified');
  assert.equal(saved.verifiedByUid, null);
  assert.equal(saved.name, 'Metformin');
  assert.deepEqual(saved.schedule.times, ['08:00', '20:00']);
  assert.equal(saved.ocrDraft.confidence, 'high');
  assert.equal(
    saved.sourceDocumentAssetId,
    'households/h1/careRecipients/r1/medications/med-1/label.jpg',
  );
});

test('POST /medications/:id/process returns 502 when every vision model fails', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return { get: async () => ({ exists: true, data: () => ({ status: 'pendingUpload', photoExtension: 'jpg' }) }) };
  });
  t.mock.method(firebase, 'getBucket', () => ({
    file: () => ({ getSignedUrl: async () => ['https://signed.example.com/read'] }),
  }));
  t.mock.method(global, 'fetch', async () => ({ ok: false, status: 429, text: async () => 'rate limited' }));

  const res = await request(app)
    .post(`${BASE}/medications/med-1/process`)
    .set('Authorization', 'Bearer token')
    .send({});

  assert.equal(res.status, 502);
});

// ── Confirm ──────────────────────────────────────────────────────────────────

test('POST /medications/:id/confirm flips verificationStatus to familyConfirmed', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  let updated;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return {
      get: async () => ({ exists: true }),
      update: async (data) => { updated = data; },
    };
  });

  const res = await request(app)
    .post(`${BASE}/medications/med-1/confirm`)
    .set('Authorization', 'Bearer token')
    .send({ dosageText: '2 tablets twice daily with food' });

  assert.equal(res.status, 200);
  assert.equal(updated.verificationStatus, 'familyConfirmed');
  assert.equal(updated.verifiedByUid, 'caregiver-1');
  assert.equal(updated.dosageText, '2 tablets twice daily with food');
});

test('POST /medications/:id/confirm 404s when the medication does not exist', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return { get: async () => ({ exists: false }) };
  });

  const res = await request(app)
    .post(`${BASE}/medications/med-1/confirm`)
    .set('Authorization', 'Bearer token')
    .send({});

  assert.equal(res.status, 404);
});

// ── Medication events ────────────────────────────────────────────────────────

test('POST /medication-events/generate-today only creates events for confirmed medications not already scheduled', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  const created = [];
  t.mock.method(firebase.db, 'doc', (path) => ({
    get: async () => ({ exists: true, data: () => ({ status: 'active' }) }),
  }));
  t.mock.method(firebase.db, 'collection', (path) => {
    if (path.endsWith('/medications')) {
      return {
        where: () => ({
          get: async () => ({
            docs: [
              {
                id: 'med-1',
                data: () => ({ schedule: { times: ['08:00', '20:00'] }, verificationStatus: 'familyConfirmed' }),
              },
            ],
          }),
        }),
      };
    }
    return {
      where: () => ({
        where: () => ({
          get: async () => ({
            docs: [
              {
                id: 'evt-existing',
                data: () => ({ medicationId: 'med-1', scheduledAt: { toDate: () => new Date(`${new Date().toISOString().slice(0, 10)}T08:00:00.000Z`) } }),
              },
            ],
          }),
        }),
      }),
      doc: () => ({ id: 'evt-new' }),
    };
  });
  t.mock.method(firebase.db, 'batch', () => ({
    set: (ref, data) => created.push(data),
    commit: async () => {},
  }));

  const res = await request(app)
    .post(`${BASE}/medication-events/generate-today`)
    .set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  // 08:00 already has an event today; only 20:00 should be newly created.
  assert.equal(res.body.created, 1);
  assert.equal(created.length, 1);
  assert.equal(created[0].medicationId, 'med-1');
  assert.equal(created[0].status, 'scheduled');

  // The response includes the complete up-to-date event list (existing +
  // newly created) so the mobile client doesn't need a second GET call.
  assert.equal(res.body.events.length, 2);
  assert.ok(res.body.events.some((e) => e.id === 'evt-existing'));
  const newEvent = res.body.events.find((e) => e.id === 'evt-new');
  assert.ok(newEvent);
  assert.equal(newEvent.medicationId, 'med-1');
  assert.equal(typeof newEvent.scheduledAt, 'string');
});

test('GET /medication-events lists today\'s events', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) }));
  t.mock.method(firebase.db, 'collection', () => ({
    where: () => ({
      where: () => ({
        get: async () => ({
          docs: [{
            id: 'evt-1',
            data: () => ({ medicationId: 'med-1', status: 'scheduled', scheduledAt: { toDate: () => new Date('2026-07-30T08:00:00.000Z') } }),
          }],
        }),
      }),
    }),
  }));

  const res = await request(app).get(`${BASE}/medication-events`).set('Authorization', 'Bearer token');

  assert.equal(res.status, 200);
  assert.equal(res.body.events.length, 1);
  assert.equal(res.body.events[0].id, 'evt-1');
});

test('PATCH /medication-events/:id rejects an invalid status', async (t) => {
  mockAuthedUser(t, 'caregiver-1');
  t.mock.method(firebase.db, 'doc', () => ({ get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) }));

  const res = await request(app)
    .patch(`${BASE}/medication-events/evt-1`)
    .set('Authorization', 'Bearer token')
    .send({ status: 'bogus' });

  assert.equal(res.status, 400);
});

test('PATCH /medication-events/:id marks an event completed', async (t) => {
  mockAuthedUser(t, 'caregiver-1');

  let updated;
  t.mock.method(firebase.db, 'doc', (path) => {
    if (path.includes('/assignments/')) return { get: async () => ({ exists: true, data: () => ({ status: 'active' }) }) };
    return {
      get: async () => ({ exists: true }),
      update: async (data) => { updated = data; },
    };
  });

  const res = await request(app)
    .patch(`${BASE}/medication-events/evt-1`)
    .set('Authorization', 'Bearer token')
    .send({ status: 'completed' });

  assert.equal(res.status, 200);
  assert.equal(updated.status, 'completed');
  assert.equal(updated.completedByUid, 'caregiver-1');
});
