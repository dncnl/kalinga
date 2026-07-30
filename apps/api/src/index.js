require('dotenv').config();
const express = require('express');
const cors = require('cors');
const authRouter = require('./routes/auth');

const app = express();
const port = process.env.PORT || 3000;

// Enable CORS for all origins
app.use(cors());

// Parse incoming JSON requests
app.use(express.json());

// Routes
app.use('/auth', authRouter);

// Health check endpoint
app.get('/', (req, res) => {
  res.status(200).json({ status: 'ok', service: 'kalinga-api' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Unhandled express application error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(port, () => {
  console.log(`API running on port ${port}`);
});

module.exports = app; // Export for testing if needed
