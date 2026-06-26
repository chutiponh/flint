---
status: partial
phase: 02-extended-tools
source: [02-VERIFICATION.md]
started: 2026-06-26T14:00:00Z
updated: 2026-06-26T14:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Regex never-freeze (RGX-02)
expected: Paste pattern `(a+)+$` against `aaaaaaaaaaaaaaaaaaaa!` in Regex Tester. UI stays fully responsive; timeout warning banner appears within ~2s; last-good highlight stays visible but dimmed.
result: [pending]

### 2. Markdown PDF export (MD-03)
expected: Type Markdown, Save ▾ → "Save as PDF…", pick a filename. A non-blank, styled PDF is written; no silent failure.
result: [pending]

### 3. Color eyedropper (CLR-02)
expected: Click eyedropper in Color Converter, pick a screen pixel. Canonical color updates across all rows (HEX/RGB/HSL/HSV/OKLCH); no permission dialog.
result: [pending]

### 4. OKLCH out-of-gamut warning (CLR-01/CLR-02)
expected: Enter L=0.7 C=0.4 H=145 in OKLCH fields. "Out of sRGB gamut — clipped" warning banner appears above the swatch; swatch shows clipped color.
result: [pending]

### 5. Markdown editor syntax highlighting (MD-02) — POSSIBLE GAP
expected: Open Markdown Previewer, type `# Hello **world**`. The editor shows Markdown syntax coloring (heading marker / bold markers highlighted).
result: [pending]
note: Editor currently uses plain SyntaxEditorView (isRichText=false) — no Markdown-syntax highlight pass was implemented. MD-02 requirement text is "Editor highlights Markdown syntax; preview highlights code blocks". Preview code-block highlighting IS present; editor-side Markdown highlighting is NOT. Decide: accept plain editor for v1, or run gap closure.

### 6. Launcher visibility + fuzzy search
expected: Open popover, type 'regex', 'color', 'markdown', 'base', 'diff' — each tool appears and opens its correct UI.
result: [pending]

### 7. Detection chain (no Phase-1 shadowing)
expected: Copy `#3366FF`, focus Flint → detection banner offers Color Converter; accepting opens it pre-filled. Copying JSON / a JWT / Base64 still routes to Phase-1 tools.
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps

- MD-02 editor-side Markdown syntax highlighting not implemented (preview code-block highlighting is present). Pending developer decision in Test 5.
