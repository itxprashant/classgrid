import React from 'react';
import { Link } from 'react-router-dom';
import { instructorsFromCourse } from '../../utils/instructors';
import './InstructorLinks.css';

export default function InstructorLinks({ course, instructors: instructorsProp, className = '' }) {
    const list = Array.isArray(instructorsProp) && instructorsProp.length
        ? instructorsProp
            .map((i) => ({
                name: (i?.name || '').trim(),
                email: (i?.email || '').trim().toLowerCase() || null,
            }))
            .filter((i) => i.name || i.email)
        : instructorsFromCourse(course);
    if (!list.length) return null;

    return (
        <span className={`instr-links ${className}`.trim()}>
            {list.map((inst, index) => (
                <React.Fragment key={`${inst.email || inst.name}-${index}`}>
                    {index > 0 && <span className="instr-links__sep"> · </span>}
                    {inst.email ? (
                        <Link to={`/professor/${encodeURIComponent(inst.email)}`} className="instr-links__link">
                            {inst.name || inst.email}
                        </Link>
                    ) : (
                        <span className="instr-links__plain">{inst.name}</span>
                    )}
                </React.Fragment>
            ))}
        </span>
    );
}
