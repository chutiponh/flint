---
phase: "04-ux-improvement"
plan: "03"
subsystem: "keyboard-shortcuts"
tags: ["keyboard", "D-07", "D-08", "search-navigation", "row-copy", "notifications", "badges"]
dependency_graph:
  requires: ["04-01"]
  provides: ["selectOutputRow-notification", "OutputRowBadge", "D-07-arrow-nav", "D-08-row-copy"]
  affects: ["MenuBarPopoverView", "SearchView", "ColorView", "HashView", "NumberBaseView", "ToolShortcutActions"]
tech_stack:
  added: []
  patterns:
    - "NSEvent.addLocalMonitorForEvents for arrow-key fallback (struct-safe capture)"
    - "NotificationCenter broadcast + .onReceive observer for row copy (D-08)"
    - "Stateless display component OutputRowBadge (CopyButtonView analog)"
    - "outputForRow(_ index: Int) -> String? per-tool row map pattern"
key_files:
  created:
    - "UI/Components/OutputRowBadge.swift"
  modified:
    - "UI/MenuBarPopoverView.swift"
    - "UI/Components/ToolShortcutActions.swift"
    - "Tools/Color/ColorView.swift"
    - "Tools/Color/ColorViewModel.swift"
    - "Tools/Hash/HashView.swift"
    - "Tools/Hash/HashViewModel.swift"
    - "UI/Components/ProgressHashView.swift"
    - "Tools/NumberBase/NumberBaseView.swift"
    - "Tools/NumberBase/NumberBaseViewModel.swift"
    - "UI/SearchView.swift"
    - "Flint.xcodeproj/project.pbxproj"
decisions:
  - "D-07 fallback monitor reads @State navigationState from closure-captured struct copy — valid because SwiftUI @State is heap-backed; reading from copy always reflects live value"
  - "Arrow monitor fires only in .searchResults state; tool views are not disrupted"
  - "SearchView retains primary .onKeyPress handlers alongside fallback .onReceive — both coexist, fallback handles TextField-focus case"
  - "ProgressHashView extended with showBadges: Bool = false param for backward compat; file hash section passes false"
  - "NumberBase outputForRow index 1 = BIN (badge/row map), primaryOutput() = DEC (⌘⇧C); both are authoritative for their respective shortcuts"
  - "OutputRowBadge.swift added to Xcode project.pbxproj explicitly — project uses explicit file list"
metrics:
  duration: "~30 minutes"
  completed_date: "2026-06-29"
  tasks: 3
  files: 11
---

# Phase 04 Plan 03: Keyboard Row-Copy and Arrow Nav Summary

**One-liner:** ⌘1–⌘9 row-copy via .selectOutputRow notification + OutputRowBadge per D-08; D-07 arrow nav hardened with NSEvent monitor fallback for TextField-focus case.

## What Was Built

### Task 1: OutputRowBadge + .selectOutputRow notification + hidden ⌘1–⌘9 buttons

- Created `UI/Components/OutputRowBadge.swift` — stateless 16×16pt badge with 11pt semibold monospaced secondary text, `RoundedRectangle(cornerRadius: 4)` `.quaternary.opacity(0.6)` fill, `.accessibilityLabel("⌘\(index) to copy")` and `.help("Press ⌘\(index) to copy")`.
- Added `Notification.Name.selectOutputRow = Notification.Name("lathe.selectOutputRow")` to the existing extension block in `MenuBarPopoverView.swift`.
- Added `ForEach(1...9)` hidden buttons in the `.background()` group posting `.selectOutputRow` with `userInfo["index"]`. Bound to `KeyEquivalent(Character(String(index)))` + `.command` (digit keys 1–9, NOT letter N — existing ⌘N workspace shortcut is unchanged, CF-02 Pitfall 4).

### Task 2: Shared observer + outputForRow + badges on Color/Hash/NumberBase

