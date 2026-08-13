import * as React from 'react';

/**
 * The first panel on any view: where am I, what is this, what can I do next.
 * @startingPoint section="Layout" subtitle="View header with badge, title, description and actions" viewport="700x220"
 */
export interface PageHeaderProps {
  kicker?: string;
  /** A <Pill> — position/step context, e.g. "Section 01 / 07". */
  badge?: React.ReactNode;
  title: string;
  description?: string;
  meta?: string;
  actions?: React.ReactNode;
  style?: React.CSSProperties;
}

export declare function PageHeader(props: PageHeaderProps): JSX.Element;
