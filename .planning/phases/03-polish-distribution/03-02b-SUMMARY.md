---
phase: 03-polish-distribution
plan: 02b
subsystem: ui-input
tags: [drag-and-drop, ondrop, file-drop, text-tools, overlay, warningbanner, dist-02]

# Dependency graph
requires:
  - phase: 03-polish-distribution
    plan: 02a
    provides: "View.fileDrop(isTargeted:onText:onError:) shared text-drop helper + DropOverlayView stateless overlay"
  - phase: 01-infrastructure-core-tools
    provides: "Per-tool ViewModels exposing input/token/source/testString + errorMessage; WarningBannerView"
provides:
  - "All 9 text-tool views carry .fileDrop + DropOverlayView — dropped UTF-8 text loads into each tool's primary input; binary/oversized files rejected post-drop via the shared handler"
  - "DIST-02 text-tool half complete: D-04 (open-tool-only routing into THAT tool's input) + D-06 (binary/oversized rejection via WarningBannerView, never a crash)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Each text tool applies the shared `.fileDrop(isTargeted:onText:onError:)` + `.overlay { if isDragTargeted { DropOverlayView(label: \"Drop to load\") } }` on the root of its *ContentView (where viewModel is in scope) — two-line mechanical slice, no new components"
    - "onText sets the tool's existing primary input (driving its didSet→transform): input/token/source/testString directly; NumberBase via update(from:.dec,text:) + field re-sync; Color via updateFromHex; TextDiff into primary/left (original)"
    - "onError routes to the tool's existing `errorMessage` (7 tools); for the 2 ViewModels with no errorMessage (Color, TextDiff) a view-local `@State var dropError: String?` renders a top-of-body WarningBannerView — the only sanctioned drop-error surface, no new UI struct"

key-files:
  created: []
  modified:
    - "Tools/JSONFormatter/JSONFormatterView.swift"
    - "Tools/JWT/JWTView.swift"
    - "Tools/URLEncoder/URLView.swift"
    - "Tools/Timestamp/TimestampView.swift"
    - "Tools/Markdown/MarkdownView.swift"
    - "Tools/NumberBase/NumberBaseView.swift"
    - "Tools/Regex/RegexView.swift"
    - "Tools/Color/ColorView.swift"
    - "Tools/TextDiff/TextDiffView.swift"

key-decisions:
  - "Modifier placed on each *ContentView root (after .toolShortcuts / .background), not the lazy outer wrapper — viewModel + input/error props are only in scope inside the content view; this matches the 03-PATTERNS placement guidance"
  - "Color and TextDiff ViewModels expose no errorMessage, so a view-local `dropError` @State drives a top-of-body WarningBannerView(severity: .warning) — reuses the existing sanctioned banner (already imported/used in both files), introduces no new component"
  - "TextDiff loads dropped text into its primary/left (Original) input per the plan; the right (Changed) input is left to manual entry — open-tool-only routing never yanks the user's existing work"
  - "NumberBase has no single text input field; the decimal value is its primary, so onText trims the dropped file and calls update(from: .dec, text:) then re-syncs the BIN/OCT/DEC/HEX fields. Color similarly trims + updateFromHex (its primary text format)"

patterns-established:
  - "Mechanical drop-wiring per text tool: `@State private var isDragTargeted = false` + `.fileDrop` + `.overlay { DropOverlayView(label:) }`, error to errorMessage or a view-local WarningBannerView"

requirements-completed: [DIST-02]

# Metrics
duration: 3 min
completed: 2026-06-26
---

# Phase 3 Plan 02b: Text-Tool Drag-and-Drop Wiring Summary

**The text-tool half of DIST-02: the shared `View.fileDrop` helper + `DropOverlayView("Drop to load")` applied to all 9 remaining text-tool views (JSONFormatter, JWT, URL, Timestamp, Markdown, NumberBase, Regex, Color, TextDiff), so each loads dropped UTF-8 text into its primary input (open-tool-only, D-04) and rejects binary/oversized files post-drop via WarningBannerView (D-06) — a purely mechanical two-line-per-view slice with zero new components.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-06-26T11:09:00Z
- **Completed:** 2026-06-26T11:11:30Z
- **Tasks:** 1 auto completed; 1 checkpoint (human-verify) deferred to batched manual pass per "code now, verify at end" mode
- **Files:** 9 modified (0 created)

