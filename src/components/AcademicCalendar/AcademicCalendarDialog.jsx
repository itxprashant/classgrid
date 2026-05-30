import React, { useEffect } from 'react';
import AcademicCalendarContent from './AcademicCalendarContent';
import './AcademicCalendar.css';
import './AcademicCalendarDialog.css';

export default function AcademicCalendarDialog({ onClose }) {
    useEffect(() => {
        const onKey = (e) => {
            if (e.key === 'Escape') onClose();
        };
        document.addEventListener('keydown', onKey);
        return () => document.removeEventListener('keydown', onKey);
    }, [onClose]);

    return (
        <div className="acal-backdrop" onClick={onClose} role="presentation">
            <div
                className="acal-dialog panel"
                role="dialog"
                aria-modal="true"
                aria-labelledby="acal-dialog-title"
                onClick={(e) => e.stopPropagation()}
            >
                <div className="acal-dialog__head">
                    <h2 id="acal-dialog-title" className="acal-dialog__title">
                        Holidays &amp; timetable changes
                    </h2>
                    <button type="button" className="btn btn--sm btn--ghost" onClick={onClose}>
                        Close
                    </button>
                </div>
                <div className="acal-dialog__body">
                    <AcademicCalendarContent embedded />
                </div>
            </div>
        </div>
    );
}
