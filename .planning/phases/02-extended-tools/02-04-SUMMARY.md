---
phase: 02-extended-tools
plan: 04
subsystem: markdown-previewer
tags: [markdown, gfm, wkwebview, swift-markdown, xss, tdd, export]
dependency_graph:
  requires: [02-01]
  provides: [MarkdownTransformer, WebPreviewView, MarkdownViewModel, MarkdownView, MarkdownDefinition]
  affects: [02-07-textdiff-registration, wave-7-toolregistry]
tech_stack:
  added: [WebKit (WKWebView), swift-markdown (Document+MarkupVisitor)]
  patterns: [AST-visitor-HTML, identical-HTML-guard, TDD-red-green, debounced-render]
key_files:
  created:
    - Tools/Markdown/MarkdownTransformer.swift
    - Tools/Markdown/MarkdownViewModel.swift
    - Tools/Markdown/MarkdownView.swift
    - Tools/Markdown/MarkdownDefinition.swift
    - UI/Components/WebPreviewView.swift
    - FlintTests/MarkdownTransformerTests.swift
  modified:
    - Flint.xcodeproj/project.pbxproj
decisions:
  - "HTMLVisitor escapes raw HTMLBlock/InlineHTML nodes — never passthrough raw user HTML (T-02-MD-XSS)"
  - "Toolbar insert actions append at end of source with newline; selection-aware insertion deferred (NSTextView binding limitation in NSViewRepresentable)"
  - "saveAsPDF creates a temporary WKWebView for export; coordinator.pendingPDFExport queued until navigation-finished fires"
  - "A1 auto-approved in AUTO mode: non-sandboxed v1, no network entitlement, loadHTMLString with baseURL:nil works on macOS 14 (verified by RESEARCH §5, Apple Dev Forums 116359/126381)"
metrics:
  duration: "~45 minutes"
  completed: "2026-06-26"
  tasks: 4
  files: 7
---

# Phase 02 Plan 04: Markdown Previewer Summary

swift-markdown AST→HTML transformer with full GFM (tables/task-lists/strikethrough/fenced-code), WKWebView preview component (JS-off, nav-blocked, identical-HTML guard, PDF export), debounced ViewModel, toggle/split View with formatting toolbar + word-count/reading-time footer + HTML/.html/.pdf export.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | MarkdownTransformerTests — failing tests | 1df4d0d | FlintTests/MarkdownTransformerTests.swift, stubs for 5 new files, project.pbxproj |
| 1 (GREEN) | MarkdownTransformer full implementation | 6bb563f | Tools/Markdown/MarkdownTransformer.swift |
| 2 | WebPreviewView (WKWebView NSViewRepresentable) | 888fdce | UI/Components/WebPreviewView.swift |
| 3 | Checkpoint A1 (auto-approved in AUTO mode) | — | — |
| 4 | MarkdownViewModel + MarkdownView + MarkdownDefinition | 2977a53 | Tools/Markdown/MarkdownViewModel.swift, MarkdownView.swift, MarkdownDefinition.swift |

## Verification

- `xcodebuild test -only-testing:FlintTests/MarkdownTransformerTests`: 27/27 tests pass
- `xcodebuild build`: BUILD SUCCEEDED
- Task 3 A1 checkpoint auto-approved (AUTO mode): non-sandboxed + baseURL:nil + no network entitlement

## Deviations from Plan

### Checkpoint Auto-approval

**Task 3: A1 WKWebView checkpoint** — Per orchestrator's `<checkpoint_note>`, this run is in AUTO mode. A1 verified programmatically: (1) CLAUDE.md confirms v1 is NOT sandboxed; (2) Flint-debug/release.entitlements verified — no network key (`grep network` returns 0); (3) RESEARCH §5 explicitly states non-sandboxed + baseURL:nil works without network entitlement; (4) Apple Developer Forums 116359/126381 cited in RESEARCH confirm the network entitlement requirement is sandbox-specific. Auto-approved with evidence documented here.

### Auto-fixed Issues

None — plan executed as written.

## TDD Gate Compliance

- RED commit: `1df4d0d` — `test(02-04)`: 27 failing MarkdownTransformerTests added
- GREEN commit: `6bb563f` — `feat(02-04)`: MarkdownTransformer implementation makes all 27 tests pass
- No REFACTOR phase needed (implementation was clean)

## Known Stubs

None — all plan objectives are fully implemented. The tool is not yet registered in ToolRegistry (per plan requirement: "NOT yet appended to ToolRegistry.tools" — registration is Wave-7).

## Threat Model Coverage

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-02-MD-XSS | HTMLVisitor: all text nodes HTML-escaped via htmlEscape(); raw HTMLBlock/InlineHTML also escaped; WKWebView JS disabled + nav blocked + baseURL:nil; CSS inlined (no remote loads) |
| T-02-MD-NET | No network entitlement added; loadHTMLString with baseURL:nil; auto-verified in Task 3 |
| T-02-MD-IV | 10 MB size guard in renderHTML(); wordCount/readingTimeMinutes are pure safe functions; no force-unwraps; tested with empty/huge/garbage inputs |

## Self-Check: PASSED

- All 6 created files exist on disk
- All 4 task commits exist in git log (1df4d0d, 6bb563f, 888fdce, 2977a53)
- 27/27 MarkdownTransformerTests pass
- BUILD SUCCEEDED
