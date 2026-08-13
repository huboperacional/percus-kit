import * as React from 'react';

/**
 * Sticky navigation panel: brand, search, one flat list of destinations, footer slot.
 * One level only — this system has no nested navigation trees.
 * @startingPoint section="Navigation" subtitle="Sticky sidebar with search and counted destinations" viewport="700x400"
 */
export interface SidebarProps {
  brand?: React.ReactNode;
  search?: React.ReactNode;
  groupLabel?: string;
  footer?: React.ReactNode;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}

export declare function Sidebar(props: SidebarProps): JSX.Element;
