One pill button for every action — `primary` for the single committing action in a row, `secondary` for everything else, `ghost` inside dense toolbars, `danger` only for destructive confirmation.

```jsx
<Button variant="primary" onClick={save}>Save</Button>
<Button icon={<UploadIcon />}>Change</Button>
<Button variant="primary" size="lg" block align="left">Sign in</Button>
```

Never more than one `primary` per card or row. `size="sm"` for controls inside a media card; `lg` only for a form's submit.
