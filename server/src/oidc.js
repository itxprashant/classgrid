'use strict';

const config = require('./config');

let cachedConfigPromise = null;
let clientLib = null;

async function getClientLib() {
    if (!clientLib) {
        clientLib = await import('openid-client');
    }
    return clientLib;
}

async function getOidcConfig() {
    if (cachedConfigPromise) return cachedConfigPromise;
    cachedConfigPromise = (async () => {
        const client = await getClientLib();
        const serverUrl = new URL(config.oidc.discoveryUrl);
        return client.discovery(
            serverUrl,
            config.oidc.clientId,
            config.oidc.clientSecret,
        );
    })().catch((err) => {
        cachedConfigPromise = null;
        throw err;
    });
    return cachedConfigPromise;
}

module.exports = {
    getClientLib,
    getOidcConfig,
};