## Accomplishments

- **Task 1** — Applied the shared `.fileDrop(isTargeted:onText:onError:)` (from 03-02a) plus a `DropOverlayView(label: "Drop to load")` overlay gated by a new `@State private var isDragTargeted = false` to the root of each of the 9 text-tool content views:
  - **Direct primary-input + existing errorMessage (7 tools):** JSONFormatter (`input`), JWT (`token`), URL (`input`), Timestamp (`input`), Markdown (`source`), Regex (`testString`), NumberBase (`update(from: .dec, text:)` + field re-sync) — all route `onError` to the tool's existing `viewModel.errorMessage` already rendered by InlineErrorView/WarningBannerView.
  - **No-errorMessage tools (2):** Color (`updateFromHex`) and TextDiff (`original`, the primary/left input) have ViewModels without an `errorMessage`; each gained a view-local `@State private var dropError: String?` rendered as a top-of-body `WarningBannerView(message: dropError, severity: .warning)` — the only sanctioned drop-error surface, no new UI struct.

## Task Commits

1. **Task 1: wire .fileDrop + DropOverlayView into 9 text-tool views** — `06dd64c` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

## Files Created/Modified

- `Tools/JSONFormatter/JSONFormatterView.swift` — **modified**. `isDragTargeted` state; `.fileDrop` (onText→`input`, onError→`errorMessage`) + overlay after `.toolShortcuts`.
- `Tools/JWT/JWTView.swift` — **modified**. onText→`token`, onError→`errorMessage`; overlay after `.toolShortcuts`. (HMAC secret handling untouched.)
- `Tools/URLEncoder/URLView.swift` — **modified**. onText→`input`, onError→`errorMessage`.
- `Tools/Timestamp/TimestampView.swift` — **modified**. onText→`input`, onError→`errorMessage` (single struct, no separate ContentView).
- `Tools/Markdown/MarkdownView.swift` — **modified**. onText→`source`, onError→`errorMessage`; placed after the GeometryReader `.background`.
- `Tools/NumberBase/NumberBaseView.swift` — **modified**. onText trims + `update(from: .dec, text:)` then `syncFieldsFromViewModel()`; onError→`errorMessage`.
- `Tools/Regex/RegexView.swift` — **modified**. onText→`testString`, onError→`errorMessage`.
- `Tools/Color/ColorView.swift` — **modified**. Added `dropError` @State + top-of-body WarningBannerView; onText trims + `updateFromHex`, onError→`dropError`.
- `Tools/TextDiff/TextDiffView.swift` — **modified**. Added `dropError` @State + top-of-body WarningBannerView; onText→`original` (primary/left), onError→`dropError`.

## Decisions Made

- **Modifier on *ContentView root, not the lazy wrapper:** the outer entry views build the ViewModel lazily on `.onAppear` and have no `viewModel`/input in scope; the `.fileDrop` + overlay must live on the inner content view. Matches 03-PATTERNS placement.
- **Reuse WarningBannerView for Color/TextDiff drop errors:** both files already import and use `WarningBannerView`, so a view-local `dropError` driving one is zero-new-surface and satisfies the "no new error-banner component" acceptance criterion.
- **TextDiff → primary/left (Original) only:** keeps the user's right-side text intact; open-tool-only routing never overwrites deliberate work.
- **NumberBase/Color text targets:** NumberBase has no free-text field, so the decimal value is its primary (drop trims + drives `update(from: .dec, …)`); Color's primary text format is hex (drop trims + `updateFromHex`).

## Deviations from Plan

None — plan executed exactly as written. The plan's `<action>` explicitly authorized the view-local `dropError` + `WarningBannerView` fallback for ViewModels lacking `errorMessage`; that path was used for exactly the two tools (Color, TextDiff) that need it.

