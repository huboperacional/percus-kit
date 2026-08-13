# PanelKit — a design system for internal tools

> ## ⚠️ Status no Percus: REFERÊNCIA VISUAL — não é código de produção
>
> O PanelKit é o **norte** de design: dele saem as decisões de raio de canto, densidade,
> hierarquia de tipo, espaçamento, e as regras de foco/hover/erro. **O código sai do stack
> Percus** — Tailwind 4 + shadcn/ui, copiar-pro-repo (`02_INFRA_E_STACK_PERCUS.md:629`).
>
> **Não copie os `.jsx` desta pasta para um projeto.** Eles usam objeto de estilo inline lendo
> CSS custom properties, que é justamente o que `02_INFRA_E_STACK_PERCUS.md:642` veta. Leia-os
> como especificação — traduza para classe Tailwind no destino.
>
> Consequência prática: os defeitos abaixo, levantados no review cross-provider de 2026-08-13,
> **ficam sem conserto de propósito** — são de material de referência, não de código que roda:
>
> - `_ds_bundle.js` — Babel standalone via CDN com `new Function` (exige `unsafe-eval`, sem SRI)
> - `components/core/Button.jsx` — `HOVER`/`PRESS` sem fallback: variante inválida some com o fundo
> - `components/content/MediaCard.jsx` — card clicável sem `role`/`tabIndex`/`onKeyDown`
> - `tokens/typography.css` — `@import` de fonte do Google, dependência externa bloqueando render
>
> Se algum dia o PanelKit virar código de produção, esses quatro são pré-requisito.
>
> Exemplo de aplicação correta: `templates/permissoes-por-perfil/` — arquitetura de informação
> da Cloudflare, direções visuais do PanelKit, implementação em Tailwind + shadcn.

PanelKit is the generic, brand-neutral extraction of the AutoWorx content-panel redesign: a **soft-modernist admin aesthetic** — a light grey desk, white rounded panels floating on it, pill-shaped controls, one red accent, and image-first cards where the picture is the label.

It exists so design and engineering start every new internal tool from the same footing: same tokens, same components, same layout shell, same feedback rules. It is deliberately **product-agnostic** — nothing in here names a client, a service or an industry.

## Where it came from

