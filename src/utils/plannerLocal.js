import { parseTimingStr } from './roomSchedule';

export const SELECTED_COURSES_KEY = 'selectedCourses';
export const TIMETABLE_DATA_KEY = 'timetableData';

export function loadPlanFromLocal() {
    try {
        const selectedCourses = JSON.parse(localStorage.getItem(SELECTED_COURSES_KEY) || '[]');
        const timetableData = JSON.parse(localStorage.getItem(TIMETABLE_DATA_KEY) || '{}');
        return {
            selectedCourses: Array.isArray(selectedCourses) ? selectedCourses : [],
            timetableData: timetableData && typeof timetableData === 'object' ? timetableData : {},
        };
    } catch {
        return { selectedCourses: [], timetableData: {} };
    }
}

export function persistPlanToLocal({ selectedCourses, timetableData }) {
    localStorage.setItem(SELECTED_COURSES_KEY, JSON.stringify(selectedCourses));
    localStorage.setItem(TIMETABLE_DATA_KEY, JSON.stringify(timetableData));
}

export function isCourseOnPlan(courseCode) {
    const { selectedCourses } = loadPlanFromLocal();
    return selectedCourses.some((c) => c.courseCode === courseCode);
}

function planEntryFromCourse(course) {
    const parts = (course.creditStructure || '0.0-0.0-0.0').split('-');
    return {
        courseCode: course.courseCode,
        courseName: course.courseName,
        instructor: course.instructor,
        lecture: !!course.slot?.lectureTiming,
        tutorial: parts[1] !== '0.0',
        lab: parts[2] !== '0.0',
        lectureTiming: parseTimingStr(course.slot?.lectureTiming),
        tutorialTiming: parseTimingStr(course.slot?.tutorialTiming),
        labTiming: parseTimingStr(course.slot?.labTiming),
        creditStructure: course.creditStructure,
        totalCredits: course.totalCredits,
        lectureHall: course.lectureHall,
    };
}

export function addCourseToLocalPlan(course) {
    const plan = loadPlanFromLocal();
    if (plan.selectedCourses.some((c) => c.courseCode === course.courseCode)) {
        return plan;
    }

    const selectedCourses = [...plan.selectedCourses, planEntryFromCourse(course)];
    const timetableData = {
        ...plan.timetableData,
        [course.courseCode]: {
            lecture: parseTimingStr(course.slot?.lectureTiming),
            tutorial: null,
            lab: null,
        },
    };

    const next = { selectedCourses, timetableData };
    persistPlanToLocal(next);
    return next;
}

export function removeCourseFromLocalPlan(courseCode) {
    const plan = loadPlanFromLocal();
    const selectedCourses = plan.selectedCourses.filter((c) => c.courseCode !== courseCode);
    const timetableData = { ...plan.timetableData };
    delete timetableData[courseCode];
    const next = { selectedCourses, timetableData };
    persistPlanToLocal(next);
    return next;
}
