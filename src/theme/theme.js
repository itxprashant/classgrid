export const STORAGE_KEY = 'cg_color_scheme';

export const THEMES = {
    light: 'light',
    dark: 'dark',
};

const THEME_COLORS = {
    light: '#faf8f5', // matches :root --paper
    dark: '#1e1d28', // matches [data-theme="dark"] --paper
};

export function readStoredTheme() {
    try {
        const value = localStorage.getItem(STORAGE_KEY);
        if (value === THEMES.light || value === THEMES.dark) return value;
    } catch {
        /* private browsing / blocked storage */
    }
    return null;
}

export function systemPrefersDark() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
}

export function resolveTheme(storedTheme) {
    if (storedTheme === THEMES.light || storedTheme === THEMES.dark) return storedTheme;
    return systemPrefersDark() ? THEMES.dark : THEMES.light;
}

export function applyTheme(resolvedTheme) {
    const theme = resolvedTheme === THEMES.dark ? THEMES.dark : THEMES.light;
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = theme;

    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) {
        const paper = getComputedStyle(document.documentElement).getPropertyValue('--paper').trim();
        meta.setAttribute('content', paper || THEME_COLORS[theme]);
    }
}

export function persistTheme(theme) {
    try {
        if (theme === THEMES.light || theme === THEMES.dark) {
            localStorage.setItem(STORAGE_KEY, theme);
        } else {
            localStorage.removeItem(STORAGE_KEY);
        }
    } catch {
        /* ignore */
    }
}

export function watchSystemTheme(onChange) {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = () => {
        if (readStoredTheme()) return;
        onChange(resolveTheme(null));
    };
    if (media.addEventListener) {
        media.addEventListener('change', handler);
        return () => media.removeEventListener('change', handler);
    }
    media.addListener(handler);
    return () => media.removeListener(handler);
}
