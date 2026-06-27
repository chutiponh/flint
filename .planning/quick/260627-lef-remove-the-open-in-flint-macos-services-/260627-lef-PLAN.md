---
phase: quick
plan: 260627-lef
type: execute
wave: 1
depends_on: []
files_modified:
  - Info.plist
  - App/AppDelegate.swift
  - App/FlintApp.swift
  - App/WindowCoordinator.swift
  - Core/Services/FlintServiceProvider.swift
  - UI/MenuBarPopoverView.swift
  - Flint.xcodeproj/project.pbxproj
autonomous: true
requirements: [DIST-01-REMOVAL]

must_haves:
  truths:
    - "The 'Open in Flint' macOS Services entry no longer exists in the built app"
    - "The Flint app target builds clean after removal"
    - "First-run onboarding still works (.openOnboarding notification preserved end-to-end)"
  artifacts:
    - path: "Info.plist"
      provides: "Bundle config with NSServices array removed (Sparkle keys + all other keys preserved)"
      contains: "SUPublicEDKey"
    - path: "App/WindowCoordinator.swift"
      provides: "Relocated .openOnboarding Notification.Name declaration (kept), Services routing methods kept"
      contains: "openOnboarding"
  key_links:
    - from: "App/WindowCoordinator.swift"
      to: ".openOnboarding"
      via: "Notification.Name declaration relocated from deleted FlintServiceProvider.swift"
      pattern: "static let openOnboarding"
    - from: "App/FlintApp.swift"
      to: ".openOnboarding receiver"
      via: ".onReceive onboarding handler still present"
      pattern: "openOnboarding"
---

<objective>
Remove the "Open in Flint" macOS Services feature entirely (the right-click → Services menu entry built in plan 03-01). It was discovered during phase 3 UAT that the Services entry never appeared in the right-click menu, and the user chose removal over fixing.

Scope is **Services menu only**. Drag-and-drop, onboarding, and Sparkle are untouched. The `WindowCoordinator.openToolViaService` / `openLauncherWithStagedText` routing methods are KEPT per explicit user decision (they become unreferenced but are retained intentionally).

The single hazard in this deletion: `.openOnboarding` (consumed by onboarding plan 03-03/03-04) is currently declared inside the `Notification.Name` extension in `FlintServiceProvider.swift`, which is being deleted. It MUST be relocated before that file is removed, or the app will not compile.

Purpose: Eliminate a dead/broken feature surface cleanly without regressing onboarding or breaking the app-target build.
Output: Services provider source deleted, NSServices removed from Info.plist, AppDelegate removed, all four Services-flow handlers/notifications removed, `.openOnboarding` relocated and preserved, pbxproj cleaned, app target builds clean.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/03-polish-distribution/03-01-SUMMARY.md

<interfaces>
<!-- Exact removal targets, pre-extracted from the codebase. No exploration needed. -->

DELETE ENTIRELY:
- Core/Services/FlintServiceProvider.swift (whole file — but FIRST relocate its `.openOnboarding` declaration, see Task 1)
- App/AppDelegate.swift (whole file — its ONLY job is registering the Services provider; confirmed no other use)

App/AppDelegate.swift (full body — both statements are Services-only):
```
NSApp.servicesProvider = FlintServiceProvider.shared
NSUpdateDynamicServices()
```

FlintServiceProvider.swift Notification.Name extension (lines ~44-54) declares FOUR names:
- serviceDidReceiveText  → REMOVE (Services-only)
- routeServiceMatch      → REMOVE (Services-only)
- routeServiceNoMatch    → REMOVE (Services-only)
- openOnboarding         → PRESERVE — relocate to WindowCoordinator.swift before deleting the file

App/FlintApp.swift — REMOVE:
- Line 21-23: the `// DIST-01: AppDelegate...` comment block + `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate`
- Lines 56-79: the entire `.onReceive(...for: .serviceDidReceiveText)` modifier block (the detect → seed → route handler)
- KEEP the `.onReceive(...for: .openOnboarding)` block (lines 80-86) and the `@Environment(\.openWindow)` it uses.

UI/MenuBarPopoverView.swift — REMOVE:
- Lines 191-198: `.onReceive(...for: .routeServiceMatch)` block
- Lines 199-205: `.onReceive(...for: .routeServiceNoMatch)` block
- KEEP everything else (the `.onReceive(.showPopover)` block, all keyboard shortcuts, fileDrop, onboarding gate that calls WindowCoordinator.shared.openOnboarding()).

App/WindowCoordinator.swift — KEEP `openToolViaService(toolId:)` and `openLauncherWithStagedText(_:)` (user decision). ADD the relocated `.openOnboarding` Notification.Name declaration here. Optionally tidy the stale doc-comment at line 31 that references "FlintServiceProvider's Notification.Name extension".

Info.plist — REMOVE only the `<key>NSServices</key>` ... `</array>` block (lines ~61-81). KEEP all Sparkle keys (SUPublicEDKey, SUFeedURL) and all bundle/posture keys. CFBundleName "Flint" stays (it is generic bundle metadata, not Services-specific).

