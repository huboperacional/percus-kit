import * as React from 'react';

/**
 * Square-footprint, pill-radius icon-only button. Takes the same size scale as Button
 * (`--control-h-*`) so it aligns in any action row. `label` becomes the accessible name.
 */
export interface IconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  label: string;
  size?: 'sm' | 'md' | 'lg';
  variant?: 'secondary' | 'ghost';
  children?: React.ReactNode;
}

export declare function IconButton(props: IconButtonProps): JSX.Element;
