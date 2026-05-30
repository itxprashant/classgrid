import React, { useEffect, useRef, useState } from 'react';
import './Navbar.css';
import { NavLink, Link, useLocation } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext';

function initialsFromName(name) {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/).slice(0, 2);
    return parts.map((p) => p[0]).join('').toUpperCase();
}

const NAV_ITEMS = [
    { to: '/', end: true, label: 'Plan' },
    { to: '/course-explorer', label: 'Courses' },
    { to: '/rooms', label: 'Rooms' },
    { to: '/calendar', label: 'Calendar' },
];

export default function Navbar() {
    const { user, loading, login, logout } = useAuth();
    const location = useLocation();
    const [userMenuOpen, setUserMenuOpen] = useState(false);
    const [navOpen, setNavOpen] = useState(false);
    const userMenuRef = useRef(null);

    useEffect(() => {
        setNavOpen(false);
        setUserMenuOpen(false);
    }, [location.pathname]);

    useEffect(() => {
        if (!navOpen) return undefined;
        const prev = document.body.style.overflow;
        document.body.style.overflow = 'hidden';
        return () => {
            document.body.style.overflow = prev;
        };
    }, [navOpen]);

    useEffect(() => {
        if (!userMenuOpen) return undefined;
        const onClick = (e) => {
            if (userMenuRef.current && !userMenuRef.current.contains(e.target)) {
                setUserMenuOpen(false);
            }
        };
        document.addEventListener('mousedown', onClick);
        return () => document.removeEventListener('mousedown', onClick);
    }, [userMenuOpen]);

    const authBlock = loading ? null : user ? (
        <div className="nav__user" ref={userMenuRef}>
            <button
                type="button"
                className="nav__user-btn"
                onClick={() => setUserMenuOpen((v) => !v)}
                aria-expanded={userMenuOpen}
                aria-haspopup="menu"
            >
                <span className="nav__user-avatar" aria-hidden="true">
                    {initialsFromName(user.name || user.kerberos)}
                </span>
                <span className="nav__user-name">
                    {user.kerberos ? (
                        <span className="nav__user-kerberos mono">{user.kerberos}</span>
                    ) : (
                        user.name
                    )}
                </span>
            </button>
            {userMenuOpen && (
                <div className="nav__user-menu" role="menu">
                    <div className="nav__user-menu-head">
                        <div className="nav__user-menu-name">{user.name}</div>
                        {user.email && (
                            <div className="nav__user-menu-sub mono">{user.email}</div>
                        )}
                    </div>
                    <button
                        type="button"
                        className="nav__user-menu-item"
                        onClick={() => {
                            setUserMenuOpen(false);
                            logout();
                        }}
                        role="menuitem"
                    >
                        Log out
                    </button>
                </div>
            )}
        </div>
    ) : (
        <button
            type="button"
            className="btn btn--sm btn--primary nav__login-btn"
            onClick={login}
        >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                <path d="M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4" />
                <polyline points="10 17 15 12 10 7" />
                <line x1="15" y1="12" x2="3" y2="12" />
            </svg>
            <span className="nav__login-label">Login with IITD</span>
        </button>
    );

    return (
        <nav className="nav">
            <div className="nav__inner">
                <Link to="/" className="nav__brand" aria-label="IIT Delhi Timetable, home">
                    <span className="nav__mark" aria-hidden="true" />
                    <span className="nav__wordmark">
                        <span className="nav__wordmark-serif">ClassGrid</span>
                        <span className="nav__wordmark-mono">/iitd</span>
                    </span>
                </Link>

                <button
                    type="button"
                    className="nav__menu-btn"
                    aria-expanded={navOpen}
                    aria-controls="nav-panel"
                    aria-label={navOpen ? 'Close menu' : 'Open menu'}
                    onClick={() => setNavOpen((v) => !v)}
                >
                    <span className="nav__menu-icon" aria-hidden="true" />
                </button>

                <div
                    id="nav-panel"
                    className={'nav__panel' + (navOpen ? ' is-open' : '')}
                >
                    <div className="nav__links">
                        {NAV_ITEMS.map(({ to, end, label }) => (
                            <NavLink
                                key={to}
                                to={to}
                                end={end}
                                className={({ isActive }) =>
                                    'nav__link' + (isActive ? ' is-active' : '')
                                }
                                onClick={() => setNavOpen(false)}
                            >
                                {label}
                            </NavLink>
                        ))}
                    </div>

                    <div className="nav__auth">{authBlock}</div>
                </div>
            </div>

            {navOpen && (
                <button
                    type="button"
                    className="nav__backdrop"
                    aria-label="Close menu"
                    onClick={() => setNavOpen(false)}
                />
            )}
        </nav>
    );
}
