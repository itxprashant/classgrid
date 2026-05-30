import React, { useMemo } from 'react';
import './Timetable.css';
import TimetableElement from './TimetableElement';

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const HOURS = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];

function formatHour(h) {
    const suffix = h >= 12 ? 'PM' : 'AM';
    const hh = h === 0 ? 12 : h > 12 ? h - 12 : h;
    return `${hh} ${suffix}`;
}

function toMinutes(t) {
    return parseInt(t.substring(0, 2), 10) * 60 + parseInt(t.substring(2, 4), 10);
}

export default function TimetableGrid({ timetable, timetableData }) {
    const sessions = useMemo(() => {
        const result = [];
        timetable.forEach((course) => {
            const courseData = timetableData[course.courseCode];
            if (!courseData) return;
            const collect = (arr, type, fallbackHall) => {
                if (!arr) return;
                arr.forEach((s) => {
                    if (!s || !s.day || !DAYS.includes(s.day)) return;
                    result.push({
                        courseCode: course.courseCode,
                        type,
                        day: s.day,
                        start: s.start,
                        end: s.end,
                        location: s.location || fallbackHall || '',
                    });
                });
            };
            collect(courseData.lecture, 'Lecture', course.lectureHall);
            collect(courseData.tutorial, 'Tutorial');
            collect(courseData.lab, 'Lab');
        });
        return result;
    }, [timetable, timetableData]);

    const conflictSet = useMemo(() => {
        const set = new Set();
        for (let i = 0; i < sessions.length; i++) {
            for (let j = i + 1; j < sessions.length; j++) {
                const a = sessions[i];
                const b = sessions[j];
                if (a.day !== b.day) continue;
                if (a.courseCode === b.courseCode) continue;
                const aStart = toMinutes(a.start);
                const aEnd = toMinutes(a.end);
                const bStart = toMinutes(b.start);
                const bEnd = toMinutes(b.end);
                if (aStart < bEnd && bStart < aEnd) {
                    set.add(i);
                    set.add(j);
                }
            }
        }
        return set;
    }, [sessions]);

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
                            key={`${session.courseCode}-${session.type}-${session.day}-${session.start}-${idx}`}
                            data={{ day: session.day, start: session.start, end: session.end }}
                            course={session.courseCode}
                            lectureHall={session.location}
                            type={session.type}
                            conflict={conflictSet.has(idx)}
                        />
                    ))}

                    {sessions.length === 0 && (
                        <div className="tt__empty">
                            <div className="eyebrow">No sessions yet</div>
                            <p>Add a course from the search to see your week.</p>
                        </div>
                    )}
                </div>
            </div>
        </div>
        </div>
    );
}
