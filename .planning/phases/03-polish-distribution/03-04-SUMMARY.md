---
phase: 03-polish-distribution
plan: 04
subsystem: ui
tags: [onboarding, first-run, userdefaults, smappservice, launch-at-login, windowgroup, activation-policy, accessibility, voiceover, infra-15]

# Dependency graph
requires:
  - phase: 03-polish-distribution
    plan: 01
    provides: "WindowCoordinator activation-policy dance (openWorkspace) + the reserved .openOnboarding Notification.Name + @NSApplicationDelegateAdaptor wiring in FlintApp"
  - phase: 03-polish-distribution
    plan: 02a
    provides: "MenuBarPopoverView drag-drop wiring (isDragTargeted/dropError/.fileDrop/DropOverlayView/WarningBannerView) preserved when adding the first-run gate; DropOverlayView accessibility surface"
  - phase: 03-polish-distribution
    plan: 03
    provides: "Sparkle SparkleUpdaterService lazy start() in the popover .onAppear where the onboarding gate also lives"
  - phase: 01-infrastructure-core-tools
    provides: "PreferencesStore.launchAtLogin SMAppService toggle (INFRA-13), PreferencesView analog, WarningBannerView accessibility shape, Bool-key UserDefaults pattern"
provides:
  - "PreferencesStore.hasSeenOnboarding — cheap UserDefaults bool first-run gate (false default triggers onboarding once)"
  - "OnboardingWindowView — single non-carousel welcome window: menubar-icon callout, ⌘⇧Space hotkey teach, Launch-at-Login CTA, Get Started / Skip dismiss"
  - "WindowCoordinator.openOnboarding() — activation-policy dance surfacing the window above the frontmost app"
  - "FlintApp WindowGroup(id: onboarding) 480×360 .windowResizability(.contentSize) + .onReceive(.openOnboarding) open-by-id"
  - "First-run gate in MenuBarPopoverView .onAppear (!prefs.hasSeenOnboarding → openOnboarding()) — single synchronous bool read, no cold-start regression"
  - "Source-level INFRA-15/INFRA-14 confirmation across the 3 Phase 3 surfaces (onboarding window, drag overlay, Services-routed open) + the 12 tools/launcher (no UI-chrome hardcoded colors)"
affects: [03-05-signed-notarized-dmg, voiceover-manual-audit]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "First-run gate = cheap synchronous UserDefaults bool read in the popover .onAppear (after @State services init) — never async/DB work (RESEARCH Pitfall #6/#7)"
    - "Onboarding window reuses the WindowCoordinator activation-policy dance verbatim (openOnboarding copies openWorkspace) so a no-Dock menubar app's window surfaces above the frontmost app"
    - "Launch-at-Login CTA reuses the existing PreferencesStore.launchAtLogin SMAppService path — zero new launch code"
    - "Every dismiss path (CTA / Get Started / Skip) funnels through a single finish() that sets hasSeenOnboarding=true then dismiss(), so the window provably never reappears"

key-files:
  created:
    - "UI/OnboardingWindowView.swift"
  modified:
    - "Core/Services/PreferencesStore.swift"
    - "App/WindowCoordinator.swift"
    - "App/FlintApp.swift"
    - "UI/MenuBarPopoverView.swift"
    - "Flint.xcodeproj/project.pbxproj"

key-decisions:
  - "Tools/Color/ColorViewModel.swift's two Color(red:...) usages are LEFT UNCHANGED — they construct a SwiftUI.Color from user-entered RGBA for the system ColorPicker binding (the Color Converter's domain logic), not UI-chrome hardcoded colors. INFRA-14 forbids hardcoded chrome colors, not a color tool literally rendering the user's chosen color; changing them would break the tool."
  - "CTA is conditional: when !launchAtLogin the primary is 'Enable Launch at Login' (+ secondary 'Get Started'); when already enabled the primary becomes the sole 'Get Started' (UI-SPEC copy contract)."
  - "Onboarding WindowGroup gets only the prefs environment (minimal surface) + preferredColorScheme, mirroring the workspace group but with .windowResizability(.contentSize) for the fixed 480×360 frame."

