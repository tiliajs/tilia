---
name: .dismiss
slug: dismiss
kind: function
module: core
since: "0.1"
sort: 120
summary: Clear the rejected writes list on status.
signature:
  ts: "collection.dismiss(): void"
  res: "collection.dismiss: unit => unit"
tags: []
---

`dismiss` empties `status.rejected`. Rejections accumulate until dismissed, so the UI decides how long the user sees "the server refused this" — a toast, a banner, a review dialog.

Dismissing only clears the report: the caches were already converged back to server truth when the rejection happened. See [status](api.html#status).

```typescript
banner.onclick = () => cards.dismiss();
```

```rescript
banner.onClick = () => cards.dismiss()
```
