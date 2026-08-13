import * as React from 'react';

/**
 * Image-first card: the picture is the label. Use in a
 * `repeat(auto-fill, minmax(var(--card-min), 1fr))` grid with --space-4 gap.
 * @startingPoint section="Content" subtitle="Image-first card with badge, title and inline action" viewport="700x300"
 */
export interface MediaCardProps {
  src?: string;
  alt?: string;
  /** CSS aspect-ratio — '3 / 2' for stills, '16 / 9' for video. */
  ratio?: string;
  badge?: React.ReactNode;
  /** Centered element over the image, e.g. a play badge. */
  overlay?: React.ReactNode;
  title?: string;
  hint?: string;
  actions?: React.ReactNode;
  status?: React.ReactNode;
  onActivate?: () => void;
  style?: React.CSSProperties;
}

export declare function MediaCard(props: MediaCardProps): JSX.Element;
