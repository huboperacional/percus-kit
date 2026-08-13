Confirmation only. Routine feedback belongs in StatusLine, next to the control.

```jsx
<Dialog title="Remove this photo?" description="The slot goes empty until you upload a new one."
  actions={<><Button onClick={close}>Cancel</Button><Button variant="danger" onClick={remove}>Remove</Button></>} />
```
