'use strict';

const config = require('./config');
const { readSession } = require('./session');
const semesterData = require('./semesterData');

function normalizeKerberos(kerberos) {
    return semesterData.normalizeKerberos(kerberos);
}

function isAdminKerberos(kerberos) {
    const k = normalizeKerberos(kerberos);
    if (!k) return false;
    return config.adminKerberses.includes(k);
}

function requireAdmin(req, res, next) {
    const session = readSession(req);
    if (!session) {
        res.status(401).json({ error: 'not_authenticated' });
        return;
    }
    const kerberos = normalizeKerberos(session.kerberos);
    if (!kerberos || !isAdminKerberos(kerberos)) {
        res.status(403).json({ error: 'not_admin' });
        return;
    }
    req.session = session;
    req.adminKerberos = kerberos;
    next();
}

module.exports = {
    isAdminKerberos,
    requireAdmin,
};
