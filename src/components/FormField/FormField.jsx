import React from 'react';

/**
 * Label + control layout for ui.css form primitives.
 *
 * Put `.field` (or `.field.field--mono`, etc.) on the input/select/textarea —
 * never on this wrapper. Do not use BEM `field__label` / `field__input`.
 *
 * @see src/styles/ui.css — `.field`, `.field-label`, `.form-field`
 * @see AGENTS.md — "Form fields (web)"
 */
export default function FormField({
    label,
    htmlFor,
    children,
    className = '',
    wide = false,
    as = 'div',
}) {
    const rootClass = [
        'form-field',
        wide ? 'form-field--wide' : '',
        className,
    ].filter(Boolean).join(' ');

    if (as === 'fieldset') {
        return (
            <fieldset className={rootClass}>
                <legend className="field-label">{label}</legend>
                {children}
            </fieldset>
        );
    }

    return (
        <div className={rootClass}>
            <label className="field-label" htmlFor={htmlFor}>{label}</label>
            {children}
        </div>
    );
}