- Source design: the AutoWorx admin panel redesign (v2) built in this workspace — sign-in screen plus a 7-section, ~54-field content manager.
- Derived from that work only. No external codebase, Figma file or brand guideline was provided, so **there is no logo**: wherever a mark belongs, the system renders a rounded accent tile with the product's initial next to the product name in display type. Do not invent one — drop in the real asset when the consuming product has one.
- Fonts: **Archivo** (400/500/600/800) from Google Fonts. This was the source design's typeface; it is a genuine choice here, not a substitution. Swap `--font-display` / `--font-body` to rebrand.
- Icons: **Lucide** (https://lucide.dev), 2px stroke on `currentColor`, 14–16px in interface contexts. Not vendored — the components take icons as props so the consuming app supplies them from its own Lucide package. The only drawn glyph in the system is the solid play triangle over video thumbnails.

## Rebranding in four values

Almost all identity lives in six variables in `tokens/colors.css` and two in `tokens/typography.css`:

```
--accent, --accent-hover, --accent-press, --accent-text, --accent-tint, --accent-tint-strong
--font-display, --font-body
```

Everything else — greys, radii, shadows, motion — is the *system*, and should survive a rebrand untouched. Keep `--accent-text` dark enough for AA body text on white; the base accent is for fills, icons and large type only.

---

## VISUAL FOUNDATIONS

**Ground and surfaces.** A three-layer stack, always in this order: the app ground `--bg-app` (#f6f5f4), white panels `--bg-surface` on top of it at `--radius-panel` (20px) with `--shadow-sm`, and inside panels either bordered cards (`--border-card`, `--radius-card` 16px, no shadow at rest) or inset wells (`--bg-inset`, `--radius-tile` 12px, no border). Panels never nest inside panels; cards never nest inside cards.

**Corner radii.** Nothing is sharp and nothing is a blob. Controls are fully round (`--radius-pill`): every button, chip, badge, count and search field. Surfaces step up with size: input 10 → tile 12 → card 16 → panel 20 → modal 24. If you're unsure which to use, match the element's neighbour, not its size.

**Colour.** Mono accent. Red appears in four roles only: the primary button fill, the active navigation tint, small emphasis (pills, inline saved/error text) and the sign-in poster panel. Everything else is ink on white — `--text-primary` for content, `--text-secondary` for labels, `--text-tertiary` for hints and descriptions. Semantic colours exist (`--success`, `--warning`) but the system deliberately reuses the accent for both save-success and error, because in a single-user tool the accent already means "the system is talking to you"; reach for `--success` only when green genuinely disambiguates.

**Type.** Archivo throughout. Two voices: **display** (weight 800, `letter-spacing: -0.03em`) for anything that names something — page headings, group headings, card titles, button labels, nav items; and **body** (weight 400) for copy, labels, hints and counts. Buttons and nav items use the display face at small sizes, which is what gives the UI its compact confidence. The scale is short on purpose (11/12/13/14/15/17/26/30) — if you need a size that isn't there, you probably need a different element.

**Borders and dividers.** Hairlines only, and only where a card edge must read against white: `--border-card` on cards, `--border-input` on inputs, `--border-strong` for inactive dots. Grouping is done with panels and gaps, not rules — there are no horizontal dividers in this system.

**Elevation.** Four ink-tinted steps: `--shadow-sm` (panels and secondary buttons, always on), `--shadow-md` (floating chrome), `--shadow-card-hover` (cards under the pointer), `--shadow-modal` (dialogs, the sign-in card). One coloured shadow exists — `--shadow-accent` under the primary button. Never stack shadows or invent new ones.

**Layout.** A two-column shell: `var(--sidebar-width)` (276px) sticky left, `minmax(0, 1fr)` right, `--gap-stack` between them and as page padding. Content is a vertical stack of panels, not a scrolling document. Grids of media use `repeat(auto-fill, minmax(var(--card-min), 1fr))` with `--gap-grid`, so cards reflow instead of shrinking. Descriptions cap at `66ch`. Below ~900px the sidebar becomes a horizontally scrolling chip row above the content and `FieldRow` stacks its preview above its control.

**Spacing.** Every step is a multiple of 4 (`--space-1` … `--space-10`). There are no in-between values — if a gap wants 14px, the layout is wrong, not the scale. Beyond the raw steps, spacing is *named by job* so nobody pads a surface by eye: surfaces take `--pad-panel`, `--pad-header`, `--pad-card`, `--pad-well`, `--pad-rail`, `--pad-modal`; distances take `--gap-stack` (24, between panels), `--gap-grid` (16, between cards), `--gap-row` (12, stacked rows in a panel), `--gap-inline` (8, controls side by side) and `--gap-label` (4, label → control → hint). Use the named token when one exists — a raw `--space-*` in a component is a smell.

**Control sizing — read this before importing.** Controls are sized by **padding, never by height**:

```
height = --control-pad-y-<size> × 2  +  --control-line  +  --control-border × 2
sm 5/12 → 32px    md 9/16 → 40px    lg 12/20 → 46px
```

`Button`, `IconButton`, `TextInput` and `NavItem` all read the same `--control-pad-y-*`, `--control-pad-x-*`, `--control-line` and `--control-border` tokens, which is the only reason a button and an input on the same row line up. Four rules keep it that way:

1. **Never set an explicit height on a control** — not in the component, not at the call site. Setting one desyncs it from the row the moment the font, the line box or the touch override changes.
2. **Every variant carries a border**, filled ones included (`transparent`) — a solid button without one ends up 2px shorter than the input beside it. This is the single most common import bug.
3. **Matching `size` is mandatory for controls on the same row.** `<TextInput size="md" />` with `<Button size="md" />`. Rows align with `align-items: flex-end`, so mismatched sizes look almost right and drift by 6–8px.
4. **Icon-only controls** take `--control-h-*` as a square and drop the x-padding (`--control-pad-icon-only`), so they stay on the row grid.

Touch is handled once, in `tokens/controls.css`: `@media (pointer: coarse)` raises `--control-pad-y-*` so every control clears 44px. No component branches on pointer type, and nothing needs a `touch` prop.

Two derived tokens exist for the cases padding can't cover: `--control-pad-x-inset` (x-padding when a leading icon sits inside a field) and `--control-gap` (icon → label inside a control). `Field` owns the vertical rhythm around a control via `--gap-label`, so no caller should add a margin to an input.

**Imagery.** Full colour, `object-fit: cover`, never tinted, duotoned or desaturated — in a content tool the photograph *is* the data. Stills are 3:2, video 16:9. Labels over imagery are `--overlay-badge` pills (72% ink, white text, uppercase); the only glass element in the system is the `--overlay-glass` play badge with `--shadow-float`. Empty media slots show `--neutral-200`, not a placeholder illustration.

**Transparency and blur.** Almost none. Three sanctioned alphas: badge overlays, the glass play badge, and `--overlay-on-accent` pills on a red field. No frosted panels, no blurred backdrops — the dialog scrim is a flat 45% ink.

**Gradients.** One, and only on the sign-in screen: `radial-gradient(120% 90% at 100% 0%, var(--accent-tint), var(--bg-app))`. Panels, cards, buttons and headers are flat fills.

**Animation.** Quiet and short. `--dur-fast` (150ms) for background and border changes, `--dur-base` (180ms) for shadow and lift, `--dur-slow` (300ms) for the media zoom, all on `--ease-out`. Cards lift `-2px` and gain `--shadow-card-hover` on hover while their image scales to `1.04`; new cards fade up 4px. Nothing bounces, nothing springs, nothing loops.

**Hover / press / focus / disabled.** Hover: neutral surfaces tint to `--bg-muted`, the primary button darkens to `--accent-hover`, cards lift. Press: everything shifts `translateY(1px)`; the primary button goes to `--accent-press`. Focus: `2px solid var(--accent)` at `outset 2px` on `:focus-visible` — inputs instead switch their border to the accent with no offset. Disabled: `opacity: .45` and `cursor: not-allowed`, no colour change.

**Feedback.** Inline and local, never global. Each editable row owns a `StatusLine` that always occupies its space: idle instruction in tertiary ink, success as an accent-tinted check circle that clears after ~3.2s, error as an alert glyph with the input border switched to the accent, persisting until the user edits. There are no toasts in this system, and errors never live at the top of the page away from their cause.

---

## CONTENT FUNDAMENTALS

**Voice: plain, second person, calm.** The tool addresses the user as "you" and never refers to itself as "we". No exclamation marks, no praise, no personality. "Sign in to manage the photos and videos on your site." — not "Let's get you signed in!"

**Sentence case everywhere.** Headings, buttons, labels, pills. Uppercase is reserved for two things: kickers (`Sections`, `Search` — 11px, `--tracking-kicker`) and badges over imagery (`BEFORE`, `VIDEO`). Never uppercase a sentence.

**Buttons are verbs, and they name the object when it's ambiguous:** "Save", "Change", "Sign in", "Remove". Never "Submit", "OK", "Click here".

**Labels name the thing the way the user thinks about it, not the way the database does.** "Video link", not "YouTube ID". "Change", not "Upload replacement asset". Where a technical name is unavoidable, a hint carries the context: title "Gallery photo 3", hint "Home · Gallery".

**Hints instruct, they don't reassure.** They say what to do or where it appears: "Paste the link from YouTube's Share button.", "Plays muted behind the headline.", "Header and footer — transparent PNG."

**Errors name the mistake and the fix, in one sentence, no error codes, no blame:** "That doesn't look like a YouTube link. Paste the one from the Share button."

**Confirmations state the consequence, not the mechanic:** "Saved — live on the site" rather than "Success" or "Changes saved to database".

**Counts are surfaced everywhere** — "26 editable fields", nav count pills, "Section 01 / 07". In a tool, quantity is orientation; it tells the user how much work a destination holds. Zero-pad section positions (`01 / 07`).

**Em dashes join a label to its consequence** ("Saved — live on the site"); middle dots join breadcrumbs ("Home · Gallery"). Curly quotes and apostrophes, always.

**No emoji. Anywhere.** Status is carried by the Lucide check and alert glyphs.

---

## ICONOGRAPHY

Lucide, 2px stroke, `currentColor`, rounded caps and joins. Sizes: 14px inside small buttons and status lines, 15px in standard controls and search, 16px in icon buttons. Icons are always paired with a label except in `IconButton` (where `label` becomes the accessible name) and in status lines (where the adjacent text is the label).

The working set for an admin tool: `search`, `upload`, `log-out`, `chevron-left`, `chevron-right`, `check`, `alert-circle`, `trash-2`, `plus`, `external-link`, `image`, `video`, `settings`. The one non-Lucide glyph is the solid play triangle (`M8 5v14l11-7z`) used inside the glass badge over video thumbnails — it is filled, not stroked, and always accent-coloured.

No icon fonts, no PNG icons, no emoji, no Unicode symbols as icons, no decorative illustrations. Components take icons as `React.ReactNode` props so the consuming app supplies them from its own package.

---

## Index

| Path | What's there |
| --- | --- |
| `styles.css` | The single entry point — `@import` list only. Link this from every page. |
| `tokens/` | `colors.css`, `typography.css`, `spacing.css` (4px scale + named paddings/gaps), `controls.css` (**control sizing — read this first**), `radius.css`, `elevation.css`, `base.css` (resets + heading defaults + `.pk-muted` / `.pk-kicker`). |
| `components/core/` | `Button`, `IconButton`, `TextInput`, `Field`, `Pill`, `StatusLine` |
| `components/layout/` | `Panel`, `PageHeader` |
| `components/navigation/` | `Sidebar`, `NavItem` |
| `components/content/` | `MediaCard`, `FieldRow` |
| `components/feedback/` | `Dialog` |
| `ui_kits/content_panel/` | The canonical app view: sign-in, sidebar shell, section panels, search results. Read its README for the interaction rules. |
| `guidelines/` | Foundation specimen cards — colour, type, spacing, **control sizing**, radius, elevation, motion, imagery, the accent poster. |
| `SKILL.md` | Agent-Skills front matter so this folder works as a skill in Claude Code. |

Every component ships `<Name>.jsx`, `<Name>.d.ts` (props contract) and `<Name>.prompt.md` (what & when, with a usage example) — read the `.prompt.md` before using a component.

## Intentional additions

Nothing here existed as a component library before; the inventory was derived from the source design. Two components are generalisations rather than direct extractions, and are flagged as such:

- **`Dialog`** — the source design had no modal. Included because destructive confirmation is unavoidable in admin tools, styled from the existing modal tokens (`--radius-modal`, `--shadow-modal`, `--overlay-scrim`).
- **`FieldRow`** — a generic version of the source's video-link row: preview + label + control + commit + status. Any "setting whose value is text but whose meaning is visual" fits it.

## Using it in a codebase

1. Link `styles.css` (or copy `tokens/` into your own CSS pipeline — the custom properties are framework-agnostic; for Tailwind, map them in `theme.extend`, including the control tokens as `spacing`/`minHeight` entries so utilities stay on the same rhythm).
2. Copy `components/` in, or reimplement each component against its `.d.ts` using your framework's primitives. The JSX here is plain React with inline styles referencing `var(--*)` — no dependencies beyond React.
3. Compose screens the way `ui_kits/content_panel/` does: shell → sidebar → panel stack. Don't restyle components inside a screen; if a screen needs something the components don't offer, that's a new component.
4. If controls come out misaligned after an import, check in this order: an explicit `height` or `padding` override at a call site, a filled variant that lost its transparent border, a `line-height` reset from the host's CSS (the controls need `--control-line`, not `normal`), and mismatched `size` props on the same row.

## Caveats

- No logo or brand assets — see above. The brand mark in the UI kit is a placeholder tile.
- Imagery in cards and kits comes from `picsum.photos`; replace with real content.
- Only a light theme exists. A dark theme would need a second scope in `tokens/colors.css` (and shadows re-tuned to a hairline + ambient approach).
- Components are prototype-grade: no focus trapping in `Dialog`, no form validation library, no i18n.
