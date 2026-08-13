import React from 'react';

export function Panel({ title, meta, note, actions, padded = true, children, style }) {
  const hasHeader = title || meta || note || actions;
  return (
    <section
      style={{
        background: 'var(--bg-surface)',
        borderRadius: 'var(--radius-panel)',
        boxShadow: 'var(--shadow-sm)',
        padding: padded ? 'var(--pad-panel)' : 0,
        ...style
      }}
    >
      {hasHeader ? (
        <header style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', marginBottom: 'var(--space-4)' }}>
          {title ? <h4 style={{ fontSize: 'var(--text-lg)' }}>{title}</h4> : null}
          {meta ? <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-tertiary)' }}>{meta}</span> : null}
          {note}
          {actions ? <div style={{ marginLeft: 'auto', display: 'flex', gap: 'var(--gap-inline)' }}>{actions}</div> : null}
        </header>
      ) : null}
      {children}
    </section>
  );
}
