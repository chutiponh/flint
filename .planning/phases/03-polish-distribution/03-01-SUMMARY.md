---
phase: 03-polish-distribution
plan: 01
subsystem: infra
tags: [macos-services, nsservices, info-plist, appdelegate, nsapplicationdelegateadaptor, activation-policy, tool-routing]

# Dependency graph
requires:
  - phase: 01-infrastructure-core-tools
    provides: ToolRegistry.detect(from:) + ToolSeed (FROZEN substrate), WindowCoordinator activation-policy dance, MenuBarExtra + MenuBarExtraAccess popover, PopoverNavigationState
provides:
  - "Single 'Open in Flint' macOS Services menu entry (D-01) routing selected text to the best-matched tool pre-filled (D-02) or the search-staged launcher on no match (D-03)"
  - "Manual Info.plist foundation (GENERATE_INFOPLIST_FILE=NO + INFOPLIST_FILE=Info.plist) that plan 03-04 extends with SUPublicEDKey/SUFeedURL"
  - "AppDelegate (NSApplicationDelegateAdaptor) registering the Services provider + refreshing the Services cache"
  - "FlintServiceProvider off-main pasteboard handler decoupled to FlintApp via NotificationCenter"
  - "WindowCoordinator.openToolViaService(toolId:) and openLauncherWithStagedText(_:) routing methods"
  - "Reserved Notification.Name .openOnboarding (consumed by plan 03-03)"
affects: [03-03-onboarding, 03-04-sparkle-distribution, 03-02-drag-and-drop]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Manual Info.plist for array-of-dict keys (NSServices) that cannot be scalar INFOPLIST_KEY_* build settings"
    - "Off-main NSObject @objc Services handler → NotificationCenter → @MainActor receiver (no global singletons added to FROZEN ToolRegistry/ToolSeed)"
    - "Services routing reuses the existing activation-policy dance verbatim for above-frontmost window presentation"

key-files:
  created:
    - "Info.plist"
    - "App/AppDelegate.swift"
    - "Core/Services/FlintServiceProvider.swift"
  modified:
    - "Flint.xcodeproj/project.pbxproj"
    - "App/WindowCoordinator.swift"
    - "App/FlintApp.swift"
    - "UI/MenuBarPopoverView.swift"

key-decisions:
  - "Use com.lathe. notification-name prefix (matches existing HotkeyManager convention) for serviceDidReceiveText/openOnboarding/routeServiceMatch/routeServiceNoMatch — not the lathe. examples shown in RESEARCH.md"
  - "Route popover navigation through two extra notifications (.routeServiceMatch / .routeServiceNoMatch) because navigationState/searchText are @State private to MenuBarPopoverView and cannot be set from FlintApp directly"
  - "Cap Services text at 1 MB (utf8.count) in openInFlint, dropping oversized input silently (T-03-02 DoS mitigation, mirrors clipboard guard)"
  - "Declare routeServiceMatch/routeServiceNoMatch in FlintServiceProvider.swift alongside serviceDidReceiveText (single Notification.Name extension for all Services-flow names)"

patterns-established:
  - "Manual Info.plist migration: move all six INFOPLIST_KEY_* scalars into the plist for the app target only; leave the test target on GENERATE_INFOPLIST_FILE=YES"
  - "NSMessage selector-name parity: Info.plist NSMessage == @objc func base name, asserted via PlistBuddy + grep"

requirements-completed: [DIST-01]

# Metrics
duration: 5min
completed: 2026-06-26
---

# Phase 3 Plan 01: macOS Services "Open in Flint" Routing Summary

**Single 'Open in Flint' Services entry that runs ToolRegistry.detect() on the selection and auto-opens the matched tool pre-filled via ToolSeed (or the search-staged launcher on no match), backed by a new manual Info.plist with an NSServices array.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-26T10:49:16Z
- **Completed:** 2026-06-26T10:54:33Z
- **Tasks:** 3 auto completed + 1 checkpoint:human-verify (deferred to phase-end batched verification)
- **Files modified:** 7 (3 created, 4 modified)

