The left rail of every app view. Pair with a `grid-template-columns: var(--sidebar-width) minmax(0,1fr)` shell.

```jsx
<Sidebar brand={<BrandMark />} search={<TextInput pill leadingIcon={<Search />} />} footer={<Button align="left" icon={<LogOut />}>Sign out</Button>}>
  {sections.map(s => <NavItem key={s.id} {...s} />)}
</Sidebar>
```

Below ~900px, render the same items as a horizontally scrolling chip row above the content.