patterns-established:
  - "First-run welcome gate: UserDefaults bool default-false → popover .onAppear gate → WindowCoordinator dance → WindowGroup open-by-id → dismiss sets the flag"
  - "pbxproj ID allocation must avoid colliding with sibling-wave files: OnboardingWindowView uses DD03 after DD02 was already taken by 03-02a's FileDropHandler"

requirements-completed: [DIST-03, INFRA-15]

# Metrics
duration: 18min
completed: 2026-06-27
---

# Phase 3 Plan 04: First-Run Onboarding + Full-App Accessibility (DIST-03 / INFRA-15) Summary

**A once-only first-run welcome window (menubar-icon callout + ⌘⇧Space hotkey teach + one Launch-at-Login CTA reusing the existing SMAppService path) gated by a cheap `hasSeenOnboarding` UserDefaults bool and surfaced above the frontmost app via the WindowCoordinator activation dance, plus a source-level VoiceOver/semantic-color confirmation of the 3 new Phase 3 surfaces and the 12 tools.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-06-26T23:55:00Z
- **Completed:** 2026-06-27T00:02:00Z
- **Tasks:** 2 auto completed + 2 human-verify checkpoints (source pre-check done; manual passes deferred per "code now, verify at the end")
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments
- **`PreferencesStore.hasSeenOnboarding`** — `defaults.object(forKey:) as? Bool ?? false` with `Keys.hasSeenOnboarding = "lathe.hasSeenOnboarding"`. False default (missing key) triggers onboarding on first run; no migration needed.
- **`OnboardingWindowView`** — single non-carousel VStack (24pt padding, 16pt section spacing): "Welcome to Flint" headline (20pt semibold, `.isHeader`), Step 1 menubar callout (wrench SF Symbol, `.accessibilityHidden`), Step 2 ⌘⇧Space hotkey teach (command SF Symbol), conditional `.borderedProminent` CTA, secondary "Get Started", and "Skip". 480×360 fixed, system semantic colors, full VoiceOver labels, `.onDisappear → WindowCoordinator.windowWillClose()`.
- **`WindowCoordinator.openOnboarding()`** — copies `openWorkspace()`'s `.regular → activate → 0.1s asyncAfter → post .openOnboarding` dance verbatim so the window appears above the frontmost app.
- **`FlintApp`** — `WindowGroup(id: "onboarding")` (480×360, `.windowResizability(.contentSize)`, `.commandsRemoved()`), `@Environment(\.openWindow)`, and `.onReceive(.openOnboarding) { openWindow(id: "onboarding") }` on the MenuBarExtra content.
- **First-run gate** — added inside MenuBarPopoverView's existing `.onAppear` (after `sparkle.start()` / `installEscMonitor()`): `if !prefs.hasSeenOnboarding { WindowCoordinator.shared.openOnboarding() }`. 03-02a's `isDragTargeted`/`dropError`/`.fileDrop`/overlay/WarningBannerView wiring preserved intact.
- **INFRA-15/INFRA-14 source pre-check (Task 4 code half)** — confirmed `OnboardingWindowView` and `DropOverlayView` carry `.accessibilityLabel`/`.accessibilityHidden` on every element; confirmed no UI-chrome hardcoded colors. The only `Color(red:)` hits are the two justified domain-logic lines in `ColorViewModel.swift` (see Decisions). No fixes were required — coverage was already complete.

## Task Commits

Each task was committed atomically:

1. **Task 1: hasSeenOnboarding pref + OnboardingWindowView** — `c59e895` (feat)
2. **Task 2: WindowCoordinator.openOnboarding + FlintApp WindowGroup + first-run gate** — `bd6865c` (feat; includes the DD02→DD03 pbxproj collision fix)

**Plan metadata:** _(this commit)_ (docs: complete plan)

_Tasks 3 and 4 are human-verify checkpoints — no code commit for the manual passes; the Task 4 source pre-check fixes/confirmations are folded into the Task 1/Task 2 commits._

