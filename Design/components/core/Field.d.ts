import * as React from 'react';

/** Label + control + hint stack. The label is 12px secondary ink, never uppercase. */
export interface FieldProps {
  label?: string;
  hint?: string;
  htmlFor?: string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}

export declare function Field(props: FieldProps): JSX.Element;
