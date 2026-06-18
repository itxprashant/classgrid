import React, { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import FormField from '../components/FormField/FormField';
import {
    buildRoomCatalog,
    filterRooms,
    getRoomPrefixes,
    roomToSlug,
} from '../utils/roomSchedule';
import { useSemesterData } from '../data/SemesterDataContext';
import SemesterDataGate from '../data/SemesterDataGate';
import './RoomSchedules.css';

const ITEMS_PER_PAGE = 48;

export default function RoomSchedules() {
    const { courses, extraOccupied } = useSemesterData();
    const { rooms, catalogHasVenues, catalogHasSessions } = useMemo(
        () => buildRoomCatalog(courses, extraOccupied),
        [courses, extraOccupied]
    );
    const prefixes = useMemo(() => getRoomPrefixes(rooms), [rooms]);

    const [searchTerm, setSearchTerm] = useState('');
    const [building, setBuilding] = useState('');
    const [page, setPage] = useState(1);

    const filteredRooms = useMemo(
        () => filterRooms(rooms, { search: searchTerm, prefix: building }),
        [rooms, searchTerm, building]
    );

    const displayedRooms = useMemo(
        () => filteredRooms.slice(0, page * ITEMS_PER_PAGE),
        [filteredRooms, page]
    );

    const hasMore = displayedRooms.length < filteredRooms.length;

    const handleSearchChange = (e) => {
        setSearchTerm(e.target.value);
        setPage(1);
    };

    return (
        <SemesterDataGate>
        <div className="rs">
            <header className="rs__head">
                <div className="rs__eyebrow">Campus</div>
                <h1 className="rs__title">
                    Room schedules, <em>all week</em>.
                </h1>
                <p className="rs__sub">
                    Browse every lecture hall in the catalog and open a room to see its weekly timetable
                    as a list or calendar grid.
                </p>
            </header>

            <div className="rs__actions">
                <Link to="/empty-halls" className="btn btn--primary">
                    Empty halls right now
                </Link>
                <p className="rs__actions-hint muted">
                    See which lecture halls are free at a chosen date and time.
                </p>
            </div>

            {!catalogHasVenues && (
                <div className="rs__notice panel" role="status">
                    <p>
                        <strong>Venues are not in the catalog yet.</strong> Wait for Room Allotment Chart of the current semester to be released.
                    </p>
                </div>
            )}

            {catalogHasVenues && !catalogHasSessions && rooms.length > 0 && (
                <div className="rs__notice panel" role="status">
                    <p>
                        Rooms are listed from the catalog, but no weekly slots are attached yet. Check that
                        course timing strings are populated.
                    </p>
                </div>
            )}

            <div className="rs__toolbar">
                <div className="rs__search">
                    <span className="rs__search-icon" aria-hidden="true">
                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <circle cx="11" cy="11" r="8" />
                            <line x1="21" y1="21" x2="16.65" y2="16.65" />
                        </svg>
                    </span>
                    <input
                        type="search"
                        placeholder="Search by room name…"
                        className="rs__search-input"
                        value={searchTerm}
                        onChange={handleSearchChange}
                        aria-label="Search rooms"
                    />
                    {searchTerm && (
                        <button
                            type="button"
                            className="rs__search-clear"
                            onClick={() => { setSearchTerm(''); setPage(1); }}
                            aria-label="Clear search"
                        >
                            ×
                        </button>
                    )}
                </div>
                <FormField label="Building" htmlFor="rs-building" className="rs__building-field form-field--sm">
                    <select
                        id="rs-building"
                        className="field field--mono rs__building"
                        value={building}
                        onChange={(e) => { setBuilding(e.target.value); setPage(1); }}
                    >
                        <option value="">All buildings</option>
                        {prefixes.map(({ code, count }) => (
                            <option key={code} value={code}>
                                {code} ({count})
                            </option>
                        ))}
                    </select>
                </FormField>
            </div>

            <p className="rs__count muted">
                {filteredRooms.length.toLocaleString()} room{filteredRooms.length === 1 ? '' : 's'}
                {searchTerm || building ? ' matching filters' : ' from catalog'}
            </p>

            {filteredRooms.length === 0 ? (
                <div className="rs__empty panel">
                    <p className="muted">No rooms match your search. Try another name or clear the building filter.</p>
                </div>
            ) : (
                <ul className="rs__grid">
                    {displayedRooms.map((room) => (
                        <li key={room.name}>
                            <Link to={`/rooms/${roomToSlug(room.name)}`} className="rs__card">
                                <span className="rs__card-name mono">{room.name}</span>
                                <span className="rs__card-meta">
                                    <span className="badge">{room.prefix}</span>
                                    <span className="rs__card-sessions tnum">
                                        {room.sessionCount} session{room.sessionCount === 1 ? '' : 's'}
                                    </span>
                                </span>
                            </Link>
                        </li>
                    ))}
                </ul>
            )}

            {hasMore && (
                <div className="rs__more">
                    <button type="button" className="btn" onClick={() => setPage((p) => p + 1)}>
                        Load more
                    </button>
                </div>
            )}

        </div>
        </SemesterDataGate>
    );
}
