---
phase: 02-extended-tools
plan: 03
subsystem: color-converter
tags: [color, oklch, chromakit, wcag, eyedropper, nscolorsampler]
dependency_graph:
  requires: [02-01]
  provides: [ColorTransformer, ColorViewModel, ColorView, ColorDefinition]
  affects: [02-07-registration]
tech_stack:
  added: []
  patterns: [OKLCH hand-computed reverse via CSS Color L4 matrices, WCAG 2.1 contrast ratio, gamut detection via unclamped sRGB range check]
key_files:
  created:
    - Tools/Color/ColorTransformer.swift
    - Tools/Color/ColorViewModel.swift
    - Tools/Color/ColorView.swift
    - Tools/Color/ColorDefinition.swift
    - FlintTests/ColorTransformerTests.swift
  modified:
    - Flint.xcodeproj/project.pbxproj
decisions:
  - "OKLCH reverse (sRGB→OKLCH) hand-computed via CSS Color Level 4 Oklab inverse matrix chain — ChromaKit has no reverse API"
  - "Gamut detection via own unclamped sRGB math before ChromaKit clamp — NSColor.usingColorSpace silently clamps, so we run the raw chain independently"
  - "ColorViewModel: synchronous pure transforms with no Debounce — color math is cheap (CF-01)"
  - "View field sync: local @State TextFields synced from VM on canonicalRGBA change — prevents feedback loops from N drifting strings"
  - "formatRow helper: label + copyTooltip + copyText as named params, content as trailing closure — avoids multiple-trailing-closure Swift ambiguity"
metrics:
  duration: "10 minutes"
  completed: "2026-06-26"
  tasks: 2
  files: 6
---

# Phase 02 Plan 03: Color Converter Summary

Complete Color Converter vertical slice — pure transformer with OKLCH/WCAG math + canonical-state ViewModel + accessible swatch/eyedropper/rows/sliders/WCAG View + Definition with hex detection predicate — all CLR-01..04 requirements met, 29 transformer tests passing.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ColorTransformer (pure math) + ColorTransformerTests | c0b7d39 | ColorTransformer.swift, ColorTransformerTests.swift, project.pbxproj |
| 2 | ColorViewModel + ColorView + ColorDefinition | 995b6ba | ColorViewModel.swift, ColorView.swift, ColorDefinition.swift, project.pbxproj |

## Verification

- `! grep -q "import SwiftUI" Tools/Color/ColorTransformer.swift` — PASS (no SwiftUI in transformer)
- `xcodebuild test -only-testing:FlintTests/ColorTransformerTests` — PASS (29/29 tests)
- `grep -q "NSColorSampler" Tools/Color/ColorView.swift` — PASS
- `grep -q "ColorPicker" Tools/Color/ColorView.swift` — PASS
- `grep -q "category: .conversion" Tools/Color/ColorDefinition.swift` — PASS
- `grep -q "detectionPredicate:" Tools/Color/ColorDefinition.swift` — PASS
- `grep -q "ToolShortcutActions" Tools/Color/ColorViewModel.swift` — PASS
- `xcodebuild build` — PASS (BUILD SUCCEEDED)
- ColorDefinition.make() NOT registered in ToolRegistry — PASS (Wave-7 task)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift String subscript ambiguity in HEX parser**
- **Found during:** Task 1 build
- **Issue:** Private `String subscript(_ range: Range<String.Index>) -> String` extension conflicted with another subscript in the module, causing "ambiguous use of 'subscript(_:)'" compiler errors at lines 106-111
- **Fix:** Replaced String subscript with `Array(expanded)` indexing — `let chars = Array(expanded); let s = String(chars[i..<i+2])` — no ambiguity, no new type
- **Files modified:** `Tools/Color/ColorTransformer.swift`
- **Commit:** c0b7d39

**2. [Rule 1 - Bug] Multiple trailing closure syntax for formatRow function**
- **Found during:** Task 2 build
- **Issue:** The formatRow helper was written with 3 parameters after the first trailing closure (`copyText:` and `copyTooltip:` as labeled blocks). Swift doesn't support mixing trailing-closure and non-closure parameters in that order.
- **Fix:** Reordered `formatRow` signature to put `copyTooltip:` and `copyText:` as named non-closure parameters before the trailing `@ViewBuilder content:` closure. Call sites updated accordingly.
- **Files modified:** `Tools/Color/ColorView.swift`
- **Commit:** 995b6ba

**3. [Rule 1 - Bug] ColorViewModel missing SwiftUI import**
- **Found during:** Task 2 build
- **Issue:** `SwiftUI.Color` used in `swiftUIColor` computed property but `import SwiftUI` was missing from ColorViewModel.swift
- **Fix:** Added `import SwiftUI` to ColorViewModel.swift
- **Files modified:** `Tools/Color/ColorViewModel.swift`
- **Commit:** 995b6ba

## Known Stubs

None — all format rows are wired to the canonical RGBA via ColorTransformer. The WCAG section is fully functional with live ratio and AA/AAA badges. No placeholder text or hardcoded empty values.

## Threat Model Coverage

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-02-CLR-IV | Every parse path in ColorTransformer returns nil/guarded value; achromatic divide-by-zero guarded; garbage-input test cases in ColorTransformerTests; no force-unwrap anywhere |
| T-02-CLR-GAMUT | `oklchToLinearSRGB_unclamped` runs the CSS Color L4 chain independently to detect out-of-sRGB channels before ChromaKit's silent clamp; `GamutResult.isOutOfGamut` flag propagated to `ColorViewModel.outOfGamutWarning`; `WarningBannerView(.warning, "Out of sRGB gamut — clipped")` shown above swatch |

## Self-Check: PASSED

- All 5 created files exist on disk
- Both task commits (c0b7d39, 995b6ba) exist in git log
- Build succeeds (BUILD SUCCEEDED)
- 29/29 ColorTransformerTests pass
