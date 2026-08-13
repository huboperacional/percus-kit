For any setting whose value is text but whose meaning is visual — a video link, an embed, a URL with a preview.

```jsx
<FieldRow preview={<VideoThumb id={id} />} title="Hero background video" hint="Plays muted behind the headline"
  control={<Field label="Video link"><TextInput invalid={!!err} /></Field>}
  action={<Button variant="primary" onClick={save}>Save</Button>}
  status={<StatusLine state={state}>{msg}</StatusLine>} />
```

Rows stack with --space-3 and always sit above the MediaCard grid inside a Panel.
