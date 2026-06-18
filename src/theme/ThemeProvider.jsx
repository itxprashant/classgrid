import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import {
    applyTheme,
    persistTheme,
    readStoredTheme,
    systemPrefersDark,
    THEMES,
    watchSystemTheme,
} from './theme';

const ThemeContext = createContext(null);

export function ThemeProvider({ children }) {
    const [storedTheme, setStoredTheme] = useState(() => readStoredTheme());
    const [systemTheme, setSystemTheme] = useState(() => (
        systemPrefersDark() ? THEMES.dark : THEMES.light
    ));
    const resolvedTheme = storedTheme ?? systemTheme;

    useEffect(() => {
        applyTheme(resolvedTheme);
    }, [resolvedTheme]);

    useEffect(() => watchSystemTheme(() => {
        if (readStoredTheme()) return;
        setSystemTheme(systemPrefersDark() ? THEMES.dark : THEMES.light);
    }), []);

    const setTheme = useCallback((theme) => {
        if (theme !== THEMES.light && theme !== THEMES.dark) return;
        persistTheme(theme);
        setStoredTheme(theme);
    }, []);

    const toggleTheme = useCallback(() => {
        setTheme(resolvedTheme === THEMES.dark ? THEMES.light : THEMES.dark);
    }, [resolvedTheme, setTheme]);

    const value = useMemo(
        () => ({
            theme: storedTheme,
            resolvedTheme,
            setTheme,
            toggleTheme,
            isDark: resolvedTheme === THEMES.dark,
        }),
        [storedTheme, resolvedTheme, setTheme, toggleTheme],
    );

    return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
    const ctx = useContext(ThemeContext);
    if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
    return ctx;
}
