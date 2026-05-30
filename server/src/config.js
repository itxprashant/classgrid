'use strict';

const path = require('path');
const fs = require('fs');

const repoRoot = path.resolve(__dirname, '..', '..');

const envCandidates = [
    path.join(__dirname, '..', '.env'),
    path.join(repoRoot, '.env'),
];
for (const p of envCandidates) {
    if (fs.existsSync(p)) {
        require('dotenv').config({ path: p });
        break;
    }
}

function required(name) {
    const v = (process.env[name] || '').trim();
    if (!v) {
        console.error(`[classgrid-api] missing required env var: ${name}`);
        process.exit(1);
    }
    return v;
}

const config = {
    port: Number(process.env.PORT || 4000),
    nodeEnv: process.env.NODE_ENV || 'development',

    oidc: {
        clientId: required('OIDC_CLIENT_ID'),
        clientSecret: required('OIDC_CLIENT_SECRET'),
        redirectUri: required('OIDC_REDIRECT_URI'),
        discoveryUrl: (process.env.OIDC_DISCOVERY_URL || '').trim()
            || 'https://auth.devclub.in/api/oauth/.well-known/openid-configuration',
        scope: (process.env.OIDC_SCOPE || 'openid profile email kerberos').trim(),
    },

    sessionSecret: required('SESSION_SECRET'),
    frontendOrigin: (process.env.FRONTEND_ORIGIN || 'http://localhost:3000').trim(),

    studentCoursesPath: (process.env.STUDENT_COURSES_PATH
        || path.join(repoRoot, 'src', 'studentCourses.json')).trim(),

    catalogPath: (process.env.CATALOG_PATH
        || path.join(repoRoot, 'src', 'courses.json')).trim(),

    courseStudentsPath: (process.env.COURSE_STUDENTS_PATH
        || path.join(repoRoot, 'src', 'courseStudents.json')).trim(),

    databaseUrl: (process.env.DATABASE_URL || '').trim() || null,

    // Custom URL scheme for the Flutter app deep link after OAuth
    // (classgrid://auth/callback?token=…). Override only if the app scheme changes.
    mobileAppScheme: (process.env.MOBILE_APP_SCHEME || 'classgrid').trim(),
};

config.isProd = config.nodeEnv === 'production';

module.exports = config;
