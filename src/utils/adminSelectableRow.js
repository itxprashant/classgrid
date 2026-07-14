/**
 * Keyboard-accessible props for admin table rows that toggle a detail panel.
 */
export function adminSelectableRowProps(isSelected, onToggle) {
    return {
        tabIndex: 0,
        role: 'button',
        'aria-pressed': isSelected,
        onClick: onToggle,
        onKeyDown: (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                onToggle();
            }
        },
    };
}
