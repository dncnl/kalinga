const { test } = require('node:test');
const assert = require('node:assert/strict');

const { slugify, slugId, timestampId } = require('../../src/lib/readableId');

test('slugify lowercases, hyphenates, and trims', () => {
  assert.equal(slugify('Lola Nenas'), 'lola-nenas');
  assert.equal(slugify('  Amoxil 125mg/5mL  '), 'amoxil-125mg-5ml');
  assert.equal(slugify("Mr. O'Brien"), 'mr-o-brien');
});

test('slugify falls back to "untitled" for empty/symbols-only input', () => {
  assert.equal(slugify(''), 'untitled');
  assert.equal(slugify('!!!'), 'untitled');
});

test('slugId appends a short random suffix, distinct across calls', () => {
  const a = slugId('Lola Nenas');
  const b = slugId('Lola Nenas');
  assert.match(a, /^lola-nenas-[a-z0-9]{4}$/);
  assert.notEqual(a, b, 'two care recipients named the same thing must not collide');
});

test('timestampId is chronologically sortable and Firestore/URL-path safe', () => {
  const id1 = timestampId(new Date('2026-07-30T16:29:24.123Z'));
  const id2 = timestampId(new Date('2026-07-30T16:29:25.000Z'));
  assert.ok(id1.startsWith('2026-07-30T16-29-24-123'), id1);
  assert.ok(!id1.includes(':') && !id1.includes('.'));
  assert.ok(id1 < id2, 'later timestamps must sort after earlier ones lexicographically');
});

test('timestampId suffix guards against same-millisecond collisions', () => {
  const now = new Date();
  const a = timestampId(now);
  const b = timestampId(now);
  assert.notEqual(a, b);
});
