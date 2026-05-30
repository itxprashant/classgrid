const fs = require('fs');
const path = require('path');

// Suppress SSL verification errors for self-signed certificates
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const BASE_URL = 'https://ldapweb.iitd.ac.in/LDAP/courses';
const SEMESTER_PREFIX = '2502-';
const OUTPUT_FILE = path.join(__dirname, '../src/studentCourses.json');

async function fetchCourses() {
    console.log('Starting course fetch for semester:', SEMESTER_PREFIX);

    try {
        // 1. Fetch main list
        console.log(`Fetching ${BASE_URL}/gpaliases.html...`);
        const response = await fetch(`${BASE_URL}/gpaliases.html`);
        if (!response.ok) throw new Error(`Failed to fetch aliases: ${response.status}`);
        const text = await response.text();

        // 2. Parse course links
        const linkRegex = /href="([^"]+)"/g;
        const links = [];
        let match;
        while ((match = linkRegex.exec(text)) !== null) {
            if (match[1].startsWith(SEMESTER_PREFIX) && (match[1].endsWith('.shtml') || match[1].endsWith('.html'))) {
                links.push(match[1]);
            }
        }

        console.log(`Found ${links.length} course pages.`);

        // 3. Fetch each course page and build mapping
        const studentCourses = {}; // kerberos -> [courseCodes]
        const courseStudents = {}; // courseCode -> [kerberos]
        const BATCH_SIZE = 50;

        for (let i = 0; i < links.length; i += BATCH_SIZE) {
            const batch = links.slice(i, i + BATCH_SIZE);
            console.log(`Processing batch ${i + 1}-${Math.min(i + BATCH_SIZE, links.length)}...`);

            await Promise.all(batch.map(async (link) => {
                try {
                    const courseCodeMatch = link.match(/-([A-Z0-9]+)\./);
                    if (!courseCodeMatch) return;
                    const courseCode = courseCodeMatch[1];

                    const courseRes = await fetch(`${BASE_URL}/${link}`);
                    if (!courseRes.ok) return;
                    const courseText = await courseRes.text();

                    // Parse HTML Table for ID and Name
                    // Pattern: <TR><TD ALIGN=LEFT>sahasudipan</TD>\n<TD>Sudipan Saha</TD>
                    // We can use a regex to capture this pair.
                    const rowRegex = /<TR><TD[^>]*>([a-z0-9]+)<\/TD>\s*<TD>([^<]+)<\/TD>/gi;
                    let rowMatch;

                    while ((rowMatch = rowRegex.exec(courseText)) !== null) {
                        const kid = rowMatch[1].trim().toLowerCase();
                        const name = rowMatch[2].trim();

                        // Heuristic check for valid ID length
                        if (kid.length >= 5) {
                            // Update student -> courses
                            if (!studentCourses[kid]) studentCourses[kid] = [];
                            if (!studentCourses[kid].includes(courseCode)) {
                                studentCourses[kid].push(courseCode);
                            }

                            // Update course -> students
                            if (!courseStudents[courseCode]) courseStudents[courseCode] = [];
                            // Check if student already added (by ID)
                            if (!courseStudents[courseCode].find(s => s.id === kid)) {
                                courseStudents[courseCode].push({ id: kid, name: name });
                            }
                        }
                    }
                } catch (err) {
                    console.error(`Error processing ${link}:`, err.message);
                }
            }));
        }

        // 4. Save to files
        fs.writeFileSync(OUTPUT_FILE, JSON.stringify(studentCourses, null, 2));
        console.log(`Successfully saved courses for ${Object.keys(studentCourses).length} students to ${OUTPUT_FILE}`);

        const COURSE_STUDENTS_FILE = path.join(__dirname, '../src/courseStudents.json');
        fs.writeFileSync(COURSE_STUDENTS_FILE, JSON.stringify(courseStudents, null, 2));
        console.log(`Successfully saved students for ${Object.keys(courseStudents).length} courses to ${COURSE_STUDENTS_FILE}`);

    } catch (error) {
        console.error('Fatal error:', error);
        process.exit(1);
    }
}

fetchCourses();
