import React, { useState } from 'react';
import AcademicCalendarDialog from './AcademicCalendarDialog';

export default function AcademicCalendarButton({ className = 'btn btn--sm' }) {
    const [open, setOpen] = useState(false);

    return (
        <>
            <button
                type="button"
                className={className}
                onClick={() => setOpen(true)}
            >
                Holidays &amp; timetable changes
            </button>
            {open && <AcademicCalendarDialog onClose={() => setOpen(false)} />}
        </>
    );
}
