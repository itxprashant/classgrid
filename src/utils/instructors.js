/** Normalize instructor list from a catalog course or offering row. */
export function instructorsFromCourse(course) {
    if (!course || typeof course !== 'object') return [];
    if (Array.isArray(course.instructors) && course.instructors.length) {
        return course.instructors
            .map((i) => ({
                name: (i?.name || '').trim(),
                email: (i?.email || '').trim().toLowerCase() || null,
            }))
            .filter((i) => i.name || i.email);
    }
    const raw = (course.instructor || '').trim();
    const email = (course.instructorEmail || '').trim().toLowerCase() || null;
    if (!raw && !email) return [];
    if (raw.includes(',') && email) {
        return raw.split(',').map((part, index) => ({
            name: part.replace(/\s+/g, ' ').trim(),
            email: index === 0 ? email : null,
        }));
    }
    return [{ name: raw || email, email }];
}