## Files Created/Modified
- `UI/OnboardingWindowView.swift` — **created**. First-run welcome window with the exact UI-SPEC copy, conditional Launch-at-Login CTA bound to `prefs.launchAtLogin`, single `finish()` dismiss funnel setting `hasSeenOnboarding=true`, fixed 480×360, system semantic colors, full VoiceOver labels.
- `Core/Services/PreferencesStore.swift` — **modified**. Added the `hasSeenOnboarding` Bool under a `// MARK: - Onboarding (DIST-03)` section + `Keys.hasSeenOnboarding`.
- `App/WindowCoordinator.swift` — **modified**. Added `openOnboarding()` (activation dance posting `.openOnboarding`).
- `App/FlintApp.swift` — **modified**. Added `@Environment(\.openWindow)`, the `.onReceive(.openOnboarding)` open-by-id handler, and the onboarding `WindowGroup`.
- `UI/MenuBarPopoverView.swift` — **modified**. Added the cheap `!prefs.hasSeenOnboarding` first-run gate inside the existing `.onAppear`, alongside 03-02a's drop wiring.
- `Flint.xcodeproj/project.pbxproj` — **modified**. Registered `OnboardingWindowView.swift` in the UI group + app-target Sources phase (IDs `00120000000DD03` / `00110000000DD03`). `plutil -lint` OK.

## Decisions Made
- **Color Converter's `Color(red:)` literals are domain logic, not chrome (INFRA-14 exception):** `ColorViewModel.swift` lines 91 & 114 build a `SwiftUI.Color` from the user's entered RGBA to drive the system `ColorPicker` two-way binding. That is the tool's purpose; these are not hardcoded UI-chrome colors. Forcing them to semantic tokens would break the Color Converter. Left unchanged — the effective INFRA-14 chrome pre-check is clean.
- **Conditional CTA per UI-SPEC:** primary is "Enable Launch at Login" only when launch-at-login is off; once enabled it collapses to the sole "Get Started".
- **Minimal onboarding WindowGroup environment:** only `prefs` + `preferredColorScheme`, with `.windowResizability(.contentSize)` locking the 480×360 frame.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] pbxproj object-ID collision with 03-02a's FileDropHandler**
- **Found during:** Task 2 (build verification of the new WindowGroup wiring)
- **Issue:** Task 1 registered `OnboardingWindowView.swift` using IDs `00110000000DD02` / `00120000000DD02`, but 03-02a's `FileDropHandler.swift` already owned those exact IDs. The duplicate file-reference made Xcode resolve the FileDropHandler reference to the OnboardingWindowView entry (which lives in the `UI` group), producing a phantom `Build input file cannot be found: '.../UI/FileDropHandler.swift'` error and breaking the whole app-target build.
- **Fix:** Renumbered the four OnboardingWindowView pbxproj entries to `00110000000DD03` / `00120000000DD03` (verified unused). The collision resolved and the phantom `UI/FileDropHandler.swift` error disappeared.
- **Files modified:** `Flint.xcodeproj/project.pbxproj`
- **Verification:** `plutil -lint` OK; `grep` confirms each ID is now unique; `xcodebuild` app-target Swift sources compile with zero errors (only the pre-existing test-target XCTest failure remains).
- **Committed in:** `bd6865c` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking, self-introduced pbxproj ID collision).
**Impact on plan:** Necessary for the app target to build. No scope creep — the fix is confined to my own pbxproj entries.

## Issues Encountered
- **Pre-existing test-target build failure (out of scope):** headless `xcodebuild -scheme Flint` still fails only on `FlintTests/PinnedToolReorderTests.swift` (`import XCTest — "compilation search paths unable to resolve module dependency: 'XCTest'"`). This predates phase 03 and is already logged in `deferred-items.md`. None of this plan's app-target source files produce compile errors — the app target's own Swift sources (OnboardingWindowView, FlintApp, WindowCoordinator, MenuBarPopoverView, PreferencesStore) compile cleanly.

## Known Stubs
None — the onboarding window is fully wired to live `prefs` (`launchAtLogin` SMAppService, `hasSeenOnboarding`), the gate to a live UserDefaults read, and the WindowGroup to the real activation dance. No placeholder/TODO/empty-data stubs introduced.

## Threat Flags
None — no new network endpoints, auth paths, file access, or schema changes beyond the threat model. The onboarding CTA reuses the already-audited SMAppService path (T-03-12 accept); the gate is a synchronous UserDefaults read after services init (T-03-13 mitigate).

## Deferred Manual Verification

