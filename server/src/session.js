'use strict';

const jwt = require('jsonwebtoken');
const config = require('./config');

const SESSION_COOKIE = 'cg_session';
const FLOW_COOKIE = 'cg_flow';

const SESSION_TTL = '30d';
const FLOW_TTL = '10m';

function cookieOpts(maxAgeMs) {
    return {
        httpOnly: true,
        sameSite: 'lax',
        secure: config.isProd,
        path: '/',
        maxAge: maxAgeMs,
    };
}

function signSessionToken(payload) {
    return jwt.sign(payload, config.sessionSecret, {
        expiresIn: SESSION_TTL,
        audience: 'classgrid',
        subject: 'session',
    });
}

function setSessionCookie(res, payload) {
    const token = signSessionToken(payload);
    res.cookie(SESSION_COOKIE, token, cookieOpts(30 * 24 * 60 * 60 * 1000));
    return token;
}

function clearSessionCookie(res) {
    res.clearCookie(SESSION_COOKIE, { path: '/' });
}

function readSession(req) {
    const token = req.cookies && req.cookies[SESSION_COOKIE];
    if (!token) return null;
    try {
        return jwt.verify(token, config.sessionSecret, {
            audience: 'classgrid',
            subject: 'session',
        });
    } catch (e) {
        return null;
    }
}

function setFlowCookie(res, payload) {
    const token = jwt.sign(payload, config.sessionSecret, {
        expiresIn: FLOW_TTL,
        audience: 'classgrid',
        subject: 'flow',
    });
    res.cookie(FLOW_COOKIE, token, cookieOpts(10 * 60 * 1000));
}

function clearFlowCookie(res) {
    res.clearCookie(FLOW_COOKIE, { path: '/' });
}

function readFlow(req) {
    const token = req.cookies && req.cookies[FLOW_COOKIE];
    if (!token) return null;
    try {
        return jwt.verify(token, config.sessionSecret, {
            audience: 'classgrid',
            subject: 'flow',
        });
    } catch (e) {
        return null;
    }
}

function requireSession(req, res, next) {
    const session = readSession(req);
    if (!session) {
        res.status(401).json({ error: 'not_authenticated' });
        return;
    }
    req.session = session;
    next();
}

module.exports = {
    SESSION_COOKIE,
    FLOW_COOKIE,
    signSessionToken,
    setSessionCookie,
    clearSessionCookie,
    readSession,
    setFlowCookie,
    clearFlowCookie,
    readFlow,
    requireSession,
};
