import React from 'react';
import './PlanToggle.css';

export default function PlanToggle({ onPlan, onAdd, onRemove }) {
    const label = onPlan ? 'On plan' : 'Add';
    const handleClick = onPlan ? onRemove : onAdd;

    return (
        <button
            type="button"
            className={`plan-toggle${onPlan ? ' plan-toggle--on' : ''}`}
            onClick={handleClick}
            aria-pressed={onPlan}
        >
            {onPlan ? (
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                    <polyline points="20 6 9 17 4 12" />
                </svg>
            ) : (
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                    <line x1="12" y1="5" x2="12" y2="19" />
                    <line x1="5" y1="12" x2="19" y2="12" />
                </svg>
            )}
            <span>{label}</span>
        </button>
    );
}
