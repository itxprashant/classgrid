import React, { useMemo, useState } from 'react';
import { Link, useParams, Navigate } from 'react-router-dom';
import RoomWeekGrid from '../components/RoomSchedule/RoomWeekGrid';
import {
    buildRoomCatalog,
    formatHHMM,
    getSessionsForRoom,
    groupSessionsByDay,
    roomPrefix,
    sessionOverlapIndices,
    slugToRoom,
} from '../utils/roomSchedule';
import './RoomDetail.css';

const WEEKDAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

export default function RoomDetail() {
    const { roomSlug } = useParams();
    const roomName = slugToRoom(roomSlug);
    const { rooms, sessionsByRoom } = useMemo(() => buildRoomCatalog(), []);
    const [view, setView] = useState('list');

    const roomExists = rooms.some((r) => r.name === roomName);
    const sessions = useMemo(
        () => getSessionsForRoom(sessionsByRoom, roomName),
        [sessionsByRoom, roomName]
    );
    const byDay = useMemo(() => groupSessionsByDay(sessions), [sessions]);
    const conflictSet = useMemo(() => sessionOverlapIndices(sessions), [sessions]);
    const overlapCount = conflictSet.size;

    if (!roomName) {
        return <Navigate to="/rooms" replace />;
    }

    if (!roomExists) {
        return (
            <div className="rd">
                <div className="rd__empty panel">
                    <h1 className="rd__empty-title serif">Room not found</h1>
                    <p className="muted">
                        <span className="mono">{roomName}</span> is not in the semester catalog.
                    </p>
                    <Link to="/rooms" className="btn btn--primary">Back to all rooms</Link>
                </div>
            </div>
        );
    }

    return (
        <div className="rd">
            <nav className="rd__crumb" aria-label="Breadcrumb">
                <Link to="/rooms">Rooms</Link>
                <span aria-hidden="true">/</span>
                <span className="mono">{roomName}</span>
            </nav>

            <header className="rd__head">
                <div className="rd__eyebrow">{roomPrefix(roomName)}</div>
                <h1 className="rd__title serif">{roomName}</h1>
                <p className="rd__sub">
                    {sessions.length} session{sessions.length === 1 ? '' : 's'} this semester
                    {overlapCount > 0 && (
                        <span className="rd__warn">
                            {' '}· {overlapCount} overlap{overlapCount === 1 ? '' : 's'} flagged
                        </span>
                    )}
                </p>
            </header>

            <div className="rd__toolbar">
                <div className="rd__view-toggle" role="tablist" aria-label="Schedule view">
                    <button
                        type="button"
                        role="tab"
                        aria-selected={view === 'list'}
                        className={'rd__view-btn' + (view === 'list' ? ' is-active' : '')}
                        onClick={() => setView('list')}
                    >
                        List
                    </button>
                    <button
                        type="button"
                        role="tab"
                        aria-selected={view === 'calendar'}
                        className={'rd__view-btn' + (view === 'calendar' ? ' is-active' : '')}
                        onClick={() => setView('calendar')}
                    >
                        Calendar
                    </button>
                </div>
                <Link to="/empty-halls" className="btn btn--sm">
                    Check if free now
                </Link>
            </div>

            {sessions.length === 0 ? (
                <div className="rd__empty panel">
                    <p className="muted">
                        No classes are scheduled in this room in the current catalog. It may still appear
                        on the rooms list if it is referenced without timing data.
                    </p>
                </div>
            ) : view === 'calendar' ? (
                <RoomWeekGrid sessions={sessions} />
            ) : (
                <div className="rd__list">
                    {WEEKDAYS.map((day) => {
                        const daySessions = byDay[day] || [];
                        if (daySessions.length === 0) return null;
                        return (
                            <section key={day} className="rd__day panel">
                                <h2 className="rd__day-title">{day}</h2>
                                <ul className="rd__sessions">
                                    {daySessions.map((session, idx) => {
                                        const globalIdx = sessions.indexOf(session);
                                        const conflict = conflictSet.has(globalIdx);
                                        return (
                                            <li
                                                key={`${session.courseCode}-${session.type}-${session.start}-${idx}`}
                                                className={'rd__session' + (conflict ? ' rd__session--conflict' : '')}
                                            >
                                                <span className="rd__session-time mono">
                                                    {formatHHMM(session.start)}–{formatHHMM(session.end)}
                                                </span>
                                                <div className="rd__session-body">
                                                    {session.courseCode ? (
                                                        <Link
                                                            to={`/course/${session.courseCode}`}
                                                            className="rd__session-code mono"
                                                        >
                                                            {session.courseCode}
                                                        </Link>
                                                    ) : (
                                                        <span className="rd__session-code mono">{session.courseName}</span>
                                                    )}
                                                    <span className="rd__session-type badge">{session.type}</span>
                                                    {session.courseCode && (
                                                        <span className="rd__session-name">{session.courseName}</span>
                                                    )}
                                                    {session.instructor && (
                                                        <span className="rd__session-instr muted">{session.instructor}</span>
                                                    )}
                                                </div>
                                            </li>
                                        );
                                    })}
                                </ul>
                            </section>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