**Total deviations:** 0.
**Impact on plan:** None — task `<verify>`, all `<acceptance_criteria>`, and the plan-level `<verification>` (source-side) pass.

## Issues Encountered

- **Headless full `xcodebuild -scheme Flint` still fails only on the pre-existing test-target error** (`FlintTests/PinnedToolReorderTests.swift: import XCTest — module 'XCTest' not resolvable`). This predates phase 03, is out of scope (SCOPE BOUNDARY), and is already logged in `deferred-items.md` by plan 03-01. **None of this plan's 9 modified files introduce new errors:** `swiftc -parse` is clean on all 9 + the shared helper, and every onText/onError target property was confirmed to exist on its ViewModel (`input`/`token`/`source`/`testString` are `var`; `errorMessage` is a settable `var` on the 7 tools that use it; `update(from:text:)` and `updateFromHex(_:)` signatures match the call sites).

## Verification Results

- Automated per-file loop (plan `<verify>`): **PASS** — all 9 views contain both `fileDrop` and `DropOverlayView`.
- `Core/Services/ToolRegistry.swift` unmodified (`git status` clean). **PASS**
- No new error-banner struct introduced (grep finds only `WarningBannerView`/`InlineErrorView` for drop errors). **PASS**
- `swiftc -parse` on the 9 views + FileDropHandler + DropOverlayView: **no syntax errors**.
- onText/onError target properties confirmed present + settable on every ViewModel.

## Deferred Manual Verification

Task 2 is a `checkpoint:human-verify` gate carried by this plan covering the **full DIST-02 drop surface** (03-02a binary tools/launcher + 03-02b text tools), deferred to the phase-end batched manual pass. A human must run Flint and confirm:

1. **Text tools load content:** Open JSON Formatter, drag a `.json` text file → overlay "Drop to load" appears during drag; on drop the contents populate the input and format. Repeat on ≥3 more text tools (e.g. JWT, Regex, Text Diff — TextDiff loads into its primary/left "Original" input) — content loads, overlay appears.
2. **Binary rejected on a text tool, no crash:** Drag an image/`.zip` onto JSON Formatter → a `WarningBannerView` ("non-text data… Try Base64 or Hash") appears AFTER the drop (post-drop rejection, per WARNING-5); the overlay stays the normal valid style during drag; no crash.
3. **Binary tools (no UI freeze on large files):** Open Hash, drag a large binary file → hashes off-main with progress (ProgressHashView), UI stays responsive, large-file path works (no size-cap regression). Open Base64, drag any file → encodes off-main without blocking.
4. **Launcher routing:** Open the launcher (root popover). Drag a text file containing a JWT → `detect()` routes to JWT Decoder pre-filled. Drag a text file with non-matching content → text staged in the search field. Drag a binary file → WarningBannerView rejection post-drop.
5. **Overlay animation:** Confirm the overlay fades in/out smoothly (easeOut 0.15).

**Resume signal:** "approved", or describe failures (overlay missing, UI froze on large file, wrong routing, crash on binary, a text tool not accepting drops).

## Known Stubs

None — every drop path is wired to a live ViewModel input/transform or the shared off-main handler. No placeholder/TODO/empty-data stubs introduced.

## Next Phase Readiness

- DIST-02 fully implemented across 03-02a (foundation + binary tools + launcher) and 03-02b (9 text tools), source-verified. All tools now accept dropped files: text tools load UTF-8 into their primary input with post-drop binary/oversized rejection; Base64/Hash accept any file off-main; the launcher routes via `detect()`.
- One gate remains: the end-to-end human-verify manual pass (deferred above) — the only outstanding item before DIST-02 can be marked fully validated.
- No blockers introduced. The pre-existing out-of-scope test-target build issue remains logged in `deferred-items.md`.

## Self-Check: PASSED

- All 9 modified view files exist on disk and contain `fileDrop` + `DropOverlayView` (per-file loop PASS).
- Task commit `06dd64c` present in git log; commit touches exactly the 9 view files with no deletions.
- ToolRegistry.swift unmodified; no new banner struct; `swiftc -parse` clean.

---
*Phase: 03-polish-distribution*
*Completed: 2026-06-26*
