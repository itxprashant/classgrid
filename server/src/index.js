'use strict';

const express = require('express');
const cookieParser = require('cookie-parser');

const config = require('./config');
const authRouter = require('./auth');
const apiRouter = require('./courses');
const catalogRouter = require('./catalog');
const calendarRouter = require('./calendarEvents');
const plannerRouter = require('./planner');
const occupiedRoomsRouter = require('./occupiedRooms');
const personalEventsRouter = require('./personalEvents');
const appVersionRouter = require('./appVersion');
const remindersRouter = require('./reminders');

const app = express();

app.set('trust proxy', 1);
app.use(express.json());
app.use(cookieParser());

app.use('/auth', authRouter);
app.use('/api', apiRouter);
app.use('/api', catalogRouter);
app.use('/api', calendarRouter);
app.use('/api', plannerRouter);
app.use('/api', occupiedRoomsRouter);
app.use('/api', personalEventsRouter);
app.use('/api', appVersionRouter);
app.use('/api', remindersRouter);

app.get('/', (req, res) => {
    res.json({ name: 'classgrid-api', ok: true });
});

app.use((err, req, res, next) => {
    console.error('[server] unhandled error:', err && (err.stack || err.message || err));
    if (res.headersSent) return next(err);
    res.status(500).json({ error: 'internal_error' });
});

app.listen(config.port, () => {
    console.log(`[classgrid-api] listening on http://127.0.0.1:${config.port} (${config.nodeEnv})`);
    console.log(`[classgrid-api] OIDC redirect_uri: ${config.oidc.redirectUri}`);
    console.log(`[classgrid-api] frontend origin: ${config.frontendOrigin}`);
    if (config.databaseUrl) {
        console.log('[classgrid-api] database: configured');
    } else {
        console.warn('[classgrid-api] database: DATABASE_URL not set (calendar API disabled)');
    }
});