Flint.xcodeproj/project.pbxproj — REMOVE these 8 lines (both AppDelegate.swift and FlintServiceProvider.swift):
- Line 45: `00110000000B1A /* AppDelegate.swift in Sources */ = ...`
- Line 46: `00110000000B2A /* FlintServiceProvider.swift in Sources */ = ...`
- Line 135: `00120000000B1A /* AppDelegate.swift */ = {isa = PBXFileReference; ...}`
- Line 136: `00120000000B2A /* FlintServiceProvider.swift */ = {isa = PBXFileReference; ...}`
- Line 301: `00120000000B1A /* AppDelegate.swift */,` (App group child)
- Line 336: `00120000000B2A /* FlintServiceProvider.swift */,` (Services group child)
- Line 718: `00110000000B1A /* AppDelegate.swift in Sources */,`
- Line 719: `00110000000B2A /* FlintServiceProvider.swift in Sources */,`
(Line numbers are from the current file; match by the unique identifier comments, not by line number, since earlier edits shift positions.)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Relocate .openOnboarding, then delete the Services source + NSServices + AppDelegate wiring</name>
  <files>App/WindowCoordinator.swift, Core/Services/FlintServiceProvider.swift, App/AppDelegate.swift, App/FlintApp.swift, UI/MenuBarPopoverView.swift, Info.plist</files>
  <action>
Perform removal in this exact order so the codebase never enters a state where `.openOnboarding` is undeclared.

1. WindowCoordinator.swift — relocate `.openOnboarding`: add a `Notification.Name` extension at the bottom of the file declaring `static let openOnboarding = Notification.Name("com.lathe.openOnboarding")` (keep the SAME raw string value `com.lathe.openOnboarding` so behavior is identical). Update the stale doc-comment at line 31 (currently "reserved in FlintServiceProvider's Notification.Name extension (plan 03-01)") to note it is declared in this file. Do NOT touch `openToolViaService` or `openLauncherWithStagedText` — keep both verbatim per user decision.

2. Delete `Core/Services/FlintServiceProvider.swift` entirely (use `rm`). This removes the `openInFlint` handler and the serviceDidReceiveText/routeServiceMatch/routeServiceNoMatch declarations. (`.openOnboarding` is now safe — it was relocated in step 1.)

3. Delete `App/AppDelegate.swift` entirely (use `rm`). Its only statements are `NSApp.servicesProvider = FlintServiceProvider.shared` and `NSUpdateDynamicServices()` — both Services-only; confirmed no other purpose via grep.

4. FlintApp.swift — remove the `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate` line plus its `// DIST-01: AppDelegate...` comment block (lines ~21-23). Remove the entire `.onReceive(...for: .serviceDidReceiveText)` modifier block (lines ~56-79, the detect → seed → openToolViaService/openLauncherWithStagedText + post routeServiceMatch/routeServiceNoMatch handler). KEEP the `.onReceive(...for: .openOnboarding)` block and `@Environment(\.openWindow)`.

5. MenuBarPopoverView.swift — remove the `.onReceive(...for: .routeServiceMatch)` block (lines ~191-198) and the `.onReceive(...for: .routeServiceNoMatch)` block (lines ~199-205). KEEP the `.onReceive(.showPopover)` block immediately above them and everything else.

6. Info.plist — remove only the `<key>NSServices</key>` element and its `<array>...</array>` value (lines ~61-81). Leave every other key untouched (Sparkle SUPublicEDKey/SUFeedURL, LSUIElement, CFBundleName, etc.).

Before deleting each of the three Services-only Notification.Name strings, the grep gate in `<verify>` confirms zero stray references remain. Do not remove `.openOnboarding`.
  </action>
  <verify>
    <automated>cd /Users/chutipon/Documents/project/flint && test ! -f Core/Services/FlintServiceProvider.swift && test ! -f App/AppDelegate.swift && grep -rq "static let openOnboarding" App/WindowCoordinator.swift && grep -rq "for: .openOnboarding" App/FlintApp.swift && ! grep -rq "serviceDidReceiveText\|routeServiceMatch\|routeServiceNoMatch" --include="*.swift" . && ! grep -q "NSServices\|openInFlint\|NSUpdateDynamicServices" Info.plist && echo PASS</automated>
  </verify>
  <done>FlintServiceProvider.swift and AppDelegate.swift are gone; `.openOnboarding` is declared in WindowCoordinator.swift and still received in FlintApp.swift; serviceDidReceiveText/routeServiceMatch/routeServiceNoMatch appear nowhere in *.swift; NSServices/openInFlint/NSUpdateDynamicServices appear nowhere in Info.plist; openToolViaService and openLauncherWithStagedText still present in WindowCoordinator.swift.</done>
</task>

<task type="auto">
  <name>Task 2: Drop file references from project.pbxproj and verify the app target builds clean</name>
  <files>Flint.xcodeproj/project.pbxproj</files>
  <action>
