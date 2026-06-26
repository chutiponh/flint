---
phase: 02-extended-tools
plan: 05
subsystem: number-base-converter
tags: [transformer, viewmodel, view, definition, bitfield, tdd, two-complement]
dependency_graph:
  requires: [02-01]
  provides: [NumberBaseTransformer, BitFieldView, NumberBaseViewModel, NumberBaseView, NumberBaseDefinition]
  affects: [ToolRegistry (Wave-7 registration)]
tech_stack:
  added: []
  patterns:
    - "Canonical UInt64 pattern + BitWidth + signed source-of-truth (ColorViewModel analog)"
    - "width.mask special-case for w64 to avoid 1<<64 UB"
    - "Two's complement via Int8/16/32/64(bitPattern:) — not raw UInt64 math"
    - "BitFieldView: pure SwiftUI toggle grid, MSB-left, nibble+byte visual grouping"
    - "onChange(of:)-based field sync with editingBase sentinel to prevent feedback loops"
key_files:
  created:
    - Tools/NumberBase/NumberBaseTransformer.swift
    - Tools/NumberBase/NumberBaseViewModel.swift
    - Tools/NumberBase/NumberBaseView.swift
    - Tools/NumberBase/NumberBaseDefinition.swift
    - UI/Components/BitFieldView.swift
    - FlintTests/NumberBaseTransformerTests.swift
  modified:
    - Flint.xcodeproj/project.pbxproj
decisions:
  - "Bit-index convention: bit 0 = LSB, bit (width-1) = MSB; buttons rendered MSB-left (standard binary notation)"
  - "BitFieldView layout: 8 bits per row (one byte per row) — keeps 64-bit readable in 480pt popover without wrapping issues"
  - "Negative decimal parse: two's-complement via (0 &- magnitude) & mask — handles Int64.min edge case"
  - "Width-64 masking: UInt64.max literal instead of (1<<64)-1 to avoid shift UB"
  - "TDD: tests written alongside transformer in a single commit (implementation passed GREEN on first run)"
metrics:
  duration: "6 minutes"
  completed: "2026-06-26"
  tasks: 2
  files: 7
---

# Phase 02 Plan 05: Number Base Converter Summary

## One-liner

Canonical UInt64 bit-pattern transformer with exhaustive two's-complement test matrix (8/16/32/64-bit × signed/unsigned × all bases) + interactive `BitFieldView` + synchronous ViewModel + full Number Base tool UI.

## What Was Built

### Task 1: NumberBaseTransformer + Tests (TDD)

`Tools/NumberBase/NumberBaseTransformer.swift` — pure Foundation-only transformer:

