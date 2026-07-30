const { getAuth } = require('firebase-admin/auth');
require('../config/firebase'); // ensure initialized

/**
 * Express middleware to verify Firebase ID Token.
 * Attaches verified { uid, email } to req.user.
 */
async function verifyToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decodedToken = await getAuth().verifyIdToken(token);
    
    // Attach user properties derived from verified Firebase token
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email
    };
    
    return next();
  } catch (error) {
    console.error('Error verifying ID token:', error.message);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = {
  verifyToken
};
