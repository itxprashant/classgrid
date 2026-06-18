import { useCallback, useEffect, useRef, useState } from 'react';
import { savePlan } from '../utils/plannerApi';
import {
    SELECTED_COURSES_KEY,
    addCourseToLocalPlan,
    isCourseOnPlan,
    removeCourseFromLocalPlan,
} from '../utils/plannerLocal';

export function useCoursePlan(course, user) {
    const [onPlan, setOnPlan] = useState(() => (
        course ? isCourseOnPlan(course.courseCode) : false
    ));
    const saveTimerRef = useRef(null);

    useEffect(() => {
        if (!course) return undefined;
        setOnPlan(isCourseOnPlan(course.courseCode));

        const syncFromStorage = (event) => {
            if (event && event.key && event.key !== SELECTED_COURSES_KEY) return;
            setOnPlan(isCourseOnPlan(course.courseCode));
        };

        window.addEventListener('storage', syncFromStorage);
        return () => window.removeEventListener('storage', syncFromStorage);
    }, [course]);

    const scheduleSave = useCallback((plan) => {
        if (!user) return;
        clearTimeout(saveTimerRef.current);
        saveTimerRef.current = setTimeout(() => {
            savePlan(plan).catch(() => {
                // Best-effort — localStorage still holds a copy.
            });
        }, 800);
    }, [user]);

    useEffect(() => () => clearTimeout(saveTimerRef.current), []);

    const addToPlan = useCallback(() => {
        if (!course) return;
        const plan = addCourseToLocalPlan(course);
        setOnPlan(true);
        scheduleSave(plan);
    }, [course, scheduleSave]);

    const removeFromPlan = useCallback(() => {
        if (!course) return;
        const plan = removeCourseFromLocalPlan(course.courseCode);
        setOnPlan(false);
        scheduleSave(plan);
    }, [course, scheduleSave]);

    return { onPlan, addToPlan, removeFromPlan };
}
