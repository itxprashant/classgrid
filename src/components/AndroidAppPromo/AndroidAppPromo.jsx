import React, { useEffect, useState } from 'react';
import { apiFetch } from '../../auth/AuthContext';
import './AndroidAppPromo.css';

const DEFAULT_APK_URL = 'https://classgrid.devclub.in/app/classgrid.apk';
const DEFAULT_VERSION = '1.0.0';

export default function AndroidAppPromo() {
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
