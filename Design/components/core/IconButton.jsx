import React from 'react';

const SQUARE = { sm: 'var(--control-h-sm)', md: 'var(--control-h-md)', lg: 'var(--control-h-lg)' };

/* Square footprint: the same height token as every other control of that size,
   with the horizontal padding dropped so the glyph centres. */
export function IconButton({ label, size = 'md', variant = 'secondary', style, children, ...rest }) {
  const [hover, setHover] = React.useState(false);
  const secondary = variant === 'secondary';
  const box = SQUARE[size] || SQUARE.md;
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: box,
        height: box,
        flex: 'none',
        padding: 'var(--control-pad-icon-only)',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: 'var(--radius-pill)',
        borderStyle: 'solid',
        borderWidth: 'var(--control-border)',
        borderColor: secondary ? 'var(--border-input)' : 'transparent',
        boxShadow: secondary ? 'var(--shadow-sm)' : 'none',
        color: 'var(--text-primary)',
        cursor: 'pointer',
        background: hover ? 'var(--bg-muted)' : secondary ? 'var(--bg-surface)' : 'transparent',
        transition: 'background var(--dur-fast) var(--ease-out)',
        ...style
      }}
      {...rest}
    >
      {children}
    </button>
  );
}
