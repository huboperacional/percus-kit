import React from 'react';

/* Owns the vertical rhythm around a control so no caller adds a stray margin. */
export function Field({ label, hint, htmlFor, children, style }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--gap-label)', minWidth: 0, ...style }}>
      {label ? (
        <label htmlFor={htmlFor} style={{ fontSize: 'var(--text-xs)', lineHeight: 'var(--leading-snug)', color: 'var(--text-secondary)' }}>
          {label}
        </label>
      ) : null}
      {children}
      {hint ? <span style={{ fontSize: 'var(--text-xs)', lineHeight: 'var(--leading-snug)', color: 'var(--text-tertiary)' }}>{hint}</span> : null}
    </div>
  );
}
