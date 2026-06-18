'use strict';

const fs = require('fs');
const path = require('path');
const { attachInstructors, resolveInstructorEmails } = require('./parse_instructors');

const DAYS_MAP = { M: '1', T: '2', W: '3', Th: '4', F: '5', S: '6', Su: '7' };

function parseCreditStructure(unitsStr) {
    try {
        const parts = unitsStr.split('-').map(Number);
        if (parts.length === 3) {
            return parts[0] + parts[1] + 0.5 * parts[2];
        }
    } catch (_) { /* ignore */ }
    return 0;
}

function cleanCourseCode(nameStr) {
    if (!nameStr) return '';
    const trimmed = nameStr.trim();
    const idx = trimmed.lastIndexOf('-');
    if (idx !== -1) return trimmed.slice(idx + 1).trim();
    return trimmed;
}

function extractCourseName(nameStr) {
    if (!nameStr) return '';
    const idx = nameStr.lastIndexOf('-');
    if (idx !== -1) return nameStr.slice(0, idx).trim();
    return nameStr.trim();
}

function parseTimings(timeStr) {
    if (!timeStr) return null;
    const encoded = [];
    for (const part of timeStr.split(',')) {
        const trimmed = part.trim();
        if (!trimmed) continue;
        const match = trimmed.match(/([A-Za-z]+)\s+(\d{1,2}:\d{2})-(\d{1,2}:\d{2})/);
        if (!match) continue;
        const daysStr = match[1];
        const fmt = (t) => {
            const [h, m] = t.split(':');
            return `${Number(h).toString().padStart(2, '0')}${m}`;
        };
        const st = fmt(match[2]);
        const et = fmt(match[3]);
        const parsedDays = [];
        let i = 0;
        while (i < daysStr.length) {
            if (i + 1 < daysStr.length && daysStr.slice(i, i + 2) === 'Th') {
                parsedDays.push('Th');
                i += 2;
            } else {
                parsedDays.push(daysStr[i]);
                i += 1;
            }
        }
        for (const d of parsedDays) {
            if (DAYS_MAP[d]) encoded.push(`${DAYS_MAP[d]}${st}${et}`);
        }
    }
    return encoded.length ? encoded.join(',') : null;
}

function parseCsvLine(line) {
    const row = [];
    let cur = '';
    let inQuotes = false;
    for (let i = 0; i < line.length; i += 1) {
        const ch = line[i];
        if (ch === '"') {
            inQuotes = !inQuotes;
        } else if (ch === ',' && !inQuotes) {
            row.push(cur);
            cur = '';
        } else {
            cur += ch;
        }
    }
    row.push(cur);
    return row.map((c) => c.trim());
}

function parseCoursesFromCsv(csvPath, semesterCode) {
    const raw = fs.readFileSync(csvPath, 'utf8');
    const lines = raw.split(/\r?\n/);
    const courses = [];

    for (const line of lines) {
        if (!line.trim()) continue;
        const row = parseCsvLine(line);
        const sNo = (row[0] || '').trim();
        if (!/^\d+$/.test(sNo)) continue;

        const rawCourseName = (row[1] || '').trim();
        let unitsIdx = row.findIndex((col) => /^\d+(\.\d+)?-\d+(\.\d+)?-\d+(\.\d+)?$/.test(col.trim()));
        if (unitsIdx === -1) unitsIdx = row.length > 5 ? 5 : -1;
        const units = unitsIdx !== -1 ? row[unitsIdx].trim() : '0-0-0';

        let emailIdx = -1;
        const startSearch = unitsIdx !== -1 ? unitsIdx + 1 : 2;
        for (let i = startSearch; i < row.length; i += 1) {
            if (row[i].includes('@')) {
                emailIdx = i;
                break;
            }
        }

        let lectureStr = '';
        let tutorialStr = '';
        let practicalStr = '';
        if (emailIdx !== -1) {
            const vacancyIdx = row.length - 2;
            if (vacancyIdx > emailIdx + 1) {
                const timingCols = row.slice(emailIdx + 1, vacancyIdx);
                if (timingCols.length >= 1) lectureStr = timingCols[0].trim();
                if (timingCols.length >= 2) tutorialStr = timingCols[1].trim();
                if (timingCols.length >= 3) {
                    practicalStr = timingCols.length === 3
                        ? timingCols[2].trim()
                        : timingCols[3].trim();
                }
            }
        } else if (unitsIdx === 5 && row.length > 13) {
            lectureStr = row[10].trim();
            tutorialStr = row[11].trim();
            practicalStr = row[13].trim();
        } else if (unitsIdx === 4 && row.length > 8) {
            lectureStr = row[8].trim();
            if (row.length > 9) tutorialStr = row[9].trim();
            if (row.length > 10) practicalStr = row[10].trim();
        }

        const code = cleanCourseCode(rawCourseName);
        const name = extractCourseName(rawCourseName);
        if (!code) continue;

        let slotName = 'X';
        if (row.length > 3) {
            const candidate = row[3].trim();
            if (candidate.length <= 2) slotName = candidate;
        }
        if (slotName === 'X' && unitsIdx !== -1) {
            if (unitsIdx - 1 >= 0 && row[unitsIdx - 1].trim().length <= 2 && row[unitsIdx - 1].trim()) {
                slotName = row[unitsIdx - 1].trim();
            } else if (unitsIdx - 2 >= 0 && row[unitsIdx - 2].trim().length <= 2 && row[unitsIdx - 2].trim()) {
                slotName = row[unitsIdx - 2].trim();
            }
        }

        const instructor = emailIdx !== -1 && emailIdx > 0 ? row[emailIdx - 1].trim() : 'N/A';
        const instructorEmail = emailIdx !== -1
            ? (row[emailIdx] || '').trim().toLowerCase()
            : null;
        const currentStrength = row.length > 0 ? row[row.length - 1].trim() : 'N/A';

        courses.push(attachInstructors({
            courseCode: code,
            courseName: name,
            semesterCode,
            totalCredits: parseCreditStructure(units),
            creditStructure: units,
            instructor,
            instructorEmail: instructorEmail && instructorEmail.includes('@') ? instructorEmail : null,
            currentStrength,
            slot: {
                name: slotName || 'X',
                lectureTiming: parseTimings(lectureStr),
                lectureTimingStr: lectureStr,
                tutorialTiming: parseTimings(tutorialStr),
                labTiming: parseTimings(practicalStr),
            },
            lectureHall: null,
        }));
    }
    resolveInstructorEmails(courses);
    return courses;
}

module.exports = { parseCoursesFromCsv };