Remove the 8 pbxproj lines that reference the two deleted Swift files. Match by the unique identifier comments (NOT line numbers — positions shift as you delete):

- PBXBuildFile: the two lines containing `AppDelegate.swift in Sources` and `FlintServiceProvider.swift in Sources` with `isa = PBXBuildFile`.
- PBXFileReference: the two lines containing `AppDelegate.swift */ = {isa = PBXFileReference` and `FlintServiceProvider.swift */ = {isa = PBXFileReference`.
- PBXGroup children: the `AppDelegate.swift */,` child in the `App` group (id 001500000000002) and the `FlintServiceProvider.swift */,` child in the `Services` group (id 001500000000005).
- PBXSourcesBuildPhase: the two `... in Sources */,` entries in the Sources build phase (around line 718-719).

Do not remove any other file's entries. The `Core/Services/` group itself stays (it still has HistoryStore, PreferencesStore, ToolRegistry, etc.).

Then run the app-target build as the gate.

NOTE on the build gate: a full `xcodebuild -scheme Flint` build fails on a PRE-EXISTING test-target XCTest module error (FlintTests/PinnedToolReorderTests.swift) that is OUT OF SCOPE and predates this work (logged in 03-01-SUMMARY.md). That failure is NOT our concern. The gate is that the **Flint app target** compiles clean — i.e., no errors originating from app sources, and specifically no "cannot find 'AppDelegate'", "cannot find type 'FlintServiceProvider'", or unresolved `.openOnboarding`/`.serviceDidReceiveText` symbol errors. If the scheme build is used, the only acceptable remaining failure is the documented FlintTests/XCTest module error; any app-source error fails the task.
  </action>
  <verify>
    <automated>cd /Users/chutipon/Documents/project/flint && ! grep -q "FlintServiceProvider\|AppDelegate" Flint.xcodeproj/project.pbxproj && xcodebuild -project Flint.xcodeproj -scheme Flint -configuration Debug -destination 'platform=macOS' build 2>&1 | tee /tmp/flint-build.log | tail -5; ! grep -E "error:" /tmp/flint-build.log | grep -v "XCTest\|FlintTests" | grep -q "error:" && echo "APP TARGET CLEAN"</automated>
  </verify>
  <done>No `FlintServiceProvider` or `AppDelegate` strings remain in project.pbxproj. The app target compiles with no app-source errors; the only permissible build failure is the pre-existing, out-of-scope FlintTests XCTest module error.</done>
</task>

<task type="auto">
  <name>Task 3: Final scope-clean grep sweep</name>
  <files>(verification only — no edits unless a stray reference is found)</files>
  <action>
Run the full scope-clean sweep from the task intent across all Swift files and Info.plist. The only allowed surviving hits are:
- `openToolViaService` and `openLauncherWithStagedText` in WindowCoordinator.swift (KEPT per user decision) and their KEEP-related doc comments.
- `openOnboarding` everywhere (PRESERVED — onboarding flow).
- `CFBundleName` "Flint" / generic bundle keys in Info.plist (not Services-specific).

If any of `openInFlint`, `FlintServiceProvider`, `serviceDidReceiveText`, `routeServiceMatch`, `routeServiceNoMatch`, `NSServices`, or `NSUpdateDynamicServices` still appears, remove the stray reference (even in comments — flag and delete leftover Services comments). Re-run until clean.
  </action>
  <verify>
    <automated>cd /Users/chutipon/Documents/project/flint && ! grep -ri "openInFlint\|FlintServiceProvider\|serviceDidReceiveText\|routeServiceMatch\|routeServiceNoMatch\|NSServices\|NSUpdateDynamicServices" --include="*.swift" --include="Info.plist" . && echo "SCOPE CLEAN"</automated>
  </verify>
  <done>The grep sweep returns nothing for all seven Services-specific terms across *.swift and Info.plist. openToolViaService/openLauncherWithStagedText (kept) and openOnboarding (preserved) are the only Services-adjacent symbols remaining, intentionally.</done>
</task>

</tasks>

<verification>
- App target builds clean (Task 2 gate; pre-existing FlintTests XCTest error is the only permitted failure).
- `.openOnboarding` notification declared in WindowCoordinator.swift, posted by openOnboarding(), received in FlintApp.swift — onboarding flow intact.
- Seven Services-specific terms absent from all *.swift and Info.plist (Task 3).
- openToolViaService / openLauncherWithStagedText retained in WindowCoordinator.swift per user decision.
</verification>

<success_criteria>
- The "Open in Flint" macOS Services feature is fully removed: no NSServices entry, no provider source, no AppDelegate, no Services-flow notifications/handlers.
- The Flint app target compiles clean.
- Onboarding (.openOnboarding), drag-and-drop, and Sparkle are untouched and functional.
- The kept routing methods remain in WindowCoordinator.swift.
</success_criteria>

<output>
Create `.planning/quick/260627-lef-remove-the-open-in-flint-macos-services-/260627-lef-SUMMARY.md` when done.
</output>
