import React, {
    createContext,
    useCallback,
    useContext,
    useEffect,
    useMemo,
    useState,
} from 'react';
import { apiFetch } from '../auth/AuthContext';
import {
    createSemesterSchedule,
    setActiveSemesterSchedule,
} from '../utils/semesterSchedule';

const SemesterDataContext = createContext({
    loading: true,
    error: null,
    courses: [],
    explorerCourses: [],
    semesterCode: null,
    extraOccupied: [],
    schedule: null,
    retry: async () => {},
});

export function SemesterDataProvider({ children }) {
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [courses, setCourses] = useState([]);
    const [explorerCourses, setExplorerCourses] = useState([]);
    const [semesterCode, setSemesterCode] = useState(null);
    const [extraOccupied, setExtraOccupied] = useState([]);
    const [schedule, setSchedule] = useState(null);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const [catalogRes, explorerRes, scheduleRes, extraRes] = await Promise.all([
                apiFetch('/api/catalog'),
                apiFetch('/api/catalog/explorer'),
                apiFetch('/api/semester/schedule'),
                apiFetch('/api/extra-occupied'),
            ]);

            if (!catalogRes.ok) {
                throw new Error(catalogRes.status === 503 ? 'database_unavailable' : 'catalog_load_failed');
            }
            if (!explorerRes.ok) {
                throw new Error(explorerRes.status === 503 ? 'database_unavailable' : 'explorer_catalog_load_failed');
            }
            if (!scheduleRes.ok) {
                throw new Error(scheduleRes.status === 503 ? 'database_unavailable' : 'schedule_load_failed');
            }
            if (!extraRes.ok) {
                throw new Error(extraRes.status === 503 ? 'database_unavailable' : 'extra_occupied_load_failed');
            }

            const catalog = await catalogRes.json();
            const explorer = await explorerRes.json();
            const scheduleData = await scheduleRes.json();
            const extraData = await extraRes.json();

            const courseList = Array.isArray(catalog.courses) ? catalog.courses : [];
            setCourses(courseList);
            setExplorerCourses(Array.isArray(explorer.courses) ? explorer.courses : courseList);
            setSemesterCode(catalog.semesterCode || scheduleData.semester?.code || null);
            setExtraOccupied(Array.isArray(extraData.slots) ? extraData.slots : []);

            const sched = createSemesterSchedule(scheduleData);
            setActiveSemesterSchedule(sched);
            setSchedule(sched);
        } catch (e) {
            setError(e.message || 'Could not load semester data');
            setCourses([]);
            setExplorerCourses([]);
            setExtraOccupied([]);
            setSchedule(null);
            setActiveSemesterSchedule(null);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        load();
    }, [load]);

    const value = useMemo(
        () => ({
            loading,
            error,
            courses,
            explorerCourses,
            semesterCode,
            extraOccupied,
            schedule,
            retry: load,
        }),
        [loading, error, courses, explorerCourses, semesterCode, extraOccupied, schedule, load]
    );

    return (
        <SemesterDataContext.Provider value={value}>
            {children}
        </SemesterDataContext.Provider>
    );
}

export function useSemesterData() {
    return useContext(SemesterDataContext);
}

export function useSemesterSchedule() {
    const { schedule, loading, error } = useSemesterData();
    return { schedule, loading, error };
}
