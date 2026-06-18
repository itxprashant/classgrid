import React, { useEffect, useRef, useState } from 'react';
import './Navbar.css';
import { NavLink, Link, useLocation } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext';
import ThemeToggle from '../ThemeToggle/ThemeToggle';

function initialsFromName(name) {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/).slice(0, 2);
    return parts.map((p) => p[0]).join('').toUpperCase();
}

const NAV_ITEMS = [
    { to: '/calendar', end: true, label: 'Calendar' },
    { to: '/plan', label: 'Plan' },
    { to: '/rooms', label: 'Rooms' },
];

const EXPLORE_ITEMS = [
    { to: '/course-explorer', label: 'Courses' },
    { to: '/professors', label: 'Professors' },
    { to: '/students', label: 'Students' },
];

function isExplorePath(pathname) {
    return (
        pathname.startsWith('/course-explorer')
        || pathname.startsWith('/professors')
        || pathname.startsWith('/professor/')
        || pathname.startsWith('/students')
        || pathname.startsWith('/student/')
    );
}

export default function Navbar() {
    const { user, loading, login, logout } = useAuth();
    const location = useLocation();
    const [userMenuOpen, setUserMenuOpen] = useState(false);
    const [exploreMenuOpen, setExploreMenuOpen] = useState(false);
    const [navOpen, setNavOpen] = useState(false);
    const userMenuRef = useRef(null);
    const exploreMenuRef = useRef(null);

    const exploreActive = isExplorePath(location.pathname);

    useEffect(() => {
        setNavOpen(false);
        setUserMenuOpen(false);
        setExploreMenuOpen(false);
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

    useEffect(() => {
        if (!exploreMenuOpen) return undefined;
        const onClick = (e) => {
            if (exploreMenuRef.current && !exploreMenuRef.current.contains(e.target)) {
                setExploreMenuOpen(false);
            }
        };
        document.addEventListener('mousedown', onClick);
        return () => document.removeEventListener('mousedown', onClick);
    }, [exploreMenuOpen]);

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
                        {user.hostel && (
                            <div className="nav__user-menu-sub">{user.hostel}</div>
                        )}
                    </div>
                    <Link
                        to="/feedback"
                        className="nav__user-menu-item nav__user-menu-link"
                        role="menuitem"
                        onClick={() => setUserMenuOpen(false)}
                    >
                        Suggest a feature
                    </Link>
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
                <Link to="/calendar" className="nav__brand" aria-label="ClassGrid, home">
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
                        {NAV_ITEMS.slice(0, 2).map(({ to, end, label }) => (
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

                        <div className="nav__explore" ref={exploreMenuRef}>
                            <button
                                type="button"
                                className={'nav__link nav__explore-btn' + (exploreActive ? ' is-active' : '')}
                                onClick={() => setExploreMenuOpen((v) => !v)}
                                aria-expanded={exploreMenuOpen}
                                aria-haspopup="menu"
                            >
                                Explore
                                <span className="nav__explore-chevron" aria-hidden="true">▾</span>
                            </button>
                            {exploreMenuOpen && (
                                <div className="nav__explore-menu" role="menu">
                                    {EXPLORE_ITEMS.map(({ to, label }) => (
                                        <Link
                                            key={to}
                                            to={to}
                                            className="nav__explore-menu-item"
                                            role="menuitem"
                                            onClick={() => {
                                                setExploreMenuOpen(false);
                                                setNavOpen(false);
                                            }}
                                        >
                                            {label}
                                        </Link>
                                    ))}
                                </div>
                            )}
                        </div>

                        <div className="nav__explore-mobile">
                            <div className="nav__explore-mobile-label mono muted">Explore</div>
                            {EXPLORE_ITEMS.map(({ to, label }) => (
                                <NavLink
                                    key={to}
                                    to={to}
                                    className={({ isActive }) =>
                                        'nav__link nav__explore-mobile-link' + (isActive ? ' is-active' : '')
                                    }
                                    onClick={() => setNavOpen(false)}
                                >
                                    {label}
                                </NavLink>
                            ))}
                        </div>

                        {NAV_ITEMS.slice(2).map(({ to, end, label }) => (
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

                    <div className="nav__auth">
                        <ThemeToggle />
                        {authBlock}
                    </div>
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
