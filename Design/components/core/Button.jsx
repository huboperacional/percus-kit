import React from 'react';

const VARIANTS = {
  primary: { background: 'var(--accent)', color: 'var(--text-inverse)', borderColor: 'transparent', boxShadow: 'var(--shadow-accent)' },
  secondary: { background: 'var(--bg-surface)', color: 'var(--text-primary)', borderColor: 'var(--border-input)', boxShadow: 'var(--shadow-sm)' },
  ghost: { background: 'transparent', color: 'var(--text-primary)', borderColor: 'transparent', boxShadow: 'none' },
  danger: { background: 'var(--accent-press)', color: 'var(--text-inverse)', borderColor: 'transparent', boxShadow: 'none' }
};

const HOVER = { primary: 'var(--accent-hover)', secondary: 'var(--bg-muted)', ghost: 'var(--bg-muted)', danger: 'var(--accent-press)' };
const PRESS = { primary: 'var(--accent-press)', secondary: 'var(--border-card)', ghost: 'var(--border-card)', danger: 'var(--accent-press)' };

/* Size comes from padding + the shared line box — never from an explicit height,
   so a Button and a TextInput of the same size always match. */
const SIZES = {
  sm: { padding: 'var(--control-pad-y-sm) var(--control-pad-x-sm)', fontSize: 'var(--control-text-sm)', minHeight: 'var(--control-h-sm)' },
  md: { padding: 'var(--control-pad-y-md) var(--control-pad-x-md)', fontSize: 'var(--control-text-md)', minHeight: 'var(--control-h-md)' },
  lg: { padding: 'var(--control-pad-y-lg) var(--control-pad-x-lg)', fontSize: 'var(--control-text-lg)', minHeight: 'var(--control-h-lg)' }
};

export function Button({
  variant = 'secondary',
  size = 'md',
  align = 'center',
  block = false,
  disabled = false,
  icon = null,
  iconRight = null,
  children,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const v = VARIANTS[variant] || VARIANTS.secondary;
  const s = SIZES[size] || SIZES.md;

  return (
    <button
      type="button"
      disabled={disabled}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => { setHover(false); setPress(false); }}
      onMouseDown={() => setPress(true)}
      onMouseUp={() => setPress(false)}
      style={{
        display: block ? 'flex' : 'inline-flex',
        width: block ? '100%' : undefined,
        alignItems: 'center',
        justifyContent: align === 'left' ? 'flex-start' : 'center',
        gap: 'var(--control-gap)',
        padding: s.padding,
        minHeight: s.minHeight,
        fontFamily: 'var(--font-display)',
        fontWeight: 'var(--weight-display)',
        fontSize: s.fontSize,
        lineHeight: 'var(--control-line)',
        whiteSpace: 'nowrap',
        flex: 'none',
        borderRadius: 'var(--radius-pill)',
        borderStyle: 'solid',
        borderWidth: 'var(--control-border)',
        borderColor: v.borderColor,
        color: v.color,
        boxShadow: v.boxShadow,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.45 : 1,
        transition: 'background var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out), transform 100ms var(--ease-out)',
        transform: press && !disabled ? 'translateY(var(--press-shift))' : 'none',
        background: disabled ? v.background : press ? PRESS[variant] : hover ? HOVER[variant] : v.background,
        ...style
      }}
      {...rest}
    >
      {icon}
      {children}
      {iconRight}
    </button>
  );
}
