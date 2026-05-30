'use strict';

const { Pool } = require('pg');
const config = require('./config');

let pool = null;

function getPool() {
    if (!config.databaseUrl) {
        return null;
    }
    if (!pool) {
        pool = new Pool({
            connectionString: config.databaseUrl,
            max: 10,
        });
        pool.on('error', (err) => {
            console.error('[db] unexpected pool error:', err.message);
        });
    }
    return pool;
}

async function query(text, params) {
    const p = getPool();
    if (!p) {
        throw new Error('database_not_configured');
    }
    return p.query(text, params);
}

module.exports = {
    getPool,
    query,
};