- `enum NumberBase { case bin, oct, dec, hex }` with `.radix` property
- `enum BitWidth { case w8, w16, w32, w64 }` with `.mask: UInt64` (w64 = UInt64.max — no `1<<64` UB)
- `NumberBaseParseResult` struct carrying `pattern: UInt64` + `overflow: Bool`
- `parse(_:base:width:) -> Result<NumberBaseParseResult, NumberBaseTransformError>` — tolerates `0b`/`0x` prefixes; validates digits per base; supports negative decimal (two's-complement); masks to width + sets overflow flag when magnitude exceeds width
- `binary(pattern:width:)` — zero-padded to exactly `width` bits
- `octal(pattern:width:)` — plain octal string
- `decimal(pattern:width:signed:)` — for signed, dispatches to `Int8/16/32/64(bitPattern:)` for correct two's-complement rendering
- `hex(pattern:width:)` — uppercase, zero-padded to `width/4` hex digits
- `toggleBit(pattern:index:) -> UInt64` — XOR at bit index

`FlintTests/NumberBaseTransformerTests.swift` — 43 tests:

- Width × signed/unsigned × {0, max, min, -1, overflow, empty, invalid-digit, large-input}
- 8-bit: 0xFF→"-1" (signed), 0x80→"-128", 0x7F→"127"
- 16-bit: Int16 min/max verified
- 32-bit: Int32 min/max verified
- 64-bit: Int64 min/max + UInt64.max; no `1<<64` UB; binary emitter produces 64 chars
- Overflow: 256 in 8-bit → masks to 0 + overflow=true
- Tolerance: `0b`/`0x` prefix stripping; negative decimal parsing
- Crash guards: empty string, invalid digit, 10K-char input

### Task 2: BitFieldView + ViewModel + View + Definition

`UI/Components/BitFieldView.swift`:

- Pure SwiftUI toggle grid; no `NSViewRepresentable`
- `width` bits rendered MSB-left in rows of 8 (one byte/row)
- Nibbles separated by 8pt gap; per-bit 20×20pt buttons with `.system(size:10)` labels
- Per-bit `.accessibilityLabel("Bit N, value 0/1")` + `.accessibilityHint` (INFRA-15)
- Bit-index direction documented in file comment: bit 0 = LSB

`Tools/NumberBase/NumberBaseViewModel.swift`:

- Single canonical `pattern: UInt64` + `width: BitWidth` + `signed: Bool` source-of-truth
- `deriveAllFields()` re-computes all four base strings from `pattern` on every change
- `update(from:text:)` — synchronous parse + overflow detection (no debounce — CF-01)
- `toggleBit(_:)` — delegates to `NumberBaseTransformer.toggleBit`
- `applyWidthChange(_:)` — masks pattern to new width, sets overflow if needed
- `ToolShortcutActions`: `primaryOutput()` = decText; `clearInput()` resets to 0
- History write via injected `onSaveHistory` closure (INFRA-09)

`Tools/NumberBase/NumberBaseView.swift`:

- Convention B (HashView pattern): `NumberBaseView(onSaveHistory:)` + `NumberBaseContentView(@Bindable)`
- Segmented `Picker` (8/16/32/64) with `.accessibilityLabel("Bit width")`
- `Toggle(.checkbox)` "Signed" with `.accessibilityLabel("Signed integer mode")`
- 4 editable `TextField` rows (BIN/OCT/DEC/HEX): monospaced 13pt, per-field `CopyButtonView`
- `BitFieldView` bound to canonical pattern via closure-based toggle
- `WarningBannerView("Value truncated — exceeds N-bit range", severity: .warning)` on overflow
- `InlineErrorView` for invalid-digit errors
- `onChange(of:)` sync with `editingBase` sentinel prevents feedback loops during mid-edit
- `.toolShortcuts(viewModel)` applied

`Tools/NumberBase/NumberBaseDefinition.swift`:

- `id: "number-base"`, `category: .conversion`, `detectionPredicate: nil` (search-only)
- Keywords include "two's complement", "bit", "radix", "signed", "unsigned"
- `NumberBaseViewWrapper` with `@Environment(HistoryStore.self)` injection
- NOT registered in ToolRegistry (Wave-7 plan)

## Deviations from Plan

None — plan executed exactly as written.

## Threat Mitigations

| Threat | Mitigation | Location |
|--------|-----------|----------|
| T-02-NUM-IV (Input Validation) | Result-returning parse; empty/invalid-digit → failure; width-64 shift UB special-cased; all paths tested | NumberBaseTransformer.parse() |
| T-02-NUM-OF (Overflow) | Overflow = mask + overflow flag; never crash; WarningBannerView shown in UI | parse() + NumberBaseView |

## Self-Check: PASSED

- `Tools/NumberBase/NumberBaseTransformer.swift` — exists
- `Tools/NumberBase/NumberBaseViewModel.swift` — exists
- `Tools/NumberBase/NumberBaseView.swift` — exists
- `Tools/NumberBase/NumberBaseDefinition.swift` — exists
- `UI/Components/BitFieldView.swift` — exists
- `FlintTests/NumberBaseTransformerTests.swift` — exists
- Commit `1f4083b` (test + transformer) — exists
- Commit `092d286` (Task 2 full implementation) — exists
- `xcodebuild test -only-testing:FlintTests/NumberBaseTransformerTests` — PASSED
- `xcodebuild build` — BUILD SUCCEEDED