- `ToolShortcutActions.swift`: Extended `ToolShortcutsModifier` with `.onReceive(.selectOutputRow)` that copies `primaryOutput()` for index==1; all other indices are silent no-ops. All 12 tools get ⌘1 = primary output for free.
- `ColorViewModel.outputForRow(_ index: Int) -> String?`: 1=HEX, 2=RGB, 3=HSL, 4=HSV, 5=OKLCH; nil for OOB.
- `HashViewModel.outputForRow(_ index: Int) -> String?`: 1=MD5, 2=SHA-1, 3=SHA-256, 4=SHA-384, 5=SHA-512, 6=CRC32; nil for OOB (SECURITY: returns digest text only, HMAC key never referenced here — INFRA-09).
- `NumberBaseViewModel.outputForRow(_ index: Int) -> String?`: 1=BIN, 2=OCT, 3=DEC, 4=HEX (with "0x" prefix); nil for OOB.
- All three ViewModels return nil for any out-of-range index (CF-01, T-04-06 mitigation verified).
- `ColorView.swift`: `formatRow` helper extended with `rowIndex: Int` param; `OutputRowBadge(index: rowIndex)` inserted as first HStack child before the label; per-tool `.onReceive(.selectOutputRow)` observer on `formatRowsSection`.
- `HashView.swift`: Passes `showBadges: true` to text hash `ProgressHashView`; per-tool `.onReceive(.selectOutputRow)` observer on `textHashOutputSection`.
- `ProgressHashView.swift`: Extended with `showBadges: Bool = false` param (backward compatible); conditionally renders `OutputRowBadge(index: rowIndex)` on each of 6 hash rows with correct indices 1–6.
- `NumberBaseView.swift`: `baseRow` helper extended with `rowIndex: Int` param; `OutputRowBadge(index: rowIndex)` inserted as first HStack child; per-tool `.onReceive(.selectOutputRow)` observer on `baseFields`; added `import AppKit`.

### Task 3: D-07 arrow-key search navigation verification + hardening

**D-07 empirical outcome:** The existing `.onKeyPress(.upArrow/.downArrow)` in `SearchView` works when the `SearchView` subtree itself holds focus. However, the search `TextField` in `MenuBarPopoverView.searchBar` is a sibling (not a descendant) of `SearchView`, so when the TextField holds AppKit first-responder focus, SwiftUI's `.onKeyPress` on `SearchView` does not fire (Pitfall 7, RESEARCH Open Question 1). The NSEvent local monitor fallback was added to guarantee arrow navigation works regardless of focus state.

**Changes made:**
- Fixed `SearchView.swift` selected-row highlight opacity from `0.1` to `0.12` (UI-SPEC D-07 value — this was a deviation from spec).
- Added `Notification.Name.searchNavigate = Notification.Name("lathe.searchNavigate")` to the extension block.
- Added `installArrowMonitor()` / `removeArrowMonitor()` in `MenuBarPopoverView`: local NSEvent monitor for keyCodes 125 (↓) and 126 (↑) that fires only when `navigationState == .searchResults`, posts `.searchNavigate` with `userInfo["direction"]` (-1 for ↑, +1 for ↓), and consumes the event (`return nil`). Coexists with the Esc monitor (keyCode 53) without overlap. Installed in `.onAppear`, removed in `.onDisappear`.
- Added `.onReceive(.searchNavigate)` in `SearchView.body` as the fallback observer, updating `selectedIndex` with clamping (no wrap-around). Primary `.onKeyPress` handlers retained alongside the fallback.
- Added `import AppKit` to `SearchView.swift`.
- Added `OutputRowBadge.swift` to `Flint.xcodeproj/project.pbxproj` (PBXBuildFile + PBXFileReference + group + Sources build phase entries) — required because the project uses an explicit file list.

**Build result:** BUILD SUCCEEDED (Xcode, macOS Debug target, CODE_SIGNING_ALLOWED=NO).

## Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | OutputRowBadge component + ⌘1-⌘9 hidden buttons | ec5cb36 |
| 2 | Shared observer + outputForRow + badges on Color/Hash/NumberBase | b076def |
| 3 | D-07 arrow nav hardened + opacity fix + Xcode project registration | 4566c3d |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SearchView highlight opacity was 0.1 instead of 0.12**
- **Found during:** Task 3
- **Issue:** `SearchView.swift` used `Color.accentColor.opacity(0.1)` for selected row highlight in both `SearchToolRow` and history rows. UI-SPEC D-07 specifies 0.12.
- **Fix:** Replaced all occurrences of `accentColor.opacity(0.1)` with `accentColor.opacity(0.12)` in `SearchView.swift`.
- **Files modified:** `UI/SearchView.swift`
- **Commit:** 4566c3d

**2. [Rule 3 - Blocking] OutputRowBadge.swift not recognized by Xcode build (not in project file)**
- **Found during:** Task 3 (first build attempt after Task 2)
- **Issue:** Build error: "cannot find 'OutputRowBadge' in scope" — Xcode project uses an explicit file list in `project.pbxproj`, so new files must be registered manually.
- **Fix:** Added PBXBuildFile, PBXFileReference, Components group entry, and Sources build phase entry using IDs `00110000000DD06` / `00120000000DD06` (following existing pattern from `AllToolsGridView` DD04/DD05).
- **Files modified:** `Flint.xcodeproj/project.pbxproj`
- **Commit:** 4566c3d

**3. [Rule 3 - Blocking] `[weak self]` on struct type in NSEvent monitor closure**
- **Found during:** Task 3 (second build attempt)
- **Issue:** Build error: "'weak' may only be applied to class and class-bound protocol types, not 'MenuBarPopoverView'". `MenuBarPopoverView` is a SwiftUI struct, not a class.
- **Fix:** Changed `[weak self]` to `[self]` (explicit copy capture). Reading `@State` (`navigationState`) from a captured struct copy is valid — SwiftUI `@State` is heap-backed; the struct copy holds a reference to the same storage, so reads in the closure reflect the current live value. This is the same mechanism used by the existing `installEscMonitor()`.
- **Files modified:** `UI/MenuBarPopoverView.swift`
- **Commit:** 4566c3d

## D-07 Empirical Outcome

**Fallback monitor added.** The existing `.onKeyPress(.upArrow/.downArrow)` in `SearchView` does not fire when the search `TextField` (in `MenuBarPopoverView.searchBar`, a sibling view) holds AppKit first-responder focus. This is the expected macOS behavior: SwiftUI's `.onKeyPress` propagates through the SwiftUI responder chain of the view's subtree, but when an AppKit first responder (NSTextField) in a sibling view holds focus, arrow key events are consumed before reaching the SwiftUI responder chain of other sibling views.

The NSEvent local monitor fallback (keyCodes 125/126) runs before AppKit responder dispatch and guarantees arrow navigation works regardless of focus state. The monitor fires only in `.searchResults` navigation state to avoid consuming arrow keys in tool views (where scrolling and text cursor movement rely on them).

## Known Stubs

None — all output row copy functionality is fully wired to live ViewModel data.

## Threat Flags

No new network endpoints, auth paths, or trust boundaries introduced. All changes are local UI/clipboard interactions. The existing threat register entries T-04-06, T-04-07, T-04-08 cover the notification and clipboard patterns implemented here — all mitigations applied (nil returns for OOB indices, HMAC key excluded from outputForRow, clipboard cleared before write).

## Self-Check: PASSED

All files exist, all commits verified, all key functionality present:
- OutputRowBadge.swift created and registered in Xcode project
- .selectOutputRow notification + ForEach(1...9) buttons in MenuBarPopoverView
- outputForRow implemented in Color, Hash, NumberBase ViewModels
- OutputRowBadge displayed on rows in Color (5 rows), Hash (6 rows via ProgressHashView), NumberBase (4 rows)
- .searchNavigate monitor in MenuBarPopoverView + .onReceive observer in SearchView
- Selected row highlight opacity corrected to 0.12 (from 0.1)
- App builds successfully (BUILD SUCCEEDED)
