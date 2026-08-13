Group related content in a Panel; use one per logical group so a long page reads as a stack of cards rather than a scroll.

```jsx
<Panel title="Home gallery" meta="10 fields" note={<Pill>Rarely changed</Pill>}>…</Panel>
```

Don't nest panels. For a grid of items inside, use MediaCard in an auto-fill grid.
