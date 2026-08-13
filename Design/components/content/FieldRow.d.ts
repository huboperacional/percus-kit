import * as React from 'react';

/**
 * A wide editable row: preview on the left, label + control + commit button on the right,
 * inline status underneath. The counterpart to MediaCard for fields that need typing.
 * @startingPoint section="Content" subtitle="Preview + labelled control + save, with inline status" viewport="700x220"
 */
export interface FieldRowProps {
  preview?: React.ReactNode;
  previewWidth?: number;
  title: string;
  hint?: string;
  control?: React.ReactNode;
  action?: React.ReactNode;
  status?: React.ReactNode;
  style?: React.CSSProperties;
}

export declare function FieldRow(props: FieldRowProps): JSX.Element;
