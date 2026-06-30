---
status: partial
phase: 05-add-image-compression-feature
source: [05-VERIFICATION.md]
started: 2026-06-30T08:37:15Z
updated: 2026-06-30T09:05:00Z
---

## Current Test

[testing paused — PNG compression-ratio gap found, routing to fix]

## Tests

### 1. Live results table
expected: Dropping images shows a per-row thumbnail, original→new size, and green "−NN%" saved (or secondary "+N%" if larger), updating live as each image finishes.
result: [pending]

### 2. Lossless slider gate (D-05)
expected: When every dropped file is PNG/TIFF, the quality slider is disabled and a helper line explains lossless formats ignore quality.
result: [pending]

### 3. Non-image / corrupt input never crashes (INFRA-17)
expected: Dropping a non-image (or a corrupt image) alongside valid images shows a WarningBannerView on the failed row; the app never crashes and valid images still compress.
result: [pending]

### 4. Preset button active styling
expected: The matching preset button (Web/Email/Max) renders `.borderedProminent` when active and `.bordered` otherwise; selecting a preset moves the slider.
result: [pending]

### 5. Cancel mid-batch
expected: Pressing Cancel during a large batch stops pending rows; already-finished rows keep their results; the Cancel button hides and isCompressing clears.
result: [pending]

### 6. Collision disambiguation end-to-end (D-07/D-08)
expected: Compressing the same source twice produces `photo-compressed.jpg` then `photo-compressed-1.jpg` — the original is never overwritten.
result: [pending]

### 7. Launcher search routing
expected: Searching the launcher finds and routes to the Image Compressor tool.
result: pass
note: "Initially appeared missing — root cause was a stale binary launched from one of 10 DerivedData folders, not a code defect. After clean build + relaunch from canonical BUILD_DIR, tool appears in grid and search ('image'/'compress')."

### 8. PNG compression ratio
expected: Compressing a photographic PNG achieves savings comparable to dedicated PNG optimizers (~70-85%).
result: issue
reported: "doesn't compress much — online tool went 7MB to 1MB without losing quality"
severity: major

## Summary

total: 8
passed: 1
issues: 1
pending: 6
skipped: 0
blocked: 0

## Gaps

- truth: "Compressing a photographic PNG achieves savings comparable to dedicated PNG optimizers (~70-85%)"
  status: failed
  reason: "User reported: online tool compressed a 7.27MB PNG to 1.35MB with no visible quality loss; Flint barely shrinks it"
  severity: major
  test: 8
  root_cause: "ImageCompressTransformer gives PNG/TIFF nil destination properties (lines 76-78), so PNGs are losslessly re-encoded as truecolor RGBA — no size reduction. Verified: online tool's output is identical 2752x1536 dimensions but converted from 8-bit RGBA truecolor to 8-bit colormap (256-color palette), i.e. PNG color quantization (pngquant/libimagequant-style). Apple's ImageIO/CGImageDestination has NO palette-quantization API; plain re-encode of the source = 6.9MB (still RGBA)."
  artifacts:
    - path: "Tools/ImageCompress/ImageCompressTransformer.swift"
      issue: "PNG path uses nil props (no quantization) — line 76-78"
  missing:
    - "Native pure-Swift color quantizer (median-cut/octree) producing an indexed-color palette"
    - "Indexed (colormap) PNG writer — CGImageDestination cannot emit indexed PNG, needs custom writer"
    - "Quantization on by default for PNGs (user decision); preserve alpha"
  decisions:
    - "Engine: pure-Swift native quantizer, NO C dependency (libimagequant/pngquant is GPL/LGPL — blocks App Store v2 sandbox per CLAUDE.md)"
    - "Default: PNG quantization ON by default"
  debug_session: ""
