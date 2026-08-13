import React from 'react';

const CHECK = <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.4" strokeLinecap="round"><path d="M20 6 9 17l-5-5" /></svg>;
const ALERT = <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><circle cx="12" cy="12" r="9" /><path d="M12 8v5" /><path d="M12 16h.01" /></svg>;

export function StatusLine({ state = 'idle', children, style }) {
  const ok = state === 'saved';
  const bad = state === 'error';
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 'var(--gap-inline)',
        minHeight: 'var(--control-line)',
        fontSize: 'var(--text-xs)',
        lineHeight: 'var(--control-line)',
        color: ok || bad ? 'var(--accent-text)' : 'var(--text-tertiary)',
        ...style
      }}
    >
      {ok ? (
        <span style={{ width: 18, height: 18, flex: 'none', borderRadius: 'var(--radius-pill)', background: 'var(--accent-tint)', display: 'grid', placeItems: 'center' }}>{CHECK}</span>
      ) : null}
      {bad ? <span style={{ flex: 'none', display: 'flex' }}>{ALERT}</span> : null}
      <span>{children}</span>
    </div>
  );
}
