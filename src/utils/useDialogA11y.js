import { useEffect, useRef } from 'react';

const FOCUSABLE_SELECTOR = [
    'a[href]',
    'button:not([disabled])',
    'textarea:not([disabled])',
    'input:not([disabled])',
    'select:not([disabled])',
    '[tabindex]:not([tabindex="-1"])',
].join(', ');

function focusableElements(root) {
    if (!root) return [];
    return Array.from(root.querySelectorAll(FOCUSABLE_SELECTOR)).filter(
        (el) => !el.closest('[inert]'),
    );
}

/**
 * Escape to close, focus trap, scroll lock, and focus restore for modal dialogs.
 */
export function useDialogA11y(dialogRef, { onClose, active = true, initialFocusRef = null } = {}) {
    const previousFocusRef = useRef(null);
    const onCloseRef = useRef(onClose);
    onCloseRef.current = onClose;

    useEffect(() => {
        if (!active || !onCloseRef.current) return undefined;

        previousFocusRef.current = document.activeElement;
        const previousOverflow = document.body.style.overflow;
        document.body.style.overflow = 'hidden';

        const dialog = dialogRef.current;
        const focusTarget = initialFocusRef?.current
            || (dialog ? focusableElements(dialog)[0] : null);
        if (focusTarget) {
            window.setTimeout(() => focusTarget.focus(), 0);
        }

        const onKeyDown = (e) => {
            if (e.key === 'Escape') {
                e.preventDefault();
                onCloseRef.current?.();
                return;
            }
            if (e.key !== 'Tab' || !dialog) return;

            const focusables = focusableElements(dialog);
            if (focusables.length === 0) return;

            const first = focusables[0];
            const last = focusables[focusables.length - 1];

            if (e.shiftKey && document.activeElement === first) {
                e.preventDefault();
                last.focus();
            } else if (!e.shiftKey && document.activeElement === last) {
                e.preventDefault();
                first.focus();
            }
        };

        document.addEventListener('keydown', onKeyDown);
        return () => {
            document.removeEventListener('keydown', onKeyDown);
            document.body.style.overflow = previousOverflow;
            const prev = previousFocusRef.current;
            if (prev && typeof prev.focus === 'function' && document.contains(prev)) {
                prev.focus();
            }
        };
    }, [active, dialogRef, initialFocusRef]);
}
