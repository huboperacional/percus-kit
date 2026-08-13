import React from 'react';

export function FieldRow({ preview, previewWidth = 220, title, hint, control, action, status, style }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        display: 'grid',
        gridTemplateColumns: preview ? previewWidth + 'px minmax(0, 1fr)' : '1fr',
        gap: 'var(--space-5)',
        background: 'var(--bg-surface)',
        border: 'var(--control-border) solid var(--border-card)',
        borderRadius: 'var(--radius-card)',
        padding: 'var(--space-4)',
        boxShadow: hover ? 'var(--shadow-card-hover)' : 'none',
        transition: 'box-shadow var(--dur-base) var(--ease-out)',
        ...style
      }}
    >
      {preview ? <div style={{ borderRadius: 'var(--radius-tile)', overflow: 'hidden', background: 'var(--neutral-200)' }}>{preview}</div> : null}
      <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 'var(--weight-display)', fontSize: 'var(--text-md)', lineHeight: 'var(--leading-snug)' }}>{title}</div>
        {hint ? <div style={{ fontSize: 'var(--text-xs)', lineHeight: 'var(--leading-snug)', color: 'var(--text-tertiary)', marginTop: 'var(--space-1)' }}>{hint}</div> : null}
        {/* align-items: end lines the button's baseline box up with the input's,
            because both are padding-sized from the same tokens. */}
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 'var(--gap-inline)', marginTop: 'var(--space-3)' }}>
          <div style={{ flex: 1, minWidth: 0 }}>{control}</div>
          {action}
        </div>
        {status ? <div style={{ marginTop: 'var(--space-2)' }}>{status}</div> : null}
      </div>
    </div>
  );
}
