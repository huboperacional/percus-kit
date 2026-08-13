import * as React from 'react';

/**
 * Single-line text input. Sized by the shared control tokens, so a TextInput and a
 * Button with the same `size` are always the same height. `pill` is the inset
 * search treatment used in the sidebar.
 */
export interface TextInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  /** Must match the size of any Button sitting on the same row. */
  size?: 'sm' | 'md' | 'lg';
  invalid?: boolean;
  leadingIcon?: React.ReactNode;
  pill?: boolean;
}

export declare function TextInput(props: TextInputProps): JSX.Element;
