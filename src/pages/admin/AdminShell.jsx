import React from 'react';
import { Link, NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext';
import './admin.css';

function tabClass({ isActive }) {
    return isActive ? 'admin__tab admin__tab--active' : 'admin__tab';
}

export default function AdminShell() {
    const { user } = useAuth();

    return (
        <div className="admin">
            <header className="admin__head">
                <div className="admin__head-row">
                    <div className="admin__head-text">
                        <div className="admin__eyebrow">ClassGrid</div>
                        <h1 className="admin__title">Admin</h1>
                    </div>
                    <div className="admin__meta">
                        {user?.kerberos && (
                            <span className="admin__signed-in mono">{user.kerberos}</span>
                        )}
                        <Link to="/calendar" className="admin__back">← Back to site</Link>
                    </div>
                </div>
            </header>

            <nav className="admin__tabs" aria-label="Admin sections">
                <NavLink to="/admin" end className={tabClass}>Overview</NavLink>
                <NavLink to="/admin/feedback" className={tabClass}>Feedback</NavLink>
                <NavLink to="/admin/reports" className={tabClass}>Reports</NavLink>
                <NavLink to="/admin/push" className={tabClass}>Push</NavLink>
                <NavLink to="/admin/logs" className={tabClass}>Logs</NavLink>
            </nav>

            <div className="admin__body">
                <Outlet />
            </div>
        </div>
    );
}
