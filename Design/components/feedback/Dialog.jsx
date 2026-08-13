import React from 'react';

export function Dialog({ open = true, title, description, actions, onDismiss, children }) {
  if (!open) return null;
  return (
    <div
      onClick={onDismiss}
      style={{ position: 'fixed', inset: 0, background: 'var(--overlay-scrim)', display: 'grid', placeItems: 'center', padding: 'var(--space-6)', zIndex: 50 }}
    >
      <div
        role="dialog"
        aria-modal="true"
        onClick={e => e.stopPropagation()}
        style={{
          width: 'min(460px, 100%)',
          background: 'var(--bg-surface)',
          borderRadius: 'var(--radius-modal)',
          boxShadow: 'var(--shadow-modal)',
          padding: 'var(--pad-modal)',
          display: 'flex',
          flexDirection: 'column',
          gap: 'var(--space-3)'
        }}
      >
        {title ? <h3 style={{ fontSize: 'var(--text-xl)' }}>{title}</h3> : null}
        {description ? <p style={{ margin: 0, fontSize: 'var(--text-sm)', color: 'var(--text-tertiary)' }}>{description}</p> : null}
        {children}
        {actions ? <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--gap-inline)', marginTop: 'var(--space-1)' }}>{actions}</div> : null}
      </div>
    </div>
  );
}
