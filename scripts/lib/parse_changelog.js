'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Extract release notes for a semver from a Keep a Changelog file.
 *
 * @param {string} filePath - Path to CHANGELOG.md
 * @param {string} version - Semver without build (e.g. 1.1.6)
 * @returns {string} Note body without the ## heading line
 */
function parseChangelogSection(filePath, version) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const normalizedVersion = version.trim();
    const headingRe = new RegExp(
        `^##\\s*\\[${escapeRegExp(normalizedVersion)}\\][^\\n]*$`,
        'm',
    );
    const match = headingRe.exec(raw);
    if (!match) {
        throw new Error(
            `No changelog section for version ${normalizedVersion} in ${filePath}. `
            + `Add a "## [${normalizedVersion}] - YYYY-MM-DD" heading before releasing.`,
        );
    }

    const start = match.index + match[0].length;
    const rest = raw.slice(start);
    const nextHeading = rest.search(/^##\s/m);
    const body = (nextHeading === -1 ? rest : rest.slice(0, nextHeading)).trim();
    if (!body) {
        throw new Error(
            `Changelog section for ${normalizedVersion} in ${filePath} is empty.`,
        );
    }
    return body;
}

function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

module.exports = {
    parseChangelogSection,
};
