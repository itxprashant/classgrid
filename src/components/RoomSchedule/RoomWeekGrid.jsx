import React, { useMemo } from 'react';
import TimetableElement from '../Timetable/TimetableElement';
import '../Timetable/Timetable.css';
import { sessionOverlapIndices } from '../../utils/roomSchedule';

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const HOURS = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];

function formatHour(h) {
    const suffix = h >= 12 ? 'PM' : 'AM';
    const hh = h === 0 ? 12 : h > 12 ? h - 12 : h;
    return `${hh} ${suffix}`;
}

export default function RoomWeekGrid({ sessions }) {
    const conflictSet = useMemo(() => sessionOverlapIndices(sessions), [sessions]);

    return (
        <div className="tt-scroll">
            <div className="tt">
                <div className="tt__hours">
                    <div className="tt__hour-pad" />
                    {HOURS.map((h) => (
                        <div key={h} className="tt__hour">
                            <span>{formatHour(h)}</span>
                        </div>
                    ))}
                </div>

                <div className="tt__board">
                    <div className="tt__days">
                        {DAYS.map((day) => (
                            <div key={day} className="tt__day-head">
                                <span className="tt__day-name">{day}</span>
                                <span className="tt__day-abbr" aria-hidden="true">{day.slice(0, 3)}</span>
                            </div>
                        ))}
                    </div>

                    <div className="tt__plot">
                        <div className="tt__lines" aria-hidden="true">
                            {HOURS.map((h, i) => (
                                <div key={h} className={'tt__hline' + (i === 0 ? ' tt__hline--first' : '')} />
                            ))}
                        </div>
                        <div className="tt__cols" aria-hidden="true">
                            {DAYS.map((day) => (
                                <div key={day} className="tt__col" />
                            ))}
                        </div>

                        {sessions.map((session, idx) => (
                            <TimetableElement
                                key={`${session.courseCode || 'extra'}-${session.type}-${session.day}-${session.start}-${idx}`}
                                data={{ day: session.day, start: session.start, end: session.end }}
                                course={session.courseCode || session.courseName}
                                lectureHall=""
                                type={session.type}
                                conflict={conflictSet.has(idx)}
                            />
                        ))}

                        {sessions.length === 0 && (
                            <div className="tt__empty">
                                <div className="eyebrow">No sessions</div>
                                <p>Nothing is scheduled in this room for the semester catalog.</p>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