## Accomplishments
- Migrated the app target from a generated Info.plist to a manual `Info.plist` declaring the single "Open in Flint" `NSServices` entry (D-01), preserving all six prior `INFOPLIST_KEY_*` scalars.
- Added `AppDelegate` (via `@NSApplicationDelegateAdaptor`) that registers `FlintServiceProvider.shared` and calls `NSUpdateDynamicServices()` so the entry appears without a logout/login cycle during development (Pitfall #2).
- Added `FlintServiceProvider.openInFlint(_:userData:error:)` — reads pasteboard text off-main, caps it at 1 MB (T-03-02), and posts `.serviceDidReceiveText`; performs no seed/window call directly.
- Wired the detect → seed → activation-dance flow: `FlintApp` receives the notification on `@MainActor`, runs `toolRegistry.detect`, and routes to `WindowCoordinator.openToolViaService` (D-02) or `openLauncherWithStagedText` (D-03); `MenuBarPopoverView` consumes `.routeServiceMatch`/`.routeServiceNoMatch` to set navigation/search state.
- Left the FROZEN `ToolRegistry`/`ToolSeed` substrate completely untouched.

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate to manual Info.plist with NSServices** - `2572090` (feat)
2. **Task 2: AppDelegate + FlintServiceProvider (Services handler)** - `2fc0202` (feat)
3. **Task 3: WindowCoordinator routing + FlintApp wiring** - `1e97627` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

_Task 4 is a checkpoint:human-verify — no code; verification deferred per "code now, verify at the end" mode (see Deferred Manual Verification below)._

## Files Created/Modified
- `Info.plist` - **created**. Manual plist: standard bundle keys via build-setting vars, the six migrated `INFOPLIST_KEY_*` scalars (LSUIElement=true, developer-tools category, etc.), and the `NSServices` "Open in Flint" entry (NSMessage=openInFlint, NSPortName=Flint, NSSendTypes=public.plain-text).
- `App/AppDelegate.swift` - **created**. Registers the Services provider and refreshes the Services cache in `applicationDidFinishLaunching`.
- `Core/Services/FlintServiceProvider.swift` - **created**. `@objc openInFlint` off-main pasteboard handler with 1 MB cap; declares the four Services-flow `Notification.Name`s.
- `Flint.xcodeproj/project.pbxproj` - **modified**. App target Debug+Release: `GENERATE_INFOPLIST_FILE=NO`, `INFOPLIST_FILE=Info.plist`, six `INFOPLIST_KEY_*` removed; added file refs/build files/group/Sources entries for the two new Swift files and the Info.plist file ref.
- `App/WindowCoordinator.swift` - **modified**. Added `openToolViaService(toolId:)` and `openLauncherWithStagedText(_:)`, each copying `openWorkspace()`'s `.regular → activate → 0.1s delay → post .showPopover` dance.
- `App/FlintApp.swift` - **modified**. Added `@NSApplicationDelegateAdaptor(AppDelegate.self)` before the `@State` block and the `.onReceive(.serviceDidReceiveText)` detect/seed/route handler.
- `UI/MenuBarPopoverView.swift` - **modified**. Added `.onReceive(.routeServiceMatch)` (navigate to matched tool) and `.onReceive(.routeServiceNoMatch)` (stage text in search field) alongside the existing `.onReceive(.showPopover)`.

## Decisions Made
- Notification names use the existing `com.lathe.` prefix (HotkeyManager convention) rather than the `lathe.` prefix shown in RESEARCH.md examples, for consistency with the codebase.
- Popover navigation is driven by two additional notifications (`.routeServiceMatch`/`.routeServiceNoMatch`) because `navigationState`/`searchText` are `@State` private to `MenuBarPopoverView`; FlintApp cannot mutate them directly.
- All four Services-flow `Notification.Name`s are declared once in `FlintServiceProvider.swift`.

## Deviations from Plan

None - plan executed exactly as written.

The plan explicitly authorized declaring `.routeServiceMatch`/`.routeServiceNoMatch` in Task 3; they were placed in the FlintServiceProvider Notification.Name extension during Task 2 (the plan offered "or alongside" as an option), so all four names were committed together in Task 2. No functional deviation.

**Total deviations:** 0
**Impact on plan:** None — all acceptance criteria for Tasks 1–3 passed on first verification.

## Issues Encountered

- **Headless `xcodebuild` build cannot be used as a pass/fail gate in this environment.** A full `xcodebuild -scheme Flint` build fails on a pre-existing test-target error (`FlintTests/PinnedToolReorderTests.swift: import XCTest — "compilation search paths unable to resolve module dependency: 'XCTest'"`). That file was committed in `5a4632c` (project rename to Flint), before this plan's first commit, so it is out of scope (SCOPE BOUNDARY rule). None of the three new 03-01 source files produce compile errors under the scheme; the app target's own Swift sources compile, and the failure is isolated to the test bundle's XCTest module search path under CLI `xcodebuild`. A `-target Flint` build separately fails only because SPM package dependencies (GRDB, KeyboardShortcuts, MenuBarExtraAccess, HighlightSwift, ChromaKit, Markdown) resolve at the scheme/workspace level, not for a bare target build. Logged to `.planning/phases/03-polish-distribution/deferred-items.md`. Source-level acceptance criteria (grep/PlistBuddy/plutil) all pass; a clean GUI build is folded into the deferred manual-verification pass below.

## Deferred Manual Verification

Task 4 (`checkpoint:human-verify`, gate=blocking) was NOT blocked on — per "code now, verify at the end" the code is written and committed, and the verification steps are recorded here for the single batched phase-end manual pass.

**What was built:** A manual Info.plist declaring the "Open in Flint" Services entry, an AppDelegate that registers `FlintServiceProvider` and refreshes the Services cache, and the detect → seed → activation-dance routing across WindowCoordinator / FlintApp / MenuBarPopoverView.

**How to verify (human, in Xcode + real apps):**
1. Build and run Flint from Xcode (Product → Run). Confirm the menubar wrench icon appears and the app cold-starts normally. (This also clears the pre-existing CLI-only XCTest build noise — confirm the GUI build of the **Flint app scheme** succeeds.)
2. In TextEdit (or Safari), type/paste a JSON string like `{"a":1}`. Select it.
3. Right-click the selection → Services → confirm "Open in Flint" appears, then click it.
4. EXPECTED: Flint opens (above TextEdit) directly into the JSON Formatter, pre-filled with `{"a":1}` — no detection banner, no confirm step (D-02).
5. Repeat with a JWT string and a Base64 blob — each opens its matched tool pre-filled.
6. Select a non-matching string like `just some words here` and invoke "Open in Flint". EXPECTED: the launcher opens with the text staged in the search field (D-03), not an error/dead end.
7. Confirm in every case the Flint window appears IN FRONT of the source app (activation dance, Pitfall #3).

**Resume signal (for the batched pass):** "approved", or describe what failed (entry missing, opened behind, wrong tool, no pre-fill).

## User Setup Required

None - no external service configuration required for this plan. (create-dmg / Sparkle / Developer ID setup belong to plans 03-04/03-05.)

## Next Phase Readiness
- DIST-01 source implementation complete and source-verified; functional verification deferred to the phase-end batched manual pass.
- The manual `Info.plist` foundation is in place for plan 03-04 to add `SUPublicEDKey`/`SUFeedURL`.
- `.openOnboarding` Notification.Name is reserved and ready for plan 03-03.
- No blockers introduced. One pre-existing, out-of-scope test-target build issue is logged in deferred-items.md.

## Self-Check: PASSED

- Created files verified on disk: `Info.plist`, `App/AppDelegate.swift`, `Core/Services/FlintServiceProvider.swift`.
- Task commits verified in git log: `2572090`, `2fc0202`, `1e97627`.

---
*Phase: 03-polish-distribution*
*Completed: 2026-06-26*
