'use strict';

/**
 * IITD semester codes (YYTT): YY is shared across both terms in a cycle.
 * 01 → Semester 1, Jul of 20YY
 * 02 → Semester 2, Jan of 20(YY+1)
 * e.g. 2401 Jul 2024, 2402 Jan 2025, 2501 Jul 2025, 2502 Jan 2026
 */
function semesterMetaFromCode(code) {
    const normalized = (code || '').trim();
    if (!/^\d{4}$/.test(normalized)) {
        throw new Error(`Invalid semester code: ${code}`);
    }
    const yy = parseInt(normalized.slice(0, 2), 10);
    const term = normalized.slice(2);
    const startYear = 2000 + yy;

    if (term === '01') {
        return {
            label: `Semester 1, ${startYear}–${startYear + 1}`,
            classesStart: `${startYear}-07-23`,
            lastTeachingDay: `${startYear}-11-17`,
        };
    }
    if (term === '02') {
        const springYear = startYear + 1;
        return {
            label: `Semester 2, ${startYear}–${springYear}`,
            classesStart: `${springYear}-01-06`,
            lastTeachingDay: `${springYear}-05-15`,
        };
    }
    return {
        label: `Semester ${term}, ${startYear}`,
        classesStart: `${startYear}-01-01`,
        lastTeachingDay: `${startYear}-12-31`,
    };
}

module.exports = { semesterMetaFromCode };
