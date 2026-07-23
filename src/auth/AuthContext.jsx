import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';

const API_BASE = (process.env.REACT_APP_API_BASE || '').replace(/\/$/, '');

export function apiUrl(path) {
    return `${API_BASE}${path.startsWith('/') ? '' : '/'}${path}`;
}

export async function apiFetch(path, options = {}) {
    const headers = new Headers(options.headers || {});
    if (!headers.has('X-ClassGrid-Client')) {
        headers.set('X-ClassGrid-Client', 'web');
    }
    return fetch(apiUrl(path), {
        credentials: 'include',
        ...options,
        headers,
    });
}

const AuthContext = createContext({
    user: null,
    loading: true,
    refresh: async () => {},
    login: () => {},
    logout: async () => {},
});

export function AuthProvider({ children }) {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);

    const refresh = useCallback(async () => {
        try {
            const res = await apiFetch('/api/me');
            if (res.ok) {
                const data = await res.json();
                setUser(data);
            } else {
                setUser(null);
            }
        } catch (e) {
            setUser(null);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        refresh();
    }, [refresh]);

    const login = useCallback(() => {
        window.location.href = apiUrl('/auth/login');
    }, []);

    const logout = useCallback(async () => {
        try {
            await apiFetch('/auth/logout', { method: 'POST' });
        } catch (e) {
            // ignore
        }
        setUser(null);
    }, []);

    return (
        <AuthContext.Provider value={{ user, loading, refresh, login, logout }}>
            {children}
        </AuthContext.Provider>
    );
}

export function useAuth() {
    return useContext(AuthContext);
}
