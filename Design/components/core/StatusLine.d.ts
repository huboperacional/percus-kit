import * as React from 'react';

/**
 * Inline per-row feedback. Always rendered — the idle copy holds the space so nothing
 * shifts when a save resolves. Success states should clear after ~3.2s.
 */
export interface StatusLineProps {
  state?: 'idle' | 'saved' | 'error';
  children?: React.ReactNode;
  style?: React.CSSProperties;
}

export declare function StatusLine(props: StatusLineProps): JSX.Element;
