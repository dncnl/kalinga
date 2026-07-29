const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../src/app');

test('GET /health returns ok status', async () => {
  const res = await request(app).get('/health');

  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { status: 'ok' });
});
