import React, { useState, useEffect } from 'react';
import './FullTimetable.css';

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

function generateTimeOptions() {
    const options = [];
    for (let h = 8; h <= 21; h++) {
        ['00', '30'].forEach((m) => {
            if (h === 21 && m === '30') return;
            const hh = h.toString().padStart(2, '0');
            options.push({ value: `${hh}${m}`, label: `${hh}:${m}` });
        });
    }
    return options;
}

const TIME_OPTIONS = generateTimeOptions();

export default function EditTiming(props) {
    const { data, timetableData, setTimetableData, div_id } = props;

    const [tutorials, setTutorials] = useState([]);
    const [labs, setLabs] = useState([]);
    const [savedAt, setSavedAt] = useState(0);

    useEffect(() => {
        const courseData = timetableData[data.courseCode] || {};
        if (data.tutorial) {
            setTutorials(courseData.tutorial && courseData.tutorial.length > 0 ? courseData.tutorial : []);
        }
        if (data.lab) {
            setLabs(courseData.lab && courseData.lab.length > 0 ? courseData.lab : []);
        }
    }, [data.courseCode, timetableData, data.tutorial, data.lab]);

    const addTutorial = () => {
        setTutorials([...tutorials, { day: '0', start: '0800', end: '0900', location: '' }]);
    };

    const updateTutorial = (index, field, value) => {
        const next = [...tutorials];
        next[index] = { ...next[index], [field]: value };
        setTutorials(next);
    };

    const removeTutorial = (index) => {
        setTutorials(tutorials.filter((_, i) => i !== index));
    };

    const addLab = () => {
        setLabs([...labs, { day: '0', start: '1400', end: '1600', location: '' }]);
    };

    const updateLab = (index, field, value) => {
        const next = [...labs];
        next[index] = { ...next[index], [field]: value };
        setLabs(next);
    };

    const removeLab = (index) => {
        setLabs(labs.filter((_, i) => i !== index));
    };

    const saveData = () => {
        const courseCode = data.courseCode;
        const next = { ...timetableData[courseCode] };
        if (data.tutorial) {
            const valid = tutorials
                .filter((t) => t.day !== '0' && t.start && t.end && Number(t.start) < Number(t.end))
                .map((t) => ({ day: t.day, start: t.start, end: t.end, location: t.location || '' }));
            next.tutorial = valid.length > 0 ? valid : null;
        }
        if (data.lab) {
            const valid = labs
                .filter((l) => l.day !== '0' && l.start && l.end && Number(l.start) < Number(l.end))
                .map((l) => ({ day: l.day, start: l.start, end: l.end, location: l.location || '' }));
            next.lab = valid.length > 0 ? valid : null;
        }
        setTimetableData((prev) => ({ ...prev, [courseCode]: next }));
        setSavedAt(Date.now());
    };

    const showSaved = savedAt && Date.now() - savedAt < 4000;

    useEffect(() => {
        if (!savedAt) return;
        const t = setTimeout(() => setSavedAt(0), 2500);
        return () => clearTimeout(t);
    }, [savedAt]);

    const renderSession = (session, index, kind) => {
        const update = kind === 'tutorial' ? updateTutorial : updateLab;
        const remove = kind === 'tutorial' ? removeTutorial : removeLab;
        return (
            <div key={index} className="edit-timing__session">
                <div className="edit-timing__session-row">
                    <span className="edit-timing__session-num">
                        {kind === 'tutorial' ? 'Tutorial' : 'Lab'} {index + 1}
                    </span>
                    <button
                        type="button"
                        className="edit-timing__remove"
                        onClick={() => remove(index)}
                    >
                        Remove
                    </button>
                </div>
                <div className="edit-timing__grid">
                    <div className="edit-timing__cell">
                        <label>Day</label>
                        <select
                            value={session.day}
                            onChange={(e) => update(index, 'day', e.target.value)}
                        >
                            <option value="0" disabled>—</option>
                            {DAYS.map((d) => <option key={d} value={d}>{d}</option>)}
                        </select>
                    </div>
                    <div className="edit-timing__cell">
                        <label>Start</label>
                        <select
                            value={session.start}
                            onChange={(e) => update(index, 'start', e.target.value)}
                        >
                            {TIME_OPTIONS.map((opt) => (
                                <option key={opt.value} value={opt.value}>{opt.label}</option>
                            ))}
                        </select>
                    </div>
                    <div className="edit-timing__cell">
                        <label>End</label>
                        <select
                            value={session.end}
                            onChange={(e) => update(index, 'end', e.target.value)}
                        >
                            {TIME_OPTIONS.map((opt) => (
                                <option key={opt.value} value={opt.value}>{opt.label}</option>
                            ))}
                        </select>
                    </div>
                    <div className="edit-timing__cell edit-timing__venue">
                        <label>Venue</label>
                        <input
                            type="text"
                            placeholder={kind === 'tutorial' ? 'e.g. IIA 201' : 'e.g. LH 111'}
                            value={session.location || ''}
                            onChange={(e) => update(index, 'location', e.target.value)}
                        />
                    </div>
                </div>
            </div>
        );
    };

    return (
        <div id={div_id} className="edit-timing">
            <div className="edit-timing__heading">Edit sessions</div>

            {data.tutorial && (
                <div>
                    <div className="edit-timing__section-head">
                        <h5 className="edit-timing__section-title">Tutorials</h5>
                        <button type="button" className="edit-timing__add" onClick={addTutorial}>
                            + Add session
                        </button>
                    </div>
                    {tutorials.length === 0 ? (
                        <p className="edit-timing__empty">No tutorial sessions added.</p>
                    ) : (
                        tutorials.map((t, i) => renderSession(t, i, 'tutorial'))
                    )}
                </div>
            )}

            {data.lab && (
                <div>
                    <div className="edit-timing__section-head">
                        <h5 className="edit-timing__section-title">Labs</h5>
                        <button type="button" className="edit-timing__add" onClick={addLab}>
                            + Add session
                        </button>
                    </div>
                    {labs.length === 0 ? (
                        <p className="edit-timing__empty">No lab sessions added.</p>
                    ) : (
                        labs.map((l, i) => renderSession(l, i, 'lab'))
                    )}
                </div>
            )}

            <div className="edit-timing__save-row">
                {showSaved && <span className="edit-timing__saved">Saved</span>}
                <button type="button" className="btn btn--sm btn--primary" onClick={saveData}>
                    Save
                </button>
            </div>
        </div>
    );
}
