import * as React from 'react';

/**
 * The white rounded surface everything lives in. Panels stack with --space-6 between them
 * on the app ground; they never nest inside each other.
 * @startingPoint section="Layout" subtitle="The white panel surface with its header row" viewport="700x260"
 */
export interface PanelProps {
  title?: string;
  /** Small count or context line beside the title. */
  meta?: string;
  /** A <Pill> or similar, right after the meta. */
  note?: React.ReactNode;
  actions?: React.ReactNode;
  padded?: boolean;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}

export declare function Panel(props: PanelProps): JSX.Element;
