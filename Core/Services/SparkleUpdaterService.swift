// Core/Services/SparkleUpdaterService.swift
// Lazy wrapper around Sparkle's SPUStandardUpdaterController (DIST-04).
//
// Sparkle is initialized OFF the cold-start critical path: start() is invoked from
// the popover .onAppear (MenuBarPopoverView), NOT from FlintApp.init. Constructing
// SPUStandardUpdaterController at app launch would regress the < 500ms cold-start
// budget (RESEARCH Pitfall #6 / A5). Deferring it to the first popover appearance
// keeps launch instant while still arming the background update check.
//
// Sparkle intentionally does NOT check for updates on the very first launch — this is
// correct, expected behavior; do not override it (RESEARCH anti-pattern).
//
// D-08: Sparkle owns the standard update sheet (background auto-check → user prompt with
// release notes → install-and-restart). No custom update UI is added here; we never set
// up silent auto-install.
//
// Source: 03-PATTERNS.md § "SparkleUpdaterService.swift" + RESEARCH.md Pattern 3
//         (sparkle-project.org/documentation/programmatic-setup). Class shell mirrors
//         HotkeyManager's @Observable @MainActor final class service triple.

import Sparkle
import Observation

@Observable
@MainActor
final class SparkleUpdaterService {
    /// The standard Sparkle controller. Nil until start() is first called from the popover.
    private(set) var controller: SPUStandardUpdaterController?

    /// Lazily create and start the updater. Called from the popover .onAppear so Sparkle
    /// init stays off the cold-start critical path (Pitfall #6). Idempotent — guarded so
    /// repeated popover appearances do not re-create the controller.
    func start() {
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Trigger a manual update check (e.g. from a "Check for Updates…" menu item).
    /// No-op until start() has armed the controller.
    func checkForUpdates() {
        controller?.updater.checkForUpdates()
    }
}
