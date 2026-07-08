---
phase: 07-keep-menubar-popover-open-after-color-picker-use-after-choos
plan: 01
subsystem: ui
tags: [swiftui, appkit, nscolorpanel, nscolorsampler, menubarextra, color]

requires:
  - phase: earlier color-tool + menubar phases
    provides: ClipboardDetector.isPopoverPresented lever, ColorView eyedropper + system ColorPicker
provides:
  - Eyedropper (NSColorSampler) completion re-presents the popover after applying the picked color
  - Falling-edge watchdog re-presents the popover while NSColorPanel is visible (D-04)
  - Paste-back dismiss closes the ColorPanel first so the watchdog does not fight an intentional dismiss
affects: [color, menubar, clipboard, paste-back]

tech-stack:
  added: []
  patterns:
    - "Falling-edge watchdog in a @Observable stored-property didSet, gated on external AppKit state (NSColorPanel.shared.isVisible)"

key-files:
  created: []
  modified:
    - Tools/Color/ColorView.swift
    - Core/Services/ClipboardDetector.swift

key-decisions:
  - "Re-present (D-03) is the delivery mechanism, not binding suppression — MenuBarExtraAccess force-closes on resign-key regardless of the binding value"
  - "Gate the watchdog strictly on NSColorPanel.shared.isVisible so a normal no-picker dismiss passes through untouched"
  - "Paste-back closes the panel first (flips isVisible false) rather than adding a separate paste-back-in-flight flag"

patterns-established:
  - "Watchdog on the falling edge: re-assert isPopoverPresented = true in the didSet else-branch when external picker state is still active"

requirements-completed:
  - "PHASE-07-GOAL: popover stays usable after eyedropper (NSColorSampler) or system ColorPicker (NSColorPanel) use — picked color lands in the Color tool and stays copyable"
  - CLR-02

duration: ~2min
completed: 2026-07-08
---

# Phase 07: Keep Menubar Popover Open After Color Picker Use — Summary

**Popover now survives both color pickers: the eyedropper re-presents it after a pick, and a falling-edge watchdog holds it open live for the whole NSColorPanel lifetime — while a normal no-picker dismiss and an intentional paste-back dismiss both still close it.**

## Performance

- **Duration:** ~2 min (executor auto-tasks) + manual UAT gate
- **Tasks:** 4 (3 auto + 1 human-verify checkpoint)
- **Files modified:** 2
- **Completed:** 2026-07-08

## Accomplishments
- Eyedropper (`NSColorSampler`) completion re-presents the popover after applying the picked color so the color lands in the Color tool and stays copyable.
- Falling-edge watchdog in `ClipboardDetector.isPopoverPresented`'s `didSet` re-presents the popover whenever it closes while `NSColorPanel.shared.isVisible == true` (D-04) — popover stays open live for the full panel lifetime, formats update as the color is adjusted.
- Paste-back dismiss closes the `NSColorPanel` first so the watchdog sees `isVisible == false` and lets the intentional dismiss proceed.

## Task Commits

1. **Task 1: Re-present popover after eyedropper pick** — `076a90d` (feat)
2. **Task 2: Falling-edge watchdog while NSColorPanel visible (D-04)** — `bae84f9` (feat)
3. **Task 2b: Paste-back dismiss closes ColorPanel before watchdog check** — `b381541` (fix)
4. **Task 3: Manual UAT checkpoint** — verification only, no commit (operator approved)

Worktree merge: `f39374b` (chore: merge executor worktree)

## Files Created/Modified
- `Tools/Color/ColorView.swift` — eyedropper completion re-present (+1 line); paste-back branch closes the ColorPanel before clearing the binding (+1 line + comment)
- `Core/Services/ClipboardDetector.swift` — falling-edge watchdog in the `isPopoverPresented` didSet else-branch, gated on `NSColorPanel.shared.isVisible` (+comment)

## Decisions Made
- None beyond the plan — executed exactly as written. The re-present mechanism (not binding suppression) was mandated by the plan's hard constraints because MenuBarExtraAccess force-closes on resign-key regardless of binding value.

## Deviations from Plan
None — plan executed exactly as written. 9-line diff across the two existing files, no new dependencies, no new files, no NotificationCenter observer/Timer added.

## Issues Encountered
None. All three automated grep verify gates passed; `xcodebuild ... build` succeeded twice (in-worktree and post-merge on `main`).

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Phase goal delivered and manually verified via UAT (operator approved). No blockers.
- Verification is manual-UAT-only by design (`nyquist_validation: false`) — no automated coverage possible for NSWindow key-status lifecycle.

---
*Phase: 07-keep-menubar-popover-open-after-color-picker-use-after-choos*
*Completed: 2026-07-08*
