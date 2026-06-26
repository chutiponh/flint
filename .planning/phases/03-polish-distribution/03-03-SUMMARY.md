---
phase: 03-polish-distribution
plan: 03
subsystem: distribution
tags: [sparkle, auto-update, spm, eddsa, info-plist, cold-start, observable-service]

# Dependency graph
requires:
  - phase: 03-polish-distribution
    provides: "Manual Info.plist foundation (03-01); MenuBarPopoverView .onAppear + launcher fileDrop modifiers (03-02a)"
provides:
  - "Sparkle 2.9.3 as an exact-version SPM dependency, resolved and pinned in Package.resolved"
  - "SUPublicEDKey + SUFeedURL keys present in the manual Info.plist from the first distributable build (currently CLEARLY-MARKED PLACEHOLDERS — see Deferred Manual Verification)"
  - "Core/Services/SparkleUpdaterService.swift — @Observable @MainActor wrapper around SPUStandardUpdaterController with lazy start() + checkForUpdates()"
  - "Lazy Sparkle wiring: owned in FlintApp @State, injected via .environment, started from popover .onAppear (off the cold-start critical path)"
affects: [03-05-distribution-notarization-appcast]

# Tech tracking
tech-stack:
  added:
    - "Sparkle 2.9.3 (sparkle-project/Sparkle) — macOS auto-update framework (SPM, exactVersion)"
  patterns:
    - "Lazy off-critical-path service init: SPUStandardUpdaterController constructed in popover .onAppear (guarded), never in FlintApp.init (RESEARCH Pitfall #6)"
    - "@Observable @MainActor final class service shell (copies HotkeyManager) wrapping an external controller behind an idempotent start()"
    - "Sparkle keys live in the manual Info.plist (array/string keys not expressible as INFOPLIST_KEY_* scalars)"

key-files:
  created:
    - "Core/Services/SparkleUpdaterService.swift"
  modified:
    - "Flint.xcodeproj/project.pbxproj"
    - "Flint.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    - "Info.plist"
    - "App/FlintApp.swift"
    - "UI/MenuBarPopoverView.swift"

key-decisions:
  - "Embedded CLEARLY-MARKED PLACEHOLDER values for SUPublicEDKey and SUFeedURL rather than running generate_keys, because key generation writes a private key into the login Keychain — a credential-gated step the user explicitly deferred to plan 03-05. The plist structure + wiring are complete and correct; only the values are placeholders."
  - "Used exactVersion 2.9.3 for Sparkle (mirrors GRDB/KeyboardShortcuts/ChromaKit pinning convention) rather than a range, matching the CLAUDE.md locked toolchain decision."
  - "Edited project.pbxproj by hand (mirroring the existing package-reference IDs) then ran xcodebuild -resolvePackageDependencies to fetch/pin 2.9.3 and write Package.resolved."

requirements-completed: [DIST-04]

# Metrics
duration: 4 min
completed: 2026-06-26
---

# Phase 3 Plan 03: Sparkle Auto-Update Readiness Summary

**Sparkle 2.9.3 added as a pinned SPM dependency, with SUPublicEDKey + SUFeedURL embedded in the manual Info.plist and a lazy `SparkleUpdaterService` armed from the popover `.onAppear` — making Flint auto-update-ready without regressing cold start (real EdDSA key + production feed URL deferred to plan 03-05).**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-26T16:51:16Z
- **Completed:** 2026-06-26T16:55:31Z
- **Tasks:** 2 auto completed (Task 2, Task 3) + 2 checkpoint:human-verify (Task 1 package-legitimacy, Task 4 readiness — both deferred to batched phase-end verification per "code now, verify at the end" mode)
- **Files modified:** 5 (1 created, 4 modified)

