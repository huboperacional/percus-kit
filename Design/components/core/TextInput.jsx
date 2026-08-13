import React from 'react';

const SIZES = {
  sm: { padY: 'var(--control-pad-y-sm)', padX: 'var(--control-pad-x-sm)', font: 'var(--control-text-sm)', min: 'var(--control-h-sm)' },
  md: { padY: 'var(--control-pad-y-md)', padX: 'var(--control-pad-x-md)', font: 'var(--control-text-md)', min: 'var(--control-h-md)' },
  lg: { padY: 'var(--control-pad-y-lg)', padX: 'var(--control-pad-x-lg)', font: 'var(--control-text-lg)', min: 'var(--control-h-lg)' }
};

/* Same padding tokens as Button — that is the only reason the two line up. */
export function TextInput({ size = 'md', invalid = false, leadingIcon = null, pill = false, style, ...rest }) {
  const [focus, setFocus] = React.useState(false);
  const s = SIZES[size] || SIZES.md;
  const border = invalid || focus ? 'var(--accent)' : 'var(--border-input)';
  return (
    <div style={{ position: 'relative', width: '100%', display: 'flex' }}>
      {leadingIcon ? (
        <span style={{ position: 'absolute', left: 'var(--control-pad-x-sm)', top: 0, bottom: 0, display: 'flex', alignItems: 'center', opacity: 0.45, pointerEvents: 'none' }}>
          {leadingIcon}
        </span>
      ) : null}
      <input
        onFocus={() => setFocus(true)}
        onBlur={() => setFocus(false)}
        style={{
          width: '100%',
          minHeight: s.min,
          paddingTop: s.padY,
          paddingBottom: s.padY,
          paddingRight: s.padX,
          paddingLeft: leadingIcon ? 'var(--control-pad-x-inset)' : s.padX,
          font: 'inherit',
          fontSize: s.font,
          lineHeight: 'var(--control-line)',
          color: 'var(--text-primary)',
          caretColor: 'var(--accent)',
          background: pill ? 'var(--bg-inset)' : 'var(--bg-surface)',
          borderStyle: 'solid',
          borderWidth: 'var(--control-border)',
          borderColor: border,
          borderRadius: pill ? 'var(--radius-pill)' : 'var(--radius-input)',
          boxShadow: pill ? 'none' : 'var(--shadow-inset-input)',
          outline: 'none',
          transition: 'border-color var(--dur-fast) var(--ease-out)',
          ...style
        }}
        {...rest}
      />
    </div>
  );
}
