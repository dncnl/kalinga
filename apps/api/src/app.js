const express = require('express');
const cors = require('cors');

const healthRouter = require('./routes/health');
const observationsRouter = require('./routes/observations');
const rollupRouter = require('./routes/rollup');
const ragRouter = require('./routes/rag');
const householdsRouter = require('./routes/households');
const invitesRouter = require('./routes/invites');
const medicationsRouter = require('./routes/medications');
const tasksRouter = require('./routes/tasks');

const app = express();

app.use(cors());
app.use(express.json());

app.use(healthRouter);
app.use(observationsRouter);
app.use(rollupRouter);
app.use(ragRouter);
app.use(householdsRouter);
app.use(invitesRouter);
app.use(medicationsRouter);
app.use(tasksRouter);

module.exports = app;
