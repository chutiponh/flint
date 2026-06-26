# Phase 2: Extended Tools - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-26
**Phase:** 2-Extended Tools
**Areas discussed:** Regex Tester, Color Converter, Markdown Previewer, Number Base + Text Diff

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Regex Tester | Layout, flag toggles, live highlight safety, replace, pattern library | ✓ |
| Color Converter | Format sync, eyedropper/panel, sliders, contrast, OKLCH gamut | ✓ |
| Markdown Previewer | Split layout, render, syntax highlight, toolbar, counts, HTML/PDF export | ✓ |
| Number Base + Text Diff | Bit-field UI, two's-complement; diff views, word-level, patch, ignore-ws/case | ✓ |

**User's choice:** All four areas (all five tools).

---

## Regex Tester — Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Vertical stack | Pattern+flags → test editor → collapsible results → replace section | ✓ |
| Tabs (Test/Replace) | Pattern+flags fixed; tabbed Test/Replace | |
| Side-by-side string+results | Test string left, results right | |

**User's choice:** Vertical stack (Recommended).

## Regex Tester — Safety on timeout

| Option | Description | Selected |
|--------|-------------|----------|
| Warning + keep last-good | Background eval, 2s cutoff + 300ms debounce; warn + dim last highlight | ✓ |
| Clear results + warning | Clear highlights, show warning only | |
| Manual run button | No live eval, click Run | |

**User's choice:** Show timeout warning, keep last-good (Recommended).

## Regex Tester — Pattern library access

| Option | Description | Selected |
|--------|-------------|----------|
| Dropdown/menu button | "Patterns ▾" menu next to pattern field | ✓ |
| Chips row | Always-visible tappable pills | |
| Both (chips + menu) | Few chips + overflow menu | |

**User's choice:** Dropdown/menu button (Recommended).

---

## Color Converter — Format layout

| Option | Description | Selected |
|--------|-------------|----------|
| All formats editable rows | Swatch + per-format editable row + copy; edit any → all sync | ✓ |
| One active editor + read-only | Pick input format; others read-only | |
| Sliders-primary | Sliders drive; format strings read-only | |

**User's choice:** All formats as editable rows (Recommended).

## Color Converter — Contrast checker placement

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsible section | Contrast section below converter; AA/AAA pass/fail | ✓ |
| Separate mode/tab | Convert vs Contrast segmented toggle | |
| Always-visible second swatch | Two slots side-by-side always | |

**User's choice:** Collapsible section in the tool (Recommended).

## Color Converter — Out-of-gamut OKLCH

| Option | Description | Selected |
|--------|-------------|----------|
| Gamut-clip + warning badge | Show clipped HEX/RGB + "Out of sRGB gamut — clipped" badge | ✓ |
| Raw values + warning only | Show raw converted RGB + warning, no clip | |
| Builder's call | Implementer decides, badge required | |

**User's choice:** Gamut-clip + warning badge (Recommended).

---

## Markdown Previewer — Editor/preview layout

| Option | Description | Selected |
|--------|-------------|----------|
| Toggle in popover, split in window | Segmented toggle when narrow; side-by-side in resizable window | ✓ |
| Always side-by-side | Editor left, preview right everywhere | |
| Always toggle | One pane everywhere | |

**User's choice:** Toggle editor/preview, side-by-side in window (Recommended).

## Markdown Previewer — Exported HTML styling

| Option | Description | Selected |
|--------|-------------|----------|
| Styled GitHub-like CSS | Bundled GFM stylesheet, inlined CSS, presentable PDF | ✓ |
| Bare semantic HTML | Raw tags, no styling | |
| Offer both on export | Menu picks styled or bare | |

**User's choice:** Styled, GitHub-like CSS (Recommended).

## Markdown Previewer — Toolbar + counts placement

| Option | Description | Selected |
|--------|-------------|----------|
| Toolbar above editor, counts in footer | Format buttons above editor; word-count/reading-time in footer | ✓ |
| All in one top bar | Format + counts + export in single bar | |
| Builder's call | Implementer places controls | |

**User's choice:** Toolbar above editor, counts in footer (Recommended).

---

## Number Base — Bit-field rendering

| Option | Description | Selected |
|--------|-------------|----------|
| Wrapped rows grouped by nibble/byte | Bits wrap, grouped 4/8-bit with index labels | ✓ |
| Single horizontal scroll row | One scrolling row | |
| Byte-stacked grid (8 cols) | Fixed 8-col grid, one byte/row | |

**User's choice:** Wrapped rows, grouped by nibble/byte (Recommended).

## Text Diff — Default view + input

| Option | Description | Selected |
|--------|-------------|----------|
| Stacked inputs → unified default in popover | Two stacked editors; unified default popover, side-by-side window | ✓ |
| Side-by-side default everywhere | Two inputs + diff side-by-side | |
| Builder's call on default | Toggle implemented, default by width | |

**User's choice:** Two stacked inputs → unified default in popover (Recommended).

---

## Claude's Discretion

- Debounce/timeout fine-tuning, nibble-vs-byte grouping, swatch size, SF Symbol glyph choices, the GitHub stylesheet contents, animation/spacing.
- Which (if any) new tools occupy default pinned slots vs search-only.
- Detail-level requirements (flag toggles g/i/m/s/x, named-group results, two's-complement across bit widths, jump-to-diff, unified-patch export, ignore-whitespace/case) follow REQUIREMENTS.md directly — not separately discussed.

## Deferred Ideas

None — discussion stayed within Phase-2 scope.
