import React from 'react';

export function Sidebar({ brand, search, groupLabel = 'Sections', footer, children, style }) {
  return (
    <aside
      style={{
        position: 'sticky',
        top: 'var(--space-6)',
        width: 'var(--sidebar-width)',
        background: 'var(--bg-surface)',
        borderRadius: 'var(--radius-panel)',
        boxShadow: 'var(--shadow-sm)',
        padding: 'var(--pad-rail)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--space-5)',
        ...style
      }}
    >
      {brand}
      {search}
      <nav>
        {groupLabel ? <div className="pk-kicker" style={{ padding: '0 var(--control-pad-x-sm) var(--space-2)' }}>{groupLabel}</div> : null}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-px)' }}>{children}</div>
      </nav>
      {footer ? <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>{footer}</div> : null}
    </aside>
  );
}
