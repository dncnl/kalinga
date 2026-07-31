const { auth } = require('../firebase');

// Verifies the caregiver's Firebase ID token and attaches req.uid.
// Every route that touches a household's data must sit behind this —
// the schema marks those collections clientWritePolicy: serverOnly, which
// means the API itself is the only thing allowed to enforce who's who.
async function requireAuth(req, res, next) {
  const [scheme, token] = (req.headers.authorization || '').split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  try {
    const decoded = await auth.verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    // The client only ever sees the generic 401 below — the real reason
    // (expired, wrong project audience, clock skew, malformed, etc) only
    // goes to the server console, since it can hint at token internals.
    console.error('requireAuth: verifyIdToken failed:', err.message);
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { requireAuth };
