import React from 'react';

const TONES = {
  neutral: { background: 'var(--bg-muted)', color: 'var(--text-secondary)' },
  accent: { background: 'var(--accent-tint)', color: 'var(--accent-text)' },
  solid: { background: 'var(--accent)', color: 'var(--text-inverse)' },
  overlay: { background: 'var(--overlay-badge)', color: 'var(--text-inverse)' },
  onAccent: { background: 'var(--overlay-on-accent)', color: 'var(--text-inverse)' },
  success: { background: 'var(--success-tint)', color: 'var(--success)' }
};

export function Pill({ tone = 'neutral', size = 'md', uppercase = false, style, children, ...rest }) {
  const tight = size === 'sm';
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 'var(--space-1)',
        padding: tight ? 'var(--pill-pad-y-sm) var(--pill-pad-x-sm)' : 'var(--pill-pad-y) var(--pill-pad-x)',
        borderRadius: 'var(--radius-pill)',
        fontSize: 'var(--text-2xs)',
        lineHeight: 'var(--leading-snug)',
        letterSpacing: uppercase ? 'var(--tracking-pill)' : 'var(--tracking-normal)',
        textTransform: uppercase ? 'uppercase' : 'none',
        whiteSpace: 'nowrap',
        ...(TONES[tone] || TONES.neutral),
        ...style
      }}
      {...rest}
    >
      {children}
    </span>
  );
}
