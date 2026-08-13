import * as React from 'react';

/** One sidebar destination: dot + label + count pill. Active state is an accent tint, never a filled bar. */
export interface NavItemProps {
  label: string;
  count?: number | string;
  active?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}

export declare function NavItem(props: NavItemProps): JSX.Element;
