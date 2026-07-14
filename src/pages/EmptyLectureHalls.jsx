import React, { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useSemesterData } from '../data/SemesterDataContext';
import SemesterDataGate from '../data/SemesterDataGate';
import { describeAcademicDay } from '../utils/semesterSchedule';
import { computeEmptyHallsState } from '../utils/emptyHalls';
import { normalizeRoomName, roomToSlug, DEFAULT_ROOM_BUILDING_TAB, getBuildingTabCountsForRoomNames, filterEntriesByBuilding, groupLhEntriesByFloor } from '../utils/roomSchedule';
import {
    fetchOccupiedRooms,
    createOccupiedRoom,
    removeOccupiedRoom,
} from '../utils/occupiedRoomsApi';
import './EmptyLectureHalls.css';
import ReportContentPanel from '../components/ReportContent/ReportContentPanel';
import FormField from '../components/FormField/FormField';
import { useDialogA11y } from '../utils/useDialogA11y';

function formatDateYMD(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function formatDisplayDate(date) {
    return date.toLocaleDateString('en-IN', {
        weekday: 'long',
        day: 'numeric',
        month: 'short',
        year: 'numeric',
    });
}

function formatHHMM(value) {
    const s = String(value).padStart(4, '0');
    return `${s.slice(0, 2)}:${s.slice(2, 4)}`;
}

function addMinutesToHHMM(hhmm, minutes) {
    const s = String(hhmm).padStart(4, '0');
    let h = parseInt(s.slice(0, 2), 10);
    let m = parseInt(s.slice(2, 4), 10) + minutes;
    h += Math.floor(m / 60);
    m %= 60;
    if (m < 0) {
        h -= 1;
        m += 60;
    }
    h = Math.min(23, Math.max(0, h));
    return `${String(h).padStart(2, '0')}${String(m).padStart(2, '0')}`;
}

const EmptyLectureHalls = () => {
    const { user, login } = useAuth();
    const { courses, extraOccupied, schedule } = useSemesterData();
    const termStart = schedule?.SEMESTER?.classesStart || '';
    const termEnd = schedule?.SEMESTER?.lastTeachingDay || '';
    const [currentTime, setCurrentTime] = useState(new Date());
    const [isCustomSchedule, setIsCustomSchedule] = useState(false);
    const [manualMarkings, setManualMarkings] = useState([]);
    const [markingsLoading, setMarkingsLoading] = useState(false);
    const [selectedMarking, setSelectedMarking] = useState(null);
    const [markDialog, setMarkDialog] = useState(null);
    const [markEndTime, setMarkEndTime] = useState('');
    const [markNote, setMarkNote] = useState('');
    const [markSubmitting, setMarkSubmitting] = useState(false);
    const [markError, setMarkError] = useState(null);
    const [markingDialogView, setMarkingDialogView] = useState('detail');
    const [building, setBuilding] = useState(DEFAULT_ROOM_BUILDING_TAB);

    useEffect(() => {
        const timer = setInterval(() => {
            if (!isCustomSchedule) setCurrentTime(new Date());
        }, 60000);
        return () => clearInterval(timer);
    }, [isCustomSchedule]);

    const timeValueNum = useMemo(() => {
        const h = currentTime.getHours();
        const m = currentTime.getMinutes();
        return h * 100 + m;
    }, [currentTime]);

    const selectedDate = useMemo(() => formatDateYMD(currentTime), [currentTime]);

    const loadMarkings = useCallback(async () => {
        setMarkingsLoading(true);
        try {
            const markings = await fetchOccupiedRooms({
                date: selectedDate,
                time: timeValueNum,
            });
            setManualMarkings(markings);
        } catch {
            setManualMarkings([]);
        } finally {
            setMarkingsLoading(false);
        }
    }, [selectedDate, timeValueNum]);

    useEffect(() => {
        loadMarkings();
    }, [loadMarkings]);

    const {
        displayEntries,
        allHalls,
        freeCount,
        markedCount,
        timetableOccupiedCount,
        academic,
    } = useMemo(
        () =>
            computeEmptyHallsState({
                courses,
                extraOccupied,
                manualMarkings,
                at: currentTime,
            }),
        [courses, extraOccupied, currentTime, manualMarkings]
    );

    const buildingTabs = useMemo(
        () => getBuildingTabCountsForRoomNames(displayEntries.map((e) => e.room)),
        [displayEntries]
    );

    const filteredEntries = useMemo(
        () => filterEntriesByBuilding(displayEntries, building),
        [displayEntries, building]
    );

    const lhcFloorSections = useMemo(
        () => (building === 'LHC' ? groupLhEntriesByFloor(filteredEntries) : null),
        [building, filteredEntries]
    );

    const hallEntryByRoom = useMemo(() => {
        const map = new Map();
        displayEntries.forEach((entry) => map.set(entry.room, entry));
        return map;
    }, [displayEntries]);

    const handleDateChange = (e) => {
        const value = e.target.value;
        if (!value) return;
        const [y, m, d] = value.split('-').map(Number);
        const newTime = new Date(currentTime);
        newTime.setFullYear(y, m - 1, d);
        setCurrentTime(newTime);
        setIsCustomSchedule(true);
    };

    const handleTimeChange = (e) => {
        const value = e.target.value;
        if (!value) return;
        const [hours, minutes] = value.split(':');
        const newTime = new Date(currentTime);
        newTime.setHours(parseInt(hours, 10));
        newTime.setMinutes(parseInt(minutes, 10));
        setCurrentTime(newTime);
        setIsCustomSchedule(true);
    };

    const handleReset = () => {
        setIsCustomSchedule(false);
        setCurrentTime(new Date());
    };

    const openMarkDialog = (room) => {
        const start = `${String(currentTime.getHours()).padStart(2, '0')}${String(currentTime.getMinutes()).padStart(2, '0')}`;
        const end = addMinutesToHHMM(start, 60);
        setMarkEndTime(`${end.slice(0, 2)}:${end.slice(2, 4)}`);
        setMarkNote('');
        setMarkError(null);
        setMarkDialog({ room: normalizeRoomName(room) });
    };

    const closeMarkDialog = () => {
        setMarkDialog(null);
        setMarkError(null);
    };

    const closeMarkingDetail = useCallback(() => {
        setSelectedMarking(null);
        setMarkingDialogView('detail');
    }, []);

    const markingDetailDialogRef = useRef(null);
    const markRoomDialogRef = useRef(null);
    useDialogA11y(markingDetailDialogRef, { onClose: closeMarkingDetail, active: !!selectedMarking });
    useDialogA11y(markRoomDialogRef, { onClose: closeMarkDialog, active: !!markDialog });

    const submitMark = async () => {
        if (!markDialog) return;
        setMarkSubmitting(true);
        setMarkError(null);
        const start = `${String(currentTime.getHours()).padStart(2, '0')}${String(currentTime.getMinutes()).padStart(2, '0')}`;
        const endParts = markEndTime.split(':');
        const end = endParts.length === 2
            ? `${endParts[0]}${endParts[1]}`
            : '';
        try {
            await createOccupiedRoom({
                room: markDialog.room,
                date: selectedDate,
                start,
                end,
                ...(markNote.trim() ? { note: markNote.trim() } : {}),
            });
            closeMarkDialog();
            await loadMarkings();
        } catch (e) {
            setMarkError(e.message || 'Could not save marking');
        } finally {
            setMarkSubmitting(false);
        }
    };

    const clearMarking = async (marking) => {
        try {
            await removeOccupiedRoom(marking.id);
            setSelectedMarking(null);
            await loadMarkings();
        } catch (e) {
            setSelectedMarking((prev) => (prev ? { ...prev, _err: e.message } : null));
        }
    };

    const timeValue = `${String(currentTime.getHours()).padStart(2, '0')}:${String(currentTime.getMinutes()).padStart(2, '0')}`;

    const renderHallRow = (room) => {
        const entry = hallEntryByRoom.get(room);
        const isMarked = entry && entry.status === 'marked';
        const scheduleTo = `/rooms/${roomToSlug(room)}`;
        return (
            <div
                key={room}
                className={'eh__hall-row' + (isMarked ? ' eh__hall-row--marked' : '')}
            >
                <Link
                    to={scheduleTo}
                    className={'eh__hall' + (isMarked ? ' eh__hall--marked' : '')}
                >
                    {room}
                </Link>
                {isMarked ? (
                    <button
                        type="button"
                        className="eh__hall-action"
                        onClick={() => {
                            setMarkingDialogView('detail');
                            setSelectedMarking(entry.marking);
                        }}
                        aria-label={`Who marked ${room} occupied`}
                    >
                        Details
                    </button>
                ) : user ? (
                    <button
                        type="button"
                        className="eh__hall-action"
                        onClick={() => openMarkDialog(room)}
                    >
                        Mark
                    </button>
                ) : (
                    <button
                        type="button"
                        className="eh__hall-action eh__hall-action--ghost"
                        onClick={login}
                    >
                        Sign in
                    </button>
                )}
            </div>
        );
    };

    return (
        <SemesterDataGate>
        <div className="eh">
            <header className="eh__head">
                <div className="eh__eyebrow">Right now · live</div>
                <h1 className="eh__title">
                    Free rooms, <em>by hour</em>.
                </h1>
                <p className="eh__sub">
                    All campus rooms from the catalog (lecture, tutorial, and lab slots) cross-referenced
                    against the timetable for the chosen date. Red rooms are marked occupied outside the
                    official allotment. Open a room name for its weekly schedule.
                </p>
            </header>

            <div className="eh__controls">
                <FormField label="Date" htmlFor="eh-day" className="eh__control form-field--sm">
                    <input
                        id="eh-day"
                        type="date"
                        className="field field--mono"
                        value={selectedDate}
                        min={termStart}
                        max={termEnd}
                        onChange={handleDateChange}
                    />
                    {academic.type === 'swapped' && (
                        <span className="eh__day-swap muted">
                            {formatDisplayDate(currentTime)} → {academic.effectiveDay} timetable
                        </span>
                    )}
                </FormField>
                <FormField label="Time" htmlFor="eh-time" className="eh__control form-field--sm">
                    <input
                        id="eh-time"
                        type="time"
                        className="field field--mono"
                        value={timeValue}
                        onChange={handleTimeChange}
                    />
                </FormField>
                <div className="eh__control eh__control--inline">
                    {isCustomSchedule ? (
                        <button type="button" className="btn btn--sm" onClick={handleReset}>
                            Reset to now
                        </button>
                    ) : (
                        <span className="eh__live">
                            <span className="eh__live-dot" aria-hidden="true" />
                            Updating live
                        </span>
                    )}
                </div>
            </div>

            {academic.type !== 'normal' && (
                <div className={`eh__notice eh__notice--${academic.hasClasses ? 'swap' : 'off'}`} role="status">
                    <span className="eh__notice-dot" aria-hidden="true" />
                    <span className="eh__notice-text">{describeAcademicDay(academic)}</span>
                    {!academic.hasClasses && (
                        <span className="eh__notice-meta">All halls free per the timetable.</span>
                    )}
                </div>
            )}

            <div className="eh__stats">
                <div className="eh__stat">
                    <span className="eh__stat-label">Free</span>
                    <span className="eh__stat-value tnum">{freeCount}</span>
                </div>
                <div className="eh__stat">
                    <span className="eh__stat-label">Marked occupied</span>
                    <span className="eh__stat-value tnum eh__stat-value--warn">{markedCount}</span>
                </div>
                <div className="eh__stat">
                    <span className="eh__stat-label">Timetable occupied</span>
                    <span className="eh__stat-value tnum">{timetableOccupiedCount}</span>
                </div>
                <div className="eh__stat">
                    <span className="eh__stat-label">Total tracked</span>
                    <span className="eh__stat-value tnum">{allHalls.length}</span>
                </div>
            </div>

            <div className="eh__tabs" role="tablist" aria-label="Building">
                {buildingTabs.map(({ code, count }) => (
                    <button
                        key={code}
                        type="button"
                        role="tab"
                        aria-selected={building === code}
                        className={'eh__tab' + (building === code ? ' is-active' : '')}
                        onClick={() => setBuilding(code)}
                    >
                        {code}
                        <span className="eh__tab-count tnum">{count}</span>
                    </button>
                ))}
            </div>

            {markingsLoading && displayEntries.length === 0 ? (
                <p className="eh__loading muted">Loading room markings…</p>
            ) : displayEntries.length === 0 ? (
                <div className="empty">
                    <strong>Every tracked room is occupied</strong>
                    Try a different date or time, or check back later.
                </div>
            ) : filteredEntries.length === 0 ? (
                <div className="empty">
                    <strong>No rooms in {building} at this time</strong>
                    Try another building tab, date, or time.
                </div>
            ) : lhcFloorSections ? (
                <div className="eh__groups">
                    {lhcFloorSections.map(({ floor, label, entries }) => (
                        <section key={floor} className="eh__group">
                            <header className="eh__group-head">
                                <h2 className="eh__floor-title">{label}</h2>
                                <span className="eh__group-rule" aria-hidden="true" />
                            </header>
                            <div className="eh__halls">
                                {entries.map((entry) => renderHallRow(entry.room))}
                            </div>
                        </section>
                    ))}
                </div>
            ) : (
                <div className="eh__groups">
                    <section className="eh__group">
                        <header className="eh__group-head">
                            <h2 className="eh__group-title">
                                <span className="mono">{building}</span>
                                <span className="muted tnum">{filteredEntries.length}</span>
                            </h2>
                            <span className="eh__group-rule" aria-hidden="true" />
                        </header>
                        <div className="eh__halls">
                            {filteredEntries.map((entry) => renderHallRow(entry.room))}
                        </div>
                    </section>
                </div>
            )}

            <p className="eh__legend-hint muted">
                Green = free per timetable · Red = marked occupied · Room name → weekly schedule
                {user ? ' · Mark = manual occupancy for this date' : ''}
            </p>

            {selectedMarking && (
                <div
                    className="eh__dialog-backdrop"
                    onClick={closeMarkingDetail}
                    role="presentation"
                >
                    <div
                        ref={markingDetailDialogRef}
                        className="eh__dialog panel"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="eh-marked-title"
                        onClick={(e) => e.stopPropagation()}
                    >
                        {markingDialogView === 'report' ? (
                            <>
                                <div className="eh__dialog-head">
                                    <button
                                        type="button"
                                        className="btn btn--sm btn--ghost eh__dialog-back"
                                        onClick={() => setMarkingDialogView('detail')}
                                    >
                                        ← Back
                                    </button>
                                    <button
                                        type="button"
                                        className="btn btn--sm btn--ghost"
                                        onClick={() => {
                                            setSelectedMarking(null);
                                            setMarkingDialogView('detail');
                                        }}
                                        aria-label="Close"
                                    >
                                        ×
                                    </button>
                                </div>
                                <ReportContentPanel
                                    compact
                                    targetKind="occupied_room"
                                    targetId={selectedMarking.id}
                                    contextLabel={`${selectedMarking.room} · ${selectedMarking.date}`}
                                    onDone={() => {
                                        setSelectedMarking(null);
                                        setMarkingDialogView('detail');
                                    }}
                                    onCancel={() => setMarkingDialogView('detail')}
                                />
                            </>
                        ) : (
                            <>
                        <div className="eh__dialog-head">
                            <h2 id="eh-marked-title" className="eh__dialog-title">
                                {selectedMarking.room}
                            </h2>
                            <button
                                type="button"
                                className="btn btn--sm btn--ghost"
                                onClick={() => {
                                    setSelectedMarking(null);
                                    setMarkingDialogView('detail');
                                }}
                                aria-label="Close"
                            >
                                ×
                            </button>
                        </div>
                        <p className="eh__dialog-lead">Occupied — not listed on the official room allotment.</p>
                        <p className="eh__dialog-link-row">
                            <Link
                                to={`/rooms/${roomToSlug(selectedMarking.room)}`}
                                className="btn btn--sm btn--ghost"
                            >
                                Weekly schedule
                            </Link>
                            {user && (
                                <button
                                    type="button"
                                    className="btn btn--sm btn--ghost"
                                    onClick={() => setMarkingDialogView('report')}
                                >
                                    Report marking
                                </button>
                            )}
                        </p>
                        <dl className="eh__dialog-meta">
                            <div>
                                <dt>Date</dt>
                                <dd>{selectedMarking.date}</dd>
                            </div>
                            <div>
                                <dt>Marked by</dt>
                                <dd>{selectedMarking.markedBy.name}</dd>
                            </div>
                            <div>
                                <dt>Time</dt>
                                <dd className="mono">
                                    {formatHHMM(selectedMarking.start)}–{formatHHMM(selectedMarking.end)}
                                </dd>
                            </div>
                            {selectedMarking.note && (
                                <div>
                                    <dt>Note</dt>
                                    <dd>{selectedMarking.note}</dd>
                                </div>
                            )}
                        </dl>
                        {selectedMarking._err && (
                            <p className="eh__dialog-error" role="alert">{selectedMarking._err}</p>
                        )}
                        {user &&
                            selectedMarking.markedBy.kerberos &&
                            user.kerberos &&
                            selectedMarking.markedBy.kerberos.toLowerCase() === user.kerberos.toLowerCase() && (
                            <div className="eh__dialog-actions">
                                <button
                                    type="button"
                                    className="btn btn--ghost"
                                    onClick={() => clearMarking(selectedMarking)}
                                >
                                    Remove marking
                                </button>
                            </div>
                        )}
                        </>
                        )}
                    </div>
                </div>
            )}

            {markDialog && (
                <div
                    className="eh__dialog-backdrop"
                    onClick={closeMarkDialog}
                    role="presentation"
                >
                    <div
                        ref={markRoomDialogRef}
                        className="eh__dialog panel"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="eh-mark-title"
                        onClick={(e) => e.stopPropagation()}
                    >
                        <div className="eh__dialog-head">
                            <h2 id="eh-mark-title" className="eh__dialog-title">
                                Mark <span className="mono">{markDialog.room}</span> occupied
                            </h2>
                            <button
                                type="button"
                                className="btn btn--sm btn--ghost"
                                onClick={closeMarkDialog}
                                aria-label="Close"
                            >
                                ×
                            </button>
                        </div>
                        <p className="eh__dialog-hint">
                            For {formatDisplayDate(currentTime)} from {timeValue} until the end time below.
                            Markings apply to this date only.
                        </p>
                        <FormField label="Until" htmlFor="eh-mark-end" wide>
                            <input
                                id="eh-mark-end"
                                type="time"
                                className="field field--mono"
                                value={markEndTime}
                                onChange={(e) => setMarkEndTime(e.target.value)}
                            />
                        </FormField>
                        <FormField
                            label={<>Note <span className="muted">(optional)</span></>}
                            htmlFor="eh-mark-note"
                            wide
                        >
                            <input
                                id="eh-mark-note"
                                type="text"
                                className="field"
                                placeholder="Optional — e.g. club meeting"
                                value={markNote}
                                onChange={(e) => setMarkNote(e.target.value)}
                            />
                        </FormField>
                        {markError && (
                            <p className="eh__dialog-error" role="alert">{markError}</p>
                        )}
                        <div className="eh__dialog-actions">
                            <button type="button" className="btn btn--ghost" onClick={closeMarkDialog}>
                                Cancel
                            </button>
                            <button
                                type="button"
                                className="btn btn--primary"
                                onClick={submitMark}
                                disabled={markSubmitting}
                            >
                                {markSubmitting ? 'Saving…' : 'Mark occupied'}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
        </SemesterDataGate>
    );
};

export default EmptyLectureHalls;
