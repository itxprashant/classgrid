'use strict';

const path = require('path');
const fs = require('fs');

const repoRoot = path.resolve(__dirname, '..', '..');

function requireFromServer(name) {
    try {
        return require(name);
    } catch (e) {
        if (e.code !== 'MODULE_NOT_FOUND') throw e;
        return require(path.join(repoRoot, 'server', 'node_modules', name));
    }
}

const envCandidates = [
    path.join(repoRoot, 'server', '.env'),
    path.join(repoRoot, '.env'),
];
for (const p of envCandidates) {
    if (fs.existsSync(p)) {
        requireFromServer('dotenv').config({ path: p });
        break;
    }
}

const { Pool } = requireFromServer('pg');

function getPool() {
    const url = (process.env.DATABASE_URL || '').trim();
    if (!url) {
        console.error('[db] DATABASE_URL is required');
        process.exit(1);
    }
    return new Pool({ connectionString: url, max: 5 });
}

function parseArgs(argv) {
    const args = {};
    for (let i = 2; i < argv.length; i += 1) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const eq = a.indexOf('=');
            if (eq !== -1) {
                args[a.slice(2, eq)] = a.slice(eq + 1);
            } else if (argv[i + 1] && !argv[i + 1].startsWith('--')) {
                args[a.slice(2)] = argv[i + 1];
                i += 1;
            } else {
                args[a.slice(2)] = true;
            }
        }
    }
    return args;
}

async function withClient(fn) {
    const pool = getPool();
    const client = await pool.connect();
    try {
        await fn(client);
    } finally {
        client.release();
        await pool.end();
    }
}

function computeCatalogEtag(semesterCode, count, updatedAt) {
    const crypto = require('crypto');
    return crypto.createHash('sha1')
        .update(`${semesterCode}:${count}:${updatedAt || ''}`)
        .digest('hex');
}

module.exports = {
    repoRoot,
    getPool,
    parseArgs,
    withClient,
    computeCatalogEtag,
};
