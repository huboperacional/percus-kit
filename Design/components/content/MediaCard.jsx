import React from 'react';

export function MediaCard({ src, alt = '', ratio = '3 / 2', badge, overlay, title, hint, actions, status, onActivate, style }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onClick={onActivate}
      style={{
        display: 'flex',
        flexDirection: 'column',
        background: 'var(--bg-surface)',
        border: 'var(--control-border) solid var(--border-card)',
        borderRadius: 'var(--radius-card)',
        overflow: 'hidden',
        cursor: onActivate ? 'pointer' : 'default',
        boxShadow: hover ? 'var(--shadow-card-hover)' : 'none',
        transform: hover ? 'translateY(var(--lift-card))' : 'none',
        transition: 'box-shadow var(--dur-base) var(--ease-out), transform var(--dur-base) var(--ease-out)',
        ...style
      }}
    >
      <div style={{ position: 'relative', aspectRatio: ratio, background: 'var(--neutral-200)', overflow: 'hidden' }}>
        {src ? (
          <img src={src} alt={alt} style={{ width: '100%', height: '100%', objectFit: 'cover', transform: hover ? 'scale(var(--zoom-media))' : 'none', transition: 'transform var(--dur-slow) var(--ease-out)' }} />
        ) : null}
        {badge ? <div style={{ position: 'absolute', left: 'var(--media-badge-inset)', top: 'var(--media-badge-inset)' }}>{badge}</div> : null}
        {overlay ? <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center' }}>{overlay}</div> : null}
      </div>
      <div style={{ padding: 'var(--pad-card)', display: 'flex', flexDirection: 'column', gap: 'var(--space-1)', flex: 1 }}>
        {title ? <div style={{ fontFamily: 'var(--font-display)', fontWeight: 'var(--weight-display)', fontSize: 'var(--text-base)', lineHeight: 'var(--leading-snug)' }}>{title}</div> : null}
        {hint ? <div style={{ fontSize: 'var(--text-2xs)', lineHeight: 'var(--leading-snug)', color: 'var(--text-tertiary)', flex: 1 }}>{hint}</div> : null}
        {actions || status ? (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 'var(--gap-inline)', marginTop: 'var(--space-3)' }}>
            {actions}
            {status}
          </div>
        ) : null}
      </div>
    </div>
  );
}
