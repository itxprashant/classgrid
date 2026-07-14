import React, { useRef } from 'react';
import AcademicCalendarContent from './AcademicCalendarContent';
import { useDialogA11y } from '../../utils/useDialogA11y';
import './AcademicCalendar.css';
import './AcademicCalendarDialog.css';

export default function AcademicCalendarDialog({ onClose }) {
    const dialogRef = useRef(null);
    useDialogA11y(dialogRef, { onClose, active: true });

    return (
        <div className="acal-backdrop" onClick={onClose} role="presentation">
            <div
                ref={dialogRef}
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