## Accomplishments
- Added **Sparkle 2.9.3** (`github.com/sparkle-project/Sparkle`) as an `exactVersion` SPM dependency: new `XCRemoteSwiftPackageReference`, `XCSwiftPackageProductDependency`, frameworks + sources build-phase entries, and the app target's `packageProductDependencies`/`packageReferences`, mirroring the existing GRDB/KeyboardShortcuts/ChromaKit wiring. `xcodebuild -resolvePackageDependencies` fetched and checked out 2.9.3; `Package.resolved` pins `version: 2.9.3` (revision `d46d456...`).
- Created **`Core/Services/SparkleUpdaterService.swift`** — `@Observable @MainActor final class` (copies the HotkeyManager service shell) with `private(set) var controller: SPUStandardUpdaterController?`, an idempotent lazy `start()` (guarded on `controller == nil`, constructs `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)`), and `checkForUpdates()`. No custom update UI (D-08 — Sparkle owns the standard sheet).
- Embedded **`SUPublicEDKey`** and **`SUFeedURL`** in the manual `Info.plist` from this first distributable build (Pitfall #5 — the key must exist from byte one), each as a clearly-marked placeholder with an adjacent XML comment mandating replacement before any release.
- Wired the service **off the cold-start critical path** (RESEARCH Pitfall #6): owned as `@State private var sparkle = SparkleUpdaterService()` in `FlintApp`, injected via `.environment(sparkle)`, and `start()` invoked from the existing popover `.onAppear` (alongside `clipboard.start(...)`), layered cleanly onto the 03-01/03-02a modifiers. No `SPUStandardUpdaterController` is constructed in `FlintApp.init`.

## Task Commits

Each auto task was committed atomically:

1. **Task 2: Add Sparkle SPM dependency + SparkleUpdaterService** — `d37f0f1` (feat)
2. **Task 3: Embed SUPublicEDKey + SUFeedURL; wire lazy start** — `71a280f` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

_Task 1 (checkpoint:human-verify, package legitimacy) and Task 4 (checkpoint:human-verify, blocking readiness) write no code — verification recorded under Deferred Manual Verification below._

## Files Created/Modified
- `Core/Services/SparkleUpdaterService.swift` — **created**. Lazy `@Observable @MainActor` wrapper around `SPUStandardUpdaterController`; `start()` guarded + off cold-start path; `checkForUpdates()` for a manual check.
- `Flint.xcodeproj/project.pbxproj` — **modified**. Added Sparkle package reference (`exactVersion 2.9.3`), product dependency, `Sparkle in Frameworks` build file, `SparkleUpdaterService.swift` file ref + Sources build file + Services group entry, and the app target's `packageProductDependencies`/`packageReferences`. `plutil -lint` OK.
- `Flint.xcodeproj/.../swiftpm/Package.resolved` — **modified**. Sparkle pinned to `2.9.3`.
- `Info.plist` — **modified**. Added `SUPublicEDKey` (placeholder) and `SUFeedURL` (`http://localhost:8000/appcast.xml` placeholder) with replacement-mandating comments. `CFBundleVersion`/`CFBundleShortVersionString` remain build-setting variables (`$(CURRENT_PROJECT_VERSION)`/`$(MARKETING_VERSION)`) for per-release bumps.
- `App/FlintApp.swift` — **modified**. Added `@State private var sparkle = SparkleUpdaterService()` to the service block and `.environment(sparkle)` on the MenuBarPopoverView content.
- `UI/MenuBarPopoverView.swift` — **modified**. Added `@Environment(SparkleUpdaterService.self) private var sparkle` and `sparkle.start()` inside the existing `.onAppear`.

## Decisions Made
- **Placeholder SUPublicEDKey/SUFeedURL instead of generated values** — `generate_keys` writes a private key into the login Keychain (a credential-gated, machine-binding step the user explicitly deferred to plan 03-05). Wiring + plist structure are complete and correct; only the two values are placeholders, each flagged with a loud comment. This keeps the BLOCKING "key present from first build" structure in place while leaving the irreversible key-generation step to the deferred distribution plan.
- **exactVersion 2.9.3** for Sparkle (matches CLAUDE.md locked decision and the project's pinning convention for other packages).
- **Hand-edited pbxproj + `-resolvePackageDependencies`** to add the dependency deterministically and pin `Package.resolved`, rather than relying on the Xcode UI.

## Deviations from Plan

None — plan executed exactly as written, with one intentional, orchestrator-sanctioned substitution: the real EdDSA keypair generation (Task 3 `<action>`) was replaced with clearly-marked placeholders, because the credential-gated `generate_keys` step is explicitly deferred to plan 03-05 (see Deferred Manual Verification). This is the documented "code now, verify at the end" handling for this plan, not an unplanned divergence.

**Total deviations:** 0 functional. **Impact:** None on structure/wiring; the only outstanding work is value substitution (placeholders → real key + production URL) tracked into plan 03-05.

## Authentication Gates

None — no login/credential prompt was hit during execution. (The EdDSA private-key generation that would touch the login Keychain was deferred, not attempted.)

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `SUPublicEDKey` placeholder string | `Info.plist` | Real base64 public key requires `generate_keys` (writes private key to login Keychain). Deferred to plan 03-05. Replace before any release. |
| `SUFeedURL` = `http://localhost:8000/appcast.xml` | `Info.plist` | Placeholder for the v0.0.1→v0.0.2 local dry-run (plan 03-05). Replace with the production HTTPS appcast URL before v1.0. |

These are intentional and resolved by plan 03-05. The plist structure, key presence, and Sparkle wiring are complete and correct now; only the two values await the deferred credential-gated step.

## Deferred Manual Verification

Both checkpoint tasks (Task 1 package-legitimacy and Task 4 readiness) were NOT blocked on — code is written and committed; verification is recorded here for the single batched phase-end manual pass.

### Task 1 — Sparkle package legitimacy (checkpoint:human-verify, blocking-human)
**Approved inline per orchestrator instruction.** Sparkle (`github.com/sparkle-project/Sparkle`) 2.9.3 is the well-known, widely-used, only production-grade non-MAS macOS auto-update framework, named explicitly in the project's CLAUDE.md "Recommended Stack" (locked toolchain decision, not a new choice). Version 2.9.3 resolved and checked out successfully.
**Human re-confirm (optional):** repo authoritative (`sparkle-project/Sparkle`), 2.9.3 on the GitHub releases page, listed in CLAUDE.md.

### Task 4 — Sparkle readiness + cold-start budget + key presence (checkpoint:human-verify, BLOCKING)
**What was built:** Sparkle 2.9.3 SPM dependency, SUPublicEDKey + SUFeedURL in Info.plist, a lazy `SparkleUpdaterService` started from the popover `.onAppear`.

**[BLOCKING] PLACEHOLDER-SUBSTITUTION REQUIREMENT (ties into plan 03-05):**
1. The current `SUPublicEDKey` value (`PLACEHOLDER_REPLACE_WITH_REAL_SUPublicEDKey_FROM_generate_keys_BEFORE_RELEASE_03-05`) is a NON-FUNCTIONAL PLACEHOLDER — **NOT** a real key. Before ANY release ships, plan 03-05 MUST:
   - Run Sparkle 2.9.3's `bin/generate_keys` ONCE (tool present at `~/Library/Developer/Xcode/DerivedData/Flint-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys`).
   - Copy the printed base64 public key into `Info.plist` `SUPublicEDKey`, replacing the placeholder.
   - Confirm the matching **private key** was stored in the **login Keychain** (Keychain Access → search "Sparkle" / "ed25519") and is **backed up off-machine** (1Password / CI secret) — the private key must NEVER enter the repo, dotfiles, or env vars (T-03-09 Information Disclosure). It is currently absent from the repo (verified by grep gate).
   - Verify: `/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" Info.plist` prints the real key.
   - **DO NOT ship without the real key** — Sparkle rejects adding it later as a security downgrade and permanently locks existing users out of auto-update (Pitfall #5 / #10). This is unrecoverable in the field.
2. Replace the `SUFeedURL` placeholder (`http://localhost:8000/appcast.xml`) with the production **HTTPS** appcast URL before v1.0 (it may stay the local URL for the 03-05 local dry-run only).

**Human verification steps (Xcode):**
1. Build and run Flint from Xcode; confirm it compiles with Sparkle linked and launches normally (the menubar wrench icon appears).
2. Cold-start: quit Flint fully, relaunch — time-to-popover should feel instant (<500ms; use the Instruments App Launch template before/after if available). Confirm `sparkle.start()` runs in the popover `.onAppear`, not at app init (verified in source: no `SPUStandardUpdaterController` in `FlintApp.swift`).
3. Confirm NO Sparkle update sheet appears on the first launch (Sparkle intentionally skips the first-launch check — correct).
4. **DO NOT approve for release** while `SUPublicEDKey` is the placeholder. (It is acceptable as the readiness/structure checkpoint for this plan; the real-key gate is owned by plan 03-05.)

**Resume signal (batched pass):** "approved" only once the real `SUPublicEDKey` is present in `Info.plist` and cold start is unaffected; otherwise describe the gap.

## Issues Encountered

- **Headless `xcodebuild` full build is blocked by a pre-existing, out-of-scope test-target error** (`FlintTests/PinnedToolReorderTests.swift` — `import XCTest` module-search-path failure under CLI `xcodebuild`), which predates phase 03 (logged in `deferred-items.md` by plan 03-01). Per the orchestrator's explicit instruction, this was NOT fixed and was NOT used as a pass/fail gate. Source-level acceptance criteria (grep / PlistBuddy / plutil / Package.resolved pin) all pass; the app-scheme GUI compile-and-run is folded into the deferred manual-verification pass (Task 4).

## Next Phase Readiness
- DIST-04 source/structure implementation complete: Sparkle 2.9.3 pinned, `SparkleUpdaterService` wired lazily off the cold-start path, and the `SUPublicEDKey`/`SUFeedURL` plist keys present from the first build.
- **Outstanding (plan 03-05, credential-gated):** generate the real EdDSA keypair, replace the `SUPublicEDKey` placeholder with the real public key, back up the private key off-machine, and replace the `SUFeedURL` placeholder with the production HTTPS appcast URL — then run the v0.0.1→v0.0.2 local update dry-run.
- No blockers introduced. One pre-existing, out-of-scope test-target build issue remains logged in `deferred-items.md`.

## Self-Check: PASSED

- Created file verified on disk: `Core/Services/SparkleUpdaterService.swift`.
- Modified files verified: `Info.plist` (SUPublicEDKey + SUFeedURL present, `plutil -lint` OK), `App/FlintApp.swift` (`SparkleUpdaterService()` + `.environment(sparkle)`), `UI/MenuBarPopoverView.swift` (`sparkle.start()` in `.onAppear`), `project.pbxproj` (Sparkle refs), `Package.resolved` (2.9.3 pinned).
- Task commits verified in git log: `d37f0f1`, `71a280f`.
- No private key in repo (grep gate clean).

---
*Phase: 03-polish-distribution*
*Completed: 2026-06-26*
