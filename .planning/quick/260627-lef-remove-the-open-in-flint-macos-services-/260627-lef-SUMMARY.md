---
phase: quick
plan: 260627-lef
subsystem: App/Services
tags: [cleanup, services-removal, notification-names, pbxproj]
dependency_graph:
  requires: [03-01]
  provides: []
  affects: [App/WindowCoordinator.swift, App/FlintApp.swift, UI/MenuBarPopoverView.swift, Info.plist, Flint.xcodeproj/project.pbxproj]
tech_stack:
  added: []
  patterns: []
key_files:
  deleted:
    - App/AppDelegate.swift
    - Core/Services/FlintServiceProvider.swift
  modified:
    - App/WindowCoordinator.swift
    - App/FlintApp.swift
    - UI/MenuBarPopoverView.swift
    - Info.plist
    - Flint.xcodeproj/project.pbxproj
decisions:
  - openOnboarding Notification.Name relocated to WindowCoordinator.swift with same raw string value to preserve onboarding flow
  - openToolViaService/openLauncherWithStagedText retained in WindowCoordinator per explicit user decision (unreferenced but intentional)
  - FlintServiceProvider comment in WindowCoordinator extension removed during Task 3 scope sweep (stray reference cleanup)
metrics:
  duration: "~7 minutes"
  completed: "2026-06-27"
  tasks: 3
  files: 7
---

# Phase quick Plan 260627-lef: Remove Open in Flint macOS Services Summary

**One-liner:** Deleted FlintServiceProvider + AppDelegate, removed NSServices from Info.plist and 8 pbxproj entries, relocated `.openOnboarding` to WindowCoordinator.swift — app target builds clean.

## What Was Done

Removed the "Open in Flint" macOS Services feature (right-click Services menu) that was implemented in plan 03-01 but discovered during UAT to never appear in the right-click menu. The user chose removal over fixing.

### Task 1: Relocate .openOnboarding, delete Services source + NSServices + AppDelegate wiring

Critical ordering observed: `.openOnboarding` Notification.Name relocated to `App/WindowCoordinator.swift` (same raw string `com.lathe.openOnboarding`) BEFORE deleting `Core/Services/FlintServiceProvider.swift`, preventing any compile-time gap.

Changes made in order:
1. Added `Notification.Name` extension to `WindowCoordinator.swift` declaring `.openOnboarding`; updated stale doc-comment referencing old location
2. Deleted `Core/Services/FlintServiceProvider.swift` via `rm` then `git rm`
3. Deleted `App/AppDelegate.swift` via `rm` then `git rm`
4. Removed `@NSApplicationDelegateAdaptor(AppDelegate.self)` and its comment block from `FlintApp.swift`; removed the entire `.onReceive(for: .serviceDidReceiveText)` block (detect→seed→open handler); preserved `.onReceive(for: .openOnboarding)` intact
5. Removed `.onReceive(for: .routeServiceMatch)` and `.onReceive(for: .routeServiceNoMatch)` from `MenuBarPopoverView.swift`; preserved `.onReceive(for: .showPopover)` intact
6. Removed `<key>NSServices</key>...<array>...</array>` from `Info.plist`; removed stale CFBundleName NSPortName comment; preserved all Sparkle keys

**Commit:** 45cea79

### Task 2: Drop file references from project.pbxproj + build gate

Removed the 8 pbxproj entries by unique identifier comment (not line number):
- PBXBuildFile: `00110000000B1A` (AppDelegate.swift in Sources), `00110000000B2A` (FlintServiceProvider.swift in Sources)
- PBXFileReference: `00120000000B1A` (AppDelegate.swift), `00120000000B2A` (FlintServiceProvider.swift)
- PBXGroup App children: `00120000000B1A /* AppDelegate.swift */,`
- PBXGroup Services children: `00120000000B2A /* FlintServiceProvider.swift */,`
- PBXSourcesBuildPhase: both `...in Sources */,` entries

Build gate result: **BUILD SUCCEEDED** — no app-source errors.

**Commit:** 346e51a

### Task 3: Final scope-clean grep sweep

Sweep found one stray reference: a comment line in `WindowCoordinator.swift`'s Notification.Name extension that named `FlintServiceProvider.swift`. Cleaned the comment.

Final sweep result: **SCOPE CLEAN** — all seven Services-specific terms absent from *.swift and Info.plist.

**Commit:** 19fee45

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stray FlintServiceProvider comment in WindowCoordinator doc-comments for openToolViaService/openLauncherWithStagedText**
- **Found during:** Task 1
- **Issue:** The kept method doc-comments for `openToolViaService` and `openLauncherWithStagedText` referenced `.routeServiceMatch` and `.routeServiceNoMatch` by name; Task 3 sweep would catch these as stray references
- **Fix:** Updated doc-comments to remove the notification name references before Task 1 commit; final comment in Notification.Name extension cleaned during Task 3
- **Files modified:** App/WindowCoordinator.swift
- **Commit:** 45cea79 (doc-comments), 19fee45 (extension comment)

## Build Gate

**Status: PASS**

`xcodebuild -project Flint.xcodeproj -scheme Flint -configuration Debug -destination 'platform=macOS' build` completed with `** BUILD SUCCEEDED **`. No app-source errors. The pre-existing FlintTests/PinnedToolReorderTests.swift XCTest module error is out of scope and was not present in this build run (scheme build ran app target only successfully).

## Known Stubs

None. All removed code was dead (Services entry never appeared in macOS right-click menu). No UI stubs introduced.

## Threat Flags

None. This plan only removes code — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- App/WindowCoordinator.swift exists and contains `static let openOnboarding`: FOUND
- App/FlintApp.swift contains `.onReceive(for: .openOnboarding)`: FOUND
- Core/Services/FlintServiceProvider.swift: DELETED (confirmed)
- App/AppDelegate.swift: DELETED (confirmed)
- No serviceDidReceiveText/routeServiceMatch/routeServiceNoMatch in *.swift: CONFIRMED
- No NSServices/openInFlint/NSUpdateDynamicServices in Info.plist: CONFIRMED
- No AppDelegate/FlintServiceProvider in project.pbxproj: CONFIRMED (grep count=0)
- Commits 45cea79, 346e51a, 19fee45 all exist in git log: CONFIRMED
