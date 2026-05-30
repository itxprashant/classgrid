/**
 * Guest personal events — persisted in localStorage (same key as legacy My Calendar).
 * Signed-in users use Postgres via personalEventsApi.js instead.
 */

import {
    loadEvents,
    saveEvents,
    addEvent,
    updateEvent,
    deleteEvent,
    eventActorFromUser,
} from './calendarEvents';

function inRange(date, from, to) {
    if (from && date < from) return false;
    if (to && date > to) return false;
    return true;
}

function toPersonalEvent(e) {
    return {
        id: e.id,
        date: e.date,
        title: e.title,
        type: e.type,
        schedule: e.schedule || 'fullday',
        time: e.time,
        start: e.start,
        end: e.end,
        note: e.note,
        createdBy: e.createdBy,
        updatedBy: e.updatedBy,
        isPersonal: true,
    };
}

/** Personal events stored locally for the given date range. */
export function loadLocalPersonalEvents({ from, to }) {
    return loadEvents()
        .filter((e) => inRange(e.date, from, to))
        .map(toPersonalEvent);
}

export function createLocalPersonalEvent(partial, actor = null) {
    const next = addEvent(loadEvents(), partial, actor || eventActorFromUser(null));
    saveEvents(next);
    const created = next[next.length - 1];
    return toPersonalEvent(created);
}

export function patchLocalPersonalEvent(id, partial, actor = null) {
    const stamp = actor || eventActorFromUser(null);
    const next = updateEvent(loadEvents(), id, partial, stamp);
    saveEvents(next);
    const updated = next.find((e) => e.id === id);
    return updated ? toPersonalEvent(updated) : null;
}

export function removeLocalPersonalEvent(id) {
    const next = deleteEvent(loadEvents(), id);
    saveEvents(next);
    return id;
}

/** Push guest events to the API after login, then clear local copies. */
export async function migrateLocalPersonalEvents(createPersonalEvent) {
    const local = loadEvents();
    if (local.length === 0) return 0;

    for (const evt of local) {
        await createPersonalEvent({
            date: evt.date,
            title: evt.title,
            type: evt.type,
            schedule: evt.schedule || 'fullday',
            time: evt.time,
            start: evt.start,
            end: evt.end,
            note: evt.note,
        });
    }
    saveEvents([]);
    return local.length;
}
