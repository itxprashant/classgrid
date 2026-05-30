'use strict';

const express = require('express');
const config = require('./config');
const { getClientLib, getOidcConfig } = require('./oidc');
const {
    setSessionCookie,
    clearSessionCookie,
    setFlowCookie,
    clearFlowCookie,
    readFlow,
} = require('./session');

const router = express.Router();

router.get('/login', async (req, res) => {
    try {
        const client = await getClientLib();
        const cfg = await getOidcConfig();

        const codeVerifier = client.randomPKCECodeVerifier();
        const codeChallenge = await client.calculatePKCECodeChallenge(codeVerifier);
        const state = client.randomState();
        const returnApp = req.query.app === '1';

        setFlowCookie(res, {
            v: codeVerifier,
            s: state,
            ...(returnApp ? { app: 1 } : {}),
        });

        const authUrl = client.buildAuthorizationUrl(cfg, {
            redirect_uri: config.oidc.redirectUri,
            scope: config.oidc.scope,
            code_challenge: codeChallenge,
            code_challenge_method: 'S256',
            state,
        });

        res.redirect(authUrl.href);
    } catch (err) {
        console.error('[auth] /login failed:', err);
        res.status(500).send('Login initialization failed.');
    }
});

router.get('/callback', async (req, res) => {
    const flow = readFlow(req);
    if (!flow) {
        clearFlowCookie(res);
        res.status(400).send('Bad session. Start over from the home page.');
        return;
    }
    clearFlowCookie(res);

    try {
        const client = await getClientLib();
        const cfg = await getOidcConfig();

        const callbackUrl = new URL(
            req.originalUrl,
            config.oidc.redirectUri,
        );

        const tokens = await client.authorizationCodeGrant(cfg, callbackUrl, {
            pkceCodeVerifier: flow.v,
            expectedState: flow.s,
        });

        const claims = tokens.claims() || {};
        let userinfo = {};
        if (claims.sub) {
            try {
                userinfo = await client.fetchUserInfo(cfg, tokens.access_token, claims.sub);
            } catch (e) {
                console.warn('[auth] userinfo fetch failed:', e && e.message);
            }
        }

        const kerberos = (userinfo.kerberos || claims.kerberos || '').toString().toLowerCase().trim();
        const name = userinfo.name || claims.name || kerberos || 'IITD user';
        const picture = userinfo.picture || claims.picture || null;
        const email = userinfo.email || claims.email || null;

        if (!kerberos) {
            console.warn('[auth] no kerberos claim in token/userinfo');
        }

        const sessionToken = setSessionCookie(res, {
            kerberos,
            name,
            picture,
            email,
        });

        if (flow.app === 1) {
            const dest = new URL(`${config.mobileAppScheme}://auth/callback`);
            dest.searchParams.set('token', sessionToken);
            res.redirect(dest.toString());
            return;
        }

        const dest = new URL(config.frontendOrigin);
        dest.searchParams.set('login', 'success');
        res.redirect(dest.toString());
    } catch (err) {
        console.error('[auth] /callback failed:', err && (err.stack || err.message || err));
        res.status(500).send('Login failed. Please try again.');
    }
});

router.post('/logout', (req, res) => {
    clearSessionCookie(res);
    res.json({ ok: true });
});

router.get('/logout', (req, res) => {
    clearSessionCookie(res);
    res.redirect(config.frontendOrigin);
});

module.exports = router;
