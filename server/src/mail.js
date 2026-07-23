'use strict';

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const config = require('./config');

const TEMPLATES_DIR = path.join(__dirname, '..', 'email-templates');
const SEND_SCRIPT = path.join(__dirname, '..', 'scripts', 'send_email_devclub.py');

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const IITD_DOMAIN = 'iitd.ac.in';

function mailConfigured() {
    return Boolean(config.smtpUser && config.smtpPass);
}

function quoteMessage(text) {
    const raw = String(text || '').replace(/\r\n/g, '\n').trim();
    if (!raw) return '> (no message)';
    return raw
        .split('\n')
        .map((line) => `> ${line}`)
        .join('\n');
}

function fillTemplate(template, vars) {
    return String(template).replace(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g, (_, key) => {
        if (Object.prototype.hasOwnProperty.call(vars, key) && vars[key] != null) {
            return String(vars[key]);
        }
        return '';
    });
}

function templatePath(name) {
    return path.join(TEMPLATES_DIR, `${name}.txt`);
}

function loadTemplate(name) {
    const file = templatePath(name);
    if (!fs.existsSync(file)) {
        const err = new Error(`missing_template:${name}`);
        err.code = 'missing_template';
        throw err;
    }
    return fs.readFileSync(file, 'utf8');
}

function saveTemplate(name, body) {
    const text = String(body ?? '');
    if (!text.trim() || text.length > 20000) {
        const err = new Error('invalid_template');
        err.code = 'invalid_template';
        throw err;
    }
    const file = templatePath(name);
    if (!fs.existsSync(file)) {
        const err = new Error(`missing_template:${name}`);
        err.code = 'missing_template';
        throw err;
    }
    fs.writeFileSync(file, text, 'utf8');
    return text;
}

function kerberosToEmail(kerberos) {
    const k = String(kerberos || '').trim().toLowerCase();
    if (!k || !/^[a-z0-9._-]+$/i.test(k)) return null;
    return `${k}@${IITD_DOMAIN}`;
}

function resolveRecipient({ kerberos, email }) {
    const direct = email ? String(email).trim().toLowerCase() : '';
    if (direct && EMAIL_RE.test(direct)) return direct;
    return kerberosToEmail(kerberos);
}

function buildFeedbackDraft(row) {
    const kerberos = row.kerberos || null;
    const name = (row.reporter_name || kerberos || 'there').trim();
    const to = resolveRecipient({
        kerberos,
        email: row.reporter_email,
    });
    const quoted = quoteMessage(row.message);
    const body = fillTemplate(loadTemplate('feedback-review'), {
        name,
        kerberos: kerberos || '',
        quoted_message: quoted,
        reply: '',
    });
    return {
        to,
        subject: 'Feedback review',
        body,
        template: 'feedback-review',
    };
}

function buildReportDraft(row, contextLabel) {
    const kerberos = row.reporter_kerberos || null;
    const name = (row.reporter_name || kerberos || 'there').trim();
    const to = resolveRecipient({ kerberos });
    const details = row.details && String(row.details).trim()
        ? row.details
        : `(no extra details)\nTarget: ${contextLabel || row.target_kind}`;
    const body = fillTemplate(loadTemplate('report-review'), {
        name,
        kerberos: kerberos || '',
        reason: row.reason || '',
        target: contextLabel || row.target_kind || '',
        quoted_message: quoteMessage(details),
        reply: '',
    });
    return {
        to,
        subject: 'Report review',
        body,
        template: 'report-review',
    };
}

function sendEmail({ to, subject, body }) {
    if (!mailConfigured()) {
        const err = new Error('mail_unconfigured');
        err.code = 'mail_unconfigured';
        return Promise.reject(err);
    }
    const recipient = String(to || '').trim().toLowerCase();
    if (!EMAIL_RE.test(recipient)) {
        const err = new Error('invalid_recipient');
        err.code = 'invalid_recipient';
        return Promise.reject(err);
    }
    const subj = String(subject || '').trim();
    if (!subj || subj.length > 200) {
        const err = new Error('invalid_subject');
        err.code = 'invalid_subject';
        return Promise.reject(err);
    }
    const text = String(body || '');
    if (!text.trim() || text.length > 20000) {
        const err = new Error('invalid_body');
        err.code = 'invalid_body';
        return Promise.reject(err);
    }

    return new Promise((resolve, reject) => {
        const child = spawn(
            'python3',
            [SEND_SCRIPT, recipient, '-s', subj, '-f', '-'],
            {
                env: {
                    ...process.env,
                    SMTP_HOST: config.smtpHost,
                    SMTP_PORT: String(config.smtpPort),
                    SMTP_USER: config.smtpUser,
                    SMTP_PASS: config.smtpPass,
                    SMTP_FROM: config.smtpFrom,
                },
                stdio: ['pipe', 'pipe', 'pipe'],
            },
        );

        let stdout = '';
        let stderr = '';
        child.stdout.on('data', (chunk) => { stdout += chunk; });
        child.stderr.on('data', (chunk) => { stderr += chunk; });
        child.on('error', (e) => {
            const err = new Error(e.message || 'mail_spawn_failed');
            err.code = 'mail_send_failed';
            reject(err);
        });
        child.on('close', (code) => {
            if (code === 0) {
                resolve({
                    to: recipient,
                    subject: subj,
                    from: config.smtpFrom,
                });
                return;
            }
            const err = new Error((stderr || stdout || 'mail_send_failed').trim());
            err.code = 'mail_send_failed';
            reject(err);
        });
        child.stdin.write(text, 'utf8');
        child.stdin.end();
    });
}

module.exports = {
    mailConfigured,
    quoteMessage,
    fillTemplate,
    loadTemplate,
    saveTemplate,
    resolveRecipient,
    buildFeedbackDraft,
    buildReportDraft,
    sendEmail,
};
