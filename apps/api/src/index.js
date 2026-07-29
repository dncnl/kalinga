require('dotenv').config({ quiet: true });

// Initializes Firebase Admin (Firestore + Storage) on boot.
require('./firebase');

const app = require('./app');

const port = process.env.PORT || 8081;

app.listen(port, () => {
  console.log(`api listening on port ${port}`);
});
