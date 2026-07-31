const crypto = require('crypto');

function shortSuffix(len = 4) {
  return crypto.randomBytes(6).toString('base64url').replace(/[^a-z0-9]/gi, '').slice(0, len).toLowerCase();
}

function slugify(text) {
  const slug = String(text)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
  return slug || 'untitled';
}

// Readable, browsable Firestore document ids instead of opaque auto-ids —
// for "identity" documents (households, care recipients) that get looked
// up repeatedly by name in the Firebase console. A short random suffix
// avoids collisions between two documents that happen to slugify to the
// same text (e.g. two patients both named "Lola").
function slugId(text) {
  return `${slugify(text)}-${shortSuffix()}`;
}

// Readable and naturally chronologically sortable — for "event" documents
// (observations, medications, medication events, invitations) created many
// times per day, where "when was this" matters more than a human name.
// Firestore document ids technically allow ':' and '.', but both get
// replaced since these ids can also appear as URL path segments elsewhere
// in the API. The random suffix guards against two events created in the
// same millisecond (e.g. a double-tap).
function timestampId(date = new Date()) {
  const iso = date.toISOString().replace(/[:.]/g, '-');
  return `${iso}-${shortSuffix()}`;
}

module.exports = { slugify, slugId, timestampId };
