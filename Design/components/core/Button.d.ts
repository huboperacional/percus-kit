import * as React from 'react';

/**
 * The system's only button. Pill-shaped at every size; primary is a solid accent fill
 * carrying an accent-tinted shadow. Height is never set directly — it comes from
 * `--control-pad-y-*` + `--control-line`, which is what keeps buttons and inputs aligned.
 * @startingPoint section="Core" subtitle="Pill buttons in four variants and three sizes" viewport="700x150"
 */
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  /** 'left' for full-width buttons whose label should sit at the padding edge. */
  align?: 'center' | 'left';
  block?: boolean;
  disabled?: boolean;
  icon?: React.ReactNode;
  iconRight?: React.ReactNode;
  children?: React.ReactNode;
}

export declare function Button(props: ButtonProps): JSX.Element;
