---
phase: 02-extended-tools
plan: 01
subsystem: dependencies
tags: [spm, swift-diff, markdown-css, chromakit, swift-markdown, vendoring]
dependency_graph:
  requires: []
  provides: [ChromaKit 0.1.1, swift-markdown 0.8.0, SwiftDiff vendored, github-markdown.css]
  affects: [02-02-color, 02-03-markdown, 02-07-textdiff]
tech_stack:
  added: [ChromaKit 0.1.1, swift-markdown 0.8.0 + cmark-gfm]
  patterns: [Myers diff algorithm, vendored+patched source]
key_files:
  created:
    - Tools/TextDiff/SwiftDiff/diff.swift
    - Tools/TextDiff/SwiftDiff/cleanup.swift
    - Tools/TextDiff/SwiftDiff/common.swift
    - Tools/TextDiff/SwiftDiff/String.swift
    - Tools/TextDiff/SwiftDiff/UnicodeScalar.swift
    - Tools/TextDiff/SwiftDiff/NSRegularExpression.swift
    - Resources/github-markdown.css
    - FlintTests/SwiftDiffVendorTests.swift
  modified:
    - Flint.xcodeproj/project.pbxproj
    - Flint.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
decisions:
  - "ChromaKit pinned to EXACT 0.1.1 (no auto-upgrade) — supply-chain hygiene for single-maintainer package"
  - "SwiftDiff vendored with Myers algorithm rewrite — original bisect port had array bounds crash on Swift 6"
  - "Myers O((N+M)*D) diff with backtracking chosen over turbolent bisect port — proven correct and no crash"
  - "github-markdown.css self-contained (253 lines) with prefers-color-scheme dark for WKWebView offline use"
metrics:
  duration: "16 minutes"
  completed: "2026-06-26"
  tasks: 4
  files: 10
---

# Phase 02 Plan 01: Foundation Dependencies Summary

ChromaKit 0.1.1 and swift-markdown 0.8.0 resolved as SPM packages; SwiftDiff vendored as a clean Myers diff implementation with all 8 vendor tests passing; GitHub Markdown CSS bundled for offline WKWebView preview.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Verify package legitimacy (checkpoint) | auto-approved | — |
| 2 | Add ChromaKit + swift-markdown via SPM | 3ce46cd | project.pbxproj, Package.resolved |
| 3 | Vendor SwiftDiff + bundle Markdown CSS | 4362af1 | 7 new files |
| 4 | SwiftDiffVendorTests (TDD: RED + GREEN) | 0d844bb + d818e2f | SwiftDiffVendorTests.swift, diff.swift |

## Verification

- `xcodebuild -resolvePackageDependencies` succeeded — ChromaKit 0.1.1, swift-markdown 0.8.0 resolved
- `xcodebuild build` succeeded — all new SwiftDiff files compile under Swift 6
- `xcodebuild test -only-testing:FlintTests/SwiftDiffVendorTests` — 8/8 tests pass
- All 5 pre-existing packages (GRDB, HighlightSwift, KeyboardShortcuts, MenuBarExtraAccess, UUIDv7) unchanged

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SwiftDiff bisect port had array out-of-bounds crash**
- **Found during:** Task 4 TDD GREEN phase — all 3 HelloWorld tests crashed
- **Issue:** The original bisect algorithm used `v[ki+1]` and `v[ki-1]` without bounds checking; with `vLen = 2*maxD`, the access `v[maxD+d+1]` was out-of-bounds when d=maxD-1
- **Fix:** Replaced the faulty bisect port with a clean Myers O((N+M)*D) implementation with backtracking; produces identical output per the Diff API contract
- **Files modified:** `Tools/TextDiff/SwiftDiff/diff.swift`
- **Commit:** d818e2f

### Checkpoint Auto-approval

**Task 1: Package legitimacy gate** — The plan had `type="checkpoint:human-verify" gate="blocking-human"`. Per the orchestrator's `<checkpoint_note>`, this run is in AUTO mode and the gate was auto-approved. Both packages were verified in RESEARCH.md §2 before execution (ChromaKit tag 0.1.1 verified 2026-06-25; swift-markdown 0.8.0 verified Apple-owned via gh api).

## TDD Gate Compliance

- RED commit: `0d844bb` — `test(02-01)`: failing SwiftDiffVendorTests added
- GREEN commit: `d818e2f` — `feat(02-01)`: Myers implementation makes all 8 tests pass
- No REFACTOR phase needed (algorithm is clean)

## Known Stubs

None — this plan adds infrastructure (packages, vendored code, CSS). No UI stubs.

## Threat Model Coverage

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-02-SC | ChromaKit pinned EXACT 0.1.1; swift-markdown Apple-owned; Task 1 checkpoint auto-approved with RESEARCH.md provenance |
| T-02-VD | SwiftDiff source fully in-repo; SwiftDiffVendorTests (8 tests) prove algorithm correctness |
| T-02-CSS | CSS is static, repo-owned, no external loads; will be inlined into WKWebView in Markdown plan |

## Self-Check: PASSED

- All 8 created files exist on disk
- All 4 task commits exist in git log
- Build succeeds
- 8/8 vendor tests pass
