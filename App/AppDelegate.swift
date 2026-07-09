// App/AppDelegate.swift
// Owns the launch-critical services (hotkey + popover presentation) so they exist at
// launch, NOT lazily when the MenuBarExtra content first renders.
//
// Why this exists: SwiftUI only evaluates an App struct's @State defaults when a scene
// first materializes. For a pure-MenuBarExtra accessory app, the popover content isn't
// built until the user clicks the menubar icon — so HotkeyManager.init() (which registers
// ⌘⇧Space) never ran at launch, and the .showPopover receiver inside the popover view was
// never subscribed. Result: the global hotkey did nothing until the first manual click,
// after which everything was live. Registering in applicationDidFinishLaunching (which the
// OS guarantees runs at launch) fixes both the producer and the consumer.

import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Owned here (not App @State) so they are alive at launch, before any popover render.
    let clipboard = ClipboardDetector()
    let hotkeyManager = HotkeyManager()

    private var showPopoverObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register the global hotkey eagerly. HotkeyManager.registerHotkey() posts .showPopover.
        hotkeyManager.registerHotkey()

        // Drive popover presentation from here rather than the popover view's .onReceive, which
        // isn't subscribed until the popover first renders (the same lazy-materialization bug).
        // The MenuBarExtraAccess binding at the scene level IS live at launch, so flipping
        // clipboard.isPopoverPresented opens the popover on the very first hotkey press.
        showPopoverObserver = NotificationCenter.default.addObserver(
            forName: .showPopover, object: nil, queue: .main
        ) { [clipboard] _ in
            MainActor.assumeIsolated {
                clipboard.isPopoverPresented = true
            }
        }
    }
}
