import React from 'react';

/* A nav item is a control: it takes the md control padding and height so the rail
   reads on the same rhythm as the buttons in it. */
export function NavItem({ label, count, active = false, onClick, style }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      type="button"
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      aria-current={active ? 'page' : undefined}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 'var(--gap-inline)',
        width: '100%',
        minHeight: 'var(--control-h-md)',
        padding: 'var(--control-pad-y-md) var(--control-pad-x-sm)',
        textAlign: 'left',
        border: 0,
        cursor: 'pointer',
        borderRadius: 'var(--radius-tile)',
        fontFamily: 'var(--font-display)',
        fontWeight: 'var(--weight-display)',
        fontSize: 'var(--text-sm)',
        lineHeight: 'var(--control-line)',
        whiteSpace: 'nowrap',
        background: active ? 'var(--accent-tint)' : hover ? 'var(--bg-muted)' : 'transparent',
        color: active ? 'var(--accent-text)' : 'var(--text-primary)',
        transition: 'background var(--dur-fast) var(--ease-out)',
        ...style
      }}
    >
      <span style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', minWidth: 0 }}>
        <span style={{ width: 6, height: 6, flex: 'none', borderRadius: 'var(--radius-pill)', background: active ? 'var(--accent)' : 'var(--border-strong)' }} />
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{label}</span>
      </span>
      {count != null ? (
        <span style={{
          flex: 'none',
          fontFamily: 'var(--font-body)',
          fontWeight: 'var(--weight-regular)',
          fontSize: 'var(--text-2xs)',
          lineHeight: 'var(--leading-snug)',
          borderRadius: 'var(--radius-pill)',
          padding: 'var(--pill-pad-y-sm) var(--pill-pad-x-sm)',
          background: active ? 'rgba(255,255,255,0.6)' : 'var(--bg-muted)',
          color: active ? 'var(--accent-text)' : 'var(--text-tertiary)'
        }}>{count}</span>
      ) : null}
    </button>
  );
}
