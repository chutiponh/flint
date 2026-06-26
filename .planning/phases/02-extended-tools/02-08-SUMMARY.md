---
phase: 02-extended-tools
plan: 08
subsystem: markdown-editor-highlight
tags: [tdd, markdown, syntax-highlight, attribute-only, md-02]
dependency_graph:
  requires: ["02-04"]
  provides: ["MD-02-editor"]
  affects: ["UI/Components/SyntaxEditorView.swift", "Tools/Markdown/MarkdownView.swift"]
tech_stack:
  added: []
  patterns:
    - "Pure enum with nonisolated spans(in:) function returning [(NSRange, NSColor)]"
    - "NSTextStorage beginEditing/endEditing attribute-only pass (Pitfall #5 safe)"
    - "@MainActor Coordinator for NSTextViewDelegate AppKit main-thread safety"
    - "NSColor system colors for automatic Light/Dark/accent adaptation"
    - "Size guard at 2 MB to prevent O(n) regex scan on huge inputs"
key_files:
  created:
    - FlintTests/MarkdownEditorHighlightTests.swift
  modified:
    - UI/Components/SyntaxEditorView.swift
    - Tools/Markdown/MarkdownView.swift
    - Flint.xcodeproj/project.pbxproj
decisions:
  - "Pure enum MarkdownEditorHighlight with static spans(in:) keeps highlighter fully unit-testable without AppKit live objects"
  - "markdownHighlight: Bool = false flag on SyntaxEditorView keeps all non-Markdown editors untouched (Regex, Diff, JSON, Base64, etc.)"
  - "@MainActor on Coordinator eliminates Swift 6 actor-isolation warnings on NSTextView property accesses"
  - "applyHighlightDirect() in @MainActor Coordinator updates attributes immediately on textDidChange without a second async dispatch — reduces visual lag"
  - "Size guard at 2 MB (not 10 MB like MarkdownTransformer) because regex scan is O(n * patterns) whereas AST parse is O(n)"
metrics:
  duration: "6 minutes"
  completed: "2026-06-26T08:47:00Z"
  tasks: 2
  files: 4
---

# Phase 02 Plan 08: Markdown Editor Syntax Highlighting (MD-02 Gap Closure) Summary

**One-liner:** Attribute-only Markdown syntax highlight pass on NSTextStorage via MarkdownEditorHighlight.spans(in:) — opt-in flag preserves Regex/Diff editors, Pitfall #5 guard intact.

## What Was Built

Closed the MD-02 editor-side highlighting gap identified in 02-VERIFICATION.md. The Markdown editor (plain monospace SyntaxEditorView) now visually distinguishes Markdown syntax constructs as the user types:

| Construct | Pattern | Color |
|-----------|---------|-------|
| ATX heading markers | `^#{1,6}` | systemOrange |
| Bold text | `**…**` / `__…__` | systemBlue |
| Italic text | `*…*` / `_…_` | systemPurple |
| Inline code | `` `…` `` | systemTeal |
| Link syntax | `[text](url)` | secondaryLabelColor |

All colors use `NSColor` system semantics — they adapt automatically to Light mode, Dark mode, and accent color changes.

## Task Results

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 RED | Failing tests for MarkdownEditorHighlight | 111e1ea | FlintTests/MarkdownEditorHighlightTests.swift, project.pbxproj |
| 1 GREEN | MarkdownEditorHighlight + SyntaxEditorView markdownHighlight flag | 1bbee2b | UI/Components/SyntaxEditorView.swift |
| 2 | Wire markdownHighlight: true in MarkdownView editorPanel | 73dc2b6 | Tools/Markdown/MarkdownView.swift |

## Key Implementation Details

### Pitfall #5 Guard Preserved

The critical `guard textView.string != text else { return }` in `updateNSView` is intact. The highlight attribute pass runs **after** the string assignment, inside `applyMarkdownHighlight()`, which calls `textStorage.beginEditing()/.endEditing()` and only adds `.foregroundColor` + `.font` attributes — it never assigns `textView.string`. This cannot trip the re-render guard.

### No Infinite Reload Loop

When the user types:
1. `textDidChange` fires → `applyHighlightDirect()` applies attributes directly
2. Async dispatch updates the `@Binding var text`
3. SwiftUI calls `updateNSView` → guard sees `textView.string == text` → returns immediately
4. No second highlight pass triggered

### Opt-In Design

`markdownHighlight: Bool = false` default means all existing `SyntaxEditorView` call sites (9 total: JSON, Base64, URL, JWT, Hash, Regex, TextDiff ×2, plus Markdown) remain plain unless explicitly opted in. Only MarkdownView passes `markdownHighlight: true`.

## Verification

- `xcodebuild test -project Flint.xcodeproj -scheme Flint -destination 'platform=macOS' -only-testing:FlintTests/MarkdownEditorHighlightTests` → 22 tests passed, 0 failed
- Full suite: 374 tests passed, 0 failed — no regression to any existing editor
- Build: `BUILD SUCCEEDED` with no errors (Swift 6 actor-isolation warnings resolved via `@MainActor Coordinator`)

## Deviations from Plan

None — plan executed exactly as written.

The one structural decision worth noting: the `Coordinator` was annotated `@MainActor` to satisfy Swift 6 strict concurrency (NSTextView properties accessed from the delegate are always on main thread, but weren't formally annotated). This is a correctness improvement consistent with Rule 2 (missing isolation annotation), not a deviation.

## Known Stubs

None — the span function produces real attribute ranges from live text content. No hardcoded placeholders.

## Threat Flags

None — this change is attribute-only on NSTextStorage. No new network endpoints, auth paths, file access patterns, or schema changes are introduced. The regex patterns are compiled once per `spans(in:)` call; pathological regex catastrophic backtracking is not a concern because all patterns are fixed constructs with no user input in the pattern itself.

## TDD Gate Compliance

- RED gate: commit `111e1ea` — `test(02-08): add failing tests for MarkdownEditorHighlight (RED)`
- GREEN gate: commit `1bbee2b` — `feat(02-08): implement MarkdownEditorHighlight pure span function (GREEN)`

Both gates are present in correct order.

## Self-Check: PASSED

- [x] `FlintTests/MarkdownEditorHighlightTests.swift` exists
- [x] `UI/Components/SyntaxEditorView.swift` contains `markdownHighlight`
- [x] `Tools/Markdown/MarkdownView.swift` contains `markdownHighlight: true`
- [x] Commits 111e1ea, 1bbee2b, 73dc2b6 exist in git log
- [x] 374 tests pass, 0 fail
