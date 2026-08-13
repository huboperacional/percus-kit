import * as React from 'react';

/** Small pill label. `overlay` sits on top of imagery; `onAccent` on a red field. */
export interface PillProps extends React.HTMLAttributes<HTMLSpanElement> {
  tone?: 'neutral' | 'accent' | 'solid' | 'overlay' | 'onAccent' | 'success';
  /** 'sm' is the tighter padding used for counts inside nav items. */
  size?: 'sm' | 'md';
  uppercase?: boolean;
  children?: React.ReactNode;
}

export declare function Pill(props: PillProps): JSX.Element;
