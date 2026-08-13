import * as React from 'react';

/** Modal at the top elevation. Reserve it for destructive confirmation and true interruptions. */
export interface DialogProps {
  open?: boolean;
  title?: string;
  description?: string;
  actions?: React.ReactNode;
  onDismiss?: () => void;
  children?: React.ReactNode;
}

export declare function Dialog(props: DialogProps): JSX.Element;
