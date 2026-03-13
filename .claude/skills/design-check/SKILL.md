---
name: design-check
description: Audit React components against the White and Grey design system from CLAUDE.md. Catches forbidden patterns like filled buttons, gradients, dark backgrounds, and wrong text colors.
user-invocable: true
---

## Design System Audit — White & Grey

Scan React/TSX files for violations of the White & Grey design system defined in CLAUDE.md.

### What to Check

Scan all `.tsx` files in the diff (or all frontend files if no diff) for these violations:

#### Forbidden Patterns (BLOCKING)

- `variant="primary"` on any `<Button>` — renders filled/dark button
- `tone="critical"` on any `<Button>` — renders red fill
- Any inline `background` style that is not `#FFFFFF`, `#F6F6F7`, or `#EDEEEF`
- Any `gradient` in CSS or inline styles
- Any `box-shadow` heavier than `--p-shadow-100`
- Text color `#000000` (must use `#1A1A1A` instead)
- Any `tone="primary"` that renders green/black fill

#### Warnings

- Missing `variant="tertiary"` or `plain` on buttons (default Polaris button has fill)
- Colors not from the design token palette
- Shadows used without checking weight

### Allowed Polaris Patterns

```
OK:  <Button variant="tertiary">       → grey text, no fill
OK:  <Button plain>                     → text-only button
OK:  <Card background="bg">            → white card
OK:  Badge with tones: subdued, warning, critical (muted versions)
```

### Output Format

```
## Design System Audit

### Violations (BLOCKING)
- frontend/src/pages/Dashboard.tsx:15 — <Button variant="primary"> found, use variant="tertiary" instead
- frontend/src/components/Header.tsx:8 — color #000000 found, use #1A1A1A

### Warnings
- frontend/src/pages/Settings.tsx:42 — <Button> without explicit variant, may render with fill

## Verdict: PASS / FAIL (N violations)
```
