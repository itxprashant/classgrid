'use strict';

const fs = require('fs');
const config = require('./config');
const db = require('./db');

const BROADCAST_TOPIC = 'classgrid_broadcast';
const MULTICAST_BATCH = 500;

let adminApp = null;
let initAttempted = false;

function isFcmConfigured() {
    const path = (config.firebaseServiceAccountPath || '').trim();
    return Boolean(path && fs.existsSync(path));
}

function getMessaging() {
    if (adminApp) {
        return adminApp.messaging();
    }
    if (initAttempted) {
        throw new Error('fcm_unconfigured');
    }
    initAttempted = true;

    const path = (config.firebaseServiceAccountPath || '').trim();
    if (!path || !fs.existsSync(path)) {
        throw new Error('fcm_unconfigured');
    }

    // eslint-disable-next-line global-require, import/no-dynamic-require
    const serviceAccount = require(path);
    const admin = require('firebase-admin');
    adminApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
    return adminApp.messaging();
}

async function pruneInvalidTokens(tokens, responses) {
    if (!config.databaseUrl || !responses || !tokens) return;

    const stale = [];
    for (let i = 0; i < responses.length; i += 1) {
        const resp = responses[i];
        if (resp.success) continue;
        const code = resp.error && resp.error.code;
        if (code === 'messaging/registration-token-not-registered'
            || code === 'messaging/invalid-registration-token') {
            stale.push(tokens[i]);
        }
    }

    if (stale.length === 0) return;

    await db.query(
        'DELETE FROM user_fcm_tokens WHERE fcm_token = ANY($1::text[])',
        [stale],
    );
}

async function sendBroadcast({ title, body, audience, data }) {
    const messaging = getMessaging();
    const notification = { title, body };
    const payloadData = data && typeof data === 'object' ? data : undefined;

    if (audience === 'all') {
        await messaging.send({
            topic: BROADCAST_TOPIC,
            notification,
            ...(payloadData ? { data: payloadData } : {}),
        });
        return { successCount: 1, failureCount: 0 };
    }

    if (audience !== 'signed_in') {
        throw new Error('invalid_audience');
    }

    if (!config.databaseUrl) {
        throw new Error('database_unavailable');
    }

    const { rows } = await db.query(
        `SELECT fcm_token FROM user_fcm_tokens WHERE kerberos IS NOT NULL`,
    );
    const tokens = rows.map((r) => r.fcm_token).filter(Boolean);

    if (tokens.length === 0) {
        return { successCount: 0, failureCount: 0 };
    }

    let successCount = 0;
    let failureCount = 0;

    for (let offset = 0; offset < tokens.length; offset += MULTICAST_BATCH) {
        const batch = tokens.slice(offset, offset + MULTICAST_BATCH);
        const result = await messaging.sendEachForMulticast({
            tokens: batch,
            notification,
            ...(payloadData ? { data: payloadData } : {}),
        });
        successCount += result.successCount;
        failureCount += result.failureCount;
        await pruneInvalidTokens(batch, result.responses);
    }

    return { successCount, failureCount };
}

module.exports = {
    BROADCAST_TOPIC,
    isFcmConfigured,
    sendBroadcast,
};
