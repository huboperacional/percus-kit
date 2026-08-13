import React from 'react';

export function PageHeader({ kicker, badge, title, description, meta, actions, style }) {
  return (
    <div
      style={{
        background: 'var(--bg-surface)',
        borderRadius: 'var(--radius-panel)',
        boxShadow: 'var(--shadow-sm)',
        padding: 'var(--pad-header)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 'var(--space-6)',
        flexWrap: 'wrap',
        ...style
      }}
    >
      <div style={{ minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--gap-inline)' }}>
          {badge}
          {kicker ? <span className="pk-kicker">{kicker}</span> : null}
          {meta ? <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-tertiary)' }}>{meta}</span> : null}
        </div>
        <h2 style={{ margin: 'var(--space-3) 0 var(--space-1)' }}>{title}</h2>
        {description ? (
          <p style={{ margin: 0, fontSize: 'var(--text-sm)', color: 'var(--text-tertiary)', maxWidth: '66ch' }}>{description}</p>
        ) : null}
      </div>
      {actions ? <div style={{ display: 'flex', gap: 'var(--gap-inline)', flex: 'none' }}>{actions}</div> : null}
    </div>
  );
}
