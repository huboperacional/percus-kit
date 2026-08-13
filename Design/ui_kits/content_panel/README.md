# UI kit — Content panel

The canonical application view of this system, and the screen the whole system was extracted from: a single-user content manager where a non-technical owner replaces photos and video links on a marketing site.

## Screens in `index.html`
1. **Sign in** — split modal card: form on the left, red poster panel on the right. Click "Sign in" to enter the panel; "Sign out" in the sidebar returns here.
2. **Panel** — `grid-template-columns: var(--sidebar-width) minmax(0, 1fr)` with `--space-6` gap and padding. Sticky `Sidebar` on the left, a vertical stack of `Panel`s on the right, opening with `PageHeader`.
3. **Search results** — typing in the sidebar search replaces the section view with one panel of matches drawn from every section; each result's hint becomes "Section · Group".

## Interactions worth copying
- One section renders at a time: navigation replaces scrolling. Long field lists never become one long page.
- `FieldRow` for anything needing typed input plus a visual preview; `MediaCard` grid for pure image fields. Rows above the grid inside the same panel.
- Save feedback is inline (`StatusLine`) and clears after 3.2s. Errors persist until the user edits the field again.
- Video links accept any YouTube URL form (`youtu.be/ID`, `watch?v=ID`, `embed/ID`, `shorts/ID`) or a bare 11-char ID; the preview refreshes from `img.youtube.com/vi/<id>/hqdefault.jpg` on save.

## Composition rules
Screens compose the components in `components/` — they never restyle them. Anything a screen needs that the components don't provide is either a token-styled `div` (as with the brand mark and the poster panel) or a missing component worth adding to the system.
