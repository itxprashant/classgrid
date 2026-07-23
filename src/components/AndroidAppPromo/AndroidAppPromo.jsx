import React, { useEffect, useState } from 'react';
import { apiFetch } from '../../auth/AuthContext';
import './AndroidAppPromo.css';

const DEFAULT_APK_URL = 'https://classgrid.devclub.in/app/classgrid.apk';
const DEFAULT_VERSION = '1.0.0';

function AndroidIcon({ size = 16 }) {
    return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M17.6 9.48l1.84-3.18a.5.5 0 10-.87-.5l-1.86 3.22A7.93 7.93 0 0012 8c-1.68 0-3.23.52-4.51 1.4L5.63 5.8a.5.5 0 10-.87.5L6.6 9.48C4.45 11.05 3 13.37 3 16h18c0-2.63-1.45-4.95-3.4-6.52zM8.5 14.25a1 1 0 110-2 1 1 0 010 2zm7 0a1 1 0 110-2 1 1 0 010 2z" />
        </svg>
    );
}

export default function AndroidAppPromo({ variant = 'banner' }) {
    const [apkUrl, setApkUrl] = useState(DEFAULT_APK_URL);
    const [version, setVersion] = useState(DEFAULT_VERSION);

    useEffect(() => {
        let cancelled = false;
        apiFetch('/api/app/version')
            .then(async (res) => {
                if (!res.ok) return;
                const data = await res.json();
                const android = data?.android;
                if (!android || cancelled) return;
                if (android.downloadUrl) setApkUrl(android.downloadUrl);
                if (android.version) setVersion(android.version);
            })
            .catch(() => {});
        return () => { cancelled = true; };
    }, []);

    if (variant === 'sidebar') {
        return (
            <aside
                className="android-promo android-promo--sidebar"
                aria-labelledby="android-promo-title"
            >
                <div className="android-promo__sidebar-top">
                    <div className="android-promo__copy">
                        <p id="android-promo-title" className="android-promo__title">
                            Take ClassGrid anywhere.
                        </p>
                        <p className="android-promo__tagline">
                            Your timetable on Android — classes, calendar, and reminders.
                        </p>
                        <ul className="android-promo__features">
                            <li>
                                <span className="android-promo__feature-icon" aria-hidden="true">
                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v3m0 12v3M3 12h3m12 0h3M5.6 5.6l2.1 2.1m8.6 8.6l2.1 2.1M5.6 18.4l2.1-2.1m8.6-8.6l2.1-2.1" />
                                    </svg>
                                </span>
                                Offline timetable access
                            </li>
                            <li>
                                <span className="android-promo__feature-icon" aria-hidden="true">
                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                        <path strokeLinecap="round" strokeLinejoin="round" d="M15 17h5l-1.4-1.4A2 2 0 0118 14.2V11a6 6 0 10-12 0v3.2c0 .5-.2 1-.6 1.4L4 17h5m6 0a3 3 0 11-6 0" />
                                    </svg>
                                </span>
                                Class &amp; deadline reminders
                            </li>
                        </ul>
                    </div>
                    <div className="android-promo__phone" aria-hidden="true">
                        <span className="android-promo__phone-notch" />
                        <span className="android-promo__phone-screen" />
                    </div>
                </div>
                <p className="android-promo__version mono">Version {version}</p>
                <a
                    href={apkUrl}
                    className="android-promo__download btn btn--primary"
                    download="classgrid.apk"
                >
                    <AndroidIcon />
                    Download for Android
                </a>
            </aside>
        );
    }

    return (
        <aside className="android-promo" aria-labelledby="android-promo-title">
            <div className="android-promo__body">
                <div className="android-promo__copy">
                    <div className="android-promo__eyebrow">Mobile</div>
                    <p id="android-promo-title" className="android-promo__title">
                        ClassGrid for Android
                    </p>
                    <ul className="android-promo__list">
                        <li>Smooth Android experience with your weekly/monthly schedule</li>
                        <li>Courses, Calendar, rooms, and reminders</li>
                    </ul>
                </div>
                <div className="android-promo__phone" aria-hidden="true">
                    <span className="android-promo__phone-notch" />
                    <span className="android-promo__phone-screen" />
                </div>
                <a
                    href={apkUrl}
                    className="android-promo__btn"
                    download="classgrid.apk"
                >
                    <span className="android-promo__btn-meta">
                        <strong>Android build</strong>
                        v{version} · sideload
                    </span>
                    <span className="android-promo__btn-action">
                        Get APK
                        <svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" />
                        </svg>
                    </span>
                </a>
            </div>
        </aside>
    );
}
