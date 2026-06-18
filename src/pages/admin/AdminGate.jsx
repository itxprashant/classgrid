import React, { useEffect, useState } from 'react';
import { Link, Outlet } from 'react-router-dom';
import { useAuth } from '../../auth/AuthContext';
import { adminErrorMessage, fetchAdminMe } from '../../utils/adminApi';
import './admin.css';

export default function AdminGate() {
    const { user, loading, login } = useAuth();
    const [checking, setChecking] = useState(true);
    const [allowed, setAllowed] = useState(false);
    const [error, setError] = useState(null);

    useEffect(() => {
        let cancelled = false;

        async function check() {
            if (loading) return;
            if (!user) {
                if (!cancelled) {
                    setChecking(false);
                    setAllowed(false);
                    setError(null);
                }
                return;
            }

            setChecking(true);
            try {
                await fetchAdminMe();
                if (!cancelled) {
                    setAllowed(true);
                    setError(null);
                }
            } catch (e) {
                if (!cancelled) {
                    setAllowed(false);
                    setError(adminErrorMessage(e.code || e.message));
                }
            } finally {
                if (!cancelled) setChecking(false);
            }
        }

        check();
        return () => { cancelled = true; };
    }, [user, loading]);

    if (loading || checking) {
        return (
            <div className="admin admin__gate">
                <p className="admin__loading">Checking access…</p>
            </div>
        );
    }

    if (!user) {
        return (
            <div className="admin admin__gate">
                <div className="panel admin__gate-panel">
                    <div className="admin__eyebrow">ClassGrid</div>
                    <h1 className="admin__gate-title">Admin</h1>
                    <p className="admin__gate-lead">
                        Sign in with your IITD account to open the admin panel.
                    </p>
                    <button type="button" className="btn btn--primary" onClick={login}>
                        Sign in
                    </button>
                    <p className="admin__gate-footer">
                        <Link to="/calendar" className="admin__back">Back to calendar</Link>
                    </p>
                </div>
            </div>
        );
    }

    if (!allowed) {
        return (
            <div className="admin admin__gate">
                <div className="panel admin__gate-panel">
                    <div className="admin__eyebrow">ClassGrid</div>
                    <h1 className="admin__gate-title">No access</h1>
                    <p className="admin__gate-lead">
                        {error || adminErrorMessage('not_admin')}
                    </p>
                    <p className="admin__gate-footer">
                        <Link to="/calendar" className="admin__back">Back to calendar</Link>
                    </p>
                </div>
            </div>
        );
    }

    return <Outlet />;
}