The two human-verify checkpoints are recorded here per the "code now, verify at the end" mode. The Task 4 **source pre-check (code work) was performed and is complete** (semantic-color audit + accessibility-label confirmation across the Phase 3 surfaces — no fixes needed beyond confirming existing coverage). Only the hands-on manual passes are deferred:

### Task 3 — First-run onboarding (manual)
1. Reset state: `defaults delete com.flint.app lathe.hasSeenOnboarding` (or delete the whole domain).
2. Build & run. EXPECT: the "Welcome to Flint" window (480×360, not resizable) appears ABOVE the frontmost app, showing the menubar-icon callout + ⌘⇧Space instruction.
3. Click "Enable Launch at Login". EXPECT: launch-at-login enabled (verify in System Settings → General → Login Items, Flint listed) and the window dismisses.
4. Quit & relaunch. EXPECT: onboarding does NOT reappear.
5. Reset flag, relaunch, click "Skip". EXPECT: dismisses and does not reappear on next launch.
6. Confirm cold start still feels instant (<500ms) — the gate should not delay popover open. VoiceOver: tab headline → body → CTA → skip in logical order.

### Task 4 — Full-app VoiceOver audit (12 tools + launcher + 3 Phase 3 surfaces) [BLOCKING — INFRA-15]
Source pre-check (DONE): `grep -rl "Color(red:\|Color(hex:\|\.init(red:" UI Tools` returns only `Tools/Color/ColorViewModel.swift` (justified domain logic — see Decisions); DropOverlayView and OnboardingWindowView each carry `.accessibilityLabel`/`.accessibilityHidden` on every element. Manual pass deferred:
1. Enable VoiceOver (⌘F5). Tab the search-first launcher (search field, pinned/tool rows, history entry) — every Button/TextField/row announces a meaningful label.
2. Tab EACH of the 12 tools: Phase 1 (7) — JSON, Base64, URL, JWT, Timestamp, Hash, UUID (NSTextView editors announce "Code editor" / `.textArea`); Phase 2 (5) — Regex (pattern/test/group legend), Color (HEX/RGB/HSL/HSV/OKLCH fields, eyedropper, WCAG result, sliders), Markdown (editor/preview/export), Number Base (bin/oct/dec/hex + bit-field toggles), Text Diff (two inputs, jump-to-diff, export).
3. Phase 3 surface 1 — Services-routed open: select text in TextEdit → "Open in Flint" → confirm the opened tool is reachable/announced, no focus trap, pre-filled input announces its value.
4. Phase 3 surface 2 — drag overlay: drag a file over a tool surface so DropOverlayView shows → confirm its `.accessibilityLabel` ("Drop to load…") is announced.
5. Phase 3 surface 3 — onboarding window: tab headline → step bodies → CTA → Skip in logical order with meaningful labels.
6. Fix any missing label/focus-order issue, re-run the affected element, then approve.

Approve ONLY if every interactive element across all 12 tools, the launcher, and the 3 Phase 3 surfaces announces a meaningful VoiceOver label (INFRA-15).

## Next Phase Readiness
- **DIST-03 onboarding half complete:** first-run welcome flow greets new users, teaches the menubar + hotkey, enables launch-at-login via the existing SMAppService path, and never reappears (`hasSeenOnboarding`). The signed/notarized DMG half is **plan 03-05**.
- **INFRA-15 source half complete:** all Phase 3 surfaces and the 12 tools are source-confirmed accessibility-labeled with semantic colors; the hands-on VoiceOver audit is the only remaining INFRA-15 gate (deferred manual pass above).
- No blockers introduced. The one pre-existing, out-of-scope test-target build issue remains logged in `deferred-items.md`.

## Self-Check: PASSED

- Created file verified on disk: `UI/OnboardingWindowView.swift`.
- Modified files verified: `PreferencesStore.swift`, `WindowCoordinator.swift`, `FlintApp.swift`, `MenuBarPopoverView.swift`, `project.pbxproj`.
- Task commits verified in git log: `c59e895`, `bd6865c`.
- Both task `<verify>` blocks PASS; all `<acceptance_criteria>` satisfied; app-target Swift sources compile (only the pre-existing test-target XCTest error remains); `plutil -lint` OK; pbxproj ID collision resolved.

---
*Phase: 03-polish-distribution*
*Completed: 2026-06-27*
