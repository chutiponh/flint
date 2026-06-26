# Phase 3: Polish & Distribution - Pattern Map

**Mapped:** 2026-06-26
**Files analyzed:** 9 new/modified files
**Analogs found:** 9 / 9

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `App/AppDelegate.swift` | app-delegate / service-registrar | event-driven | `Core/Services/HotkeyManager.swift` (notification-post pattern) | role-match |
| `Core/Services/FlintServiceProvider.swift` | service / NSObject handler | event-driven | `Core/Services/ClipboardDetector.swift` (pasteboard read + detect + notify) | exact |
| `App/WindowCoordinator.swift` (extend) | coordinator | request-response | `App/WindowCoordinator.swift` itself (add `openOnboarding()`, `openToolViaService()`, `openLauncherWithStagedText()`) | self-extend |
| `Core/Services/PreferencesStore.swift` (extend) | service / store | CRUD | `Core/Services/PreferencesStore.swift` itself (add `hasSeenOnboarding` key) | self-extend |
| `Core/Services/SparkleUpdaterService.swift` | service / lifecycle | request-response | `Core/Services/HotkeyManager.swift` (`@Observable @MainActor` service init pattern) | role-match |
| `App/FlintApp.swift` (extend) | app entry / orchestrator | event-driven | `App/FlintApp.swift` itself (add `@NSApplicationDelegateAdaptor`, Sparkle `@State`, onboarding gate, service notification receiver) | self-extend |
| `UI/OnboardingWindowView.swift` | UI component / window | request-response | `UI/PreferencesView.swift` (non-popover window, `WindowCoordinator.windowWillClose()` on dismiss, SMAppService toggle) | role-match |
| `UI/Components/DropOverlayView.swift` | UI component / overlay | event-driven | `UI/Components/WarningBannerView.swift` (stateless SwiftUI overlay, severity-tinted, accessibility-labeled) | role-match |
| `.onDrop` additions to tool views + launcher | modifier / data-flow | file-I/O | `Tools/Base64/Base64ViewModel.swift` `encodeFileChunked` + `Tools/Hash/HashViewModel.swift` `startFileHash` (off-main file pipeline) | exact (binary tools); role-match (text tools) |

---

## Pattern Assignments

### `App/AppDelegate.swift` (app-delegate, event-driven)

**Analog:** `Core/Services/HotkeyManager.swift`

**Imports pattern** (HotkeyManager.swift lines 1-8):
```swift
import KeyboardShortcuts
import Foundation
import Observation
```
AppDelegate uses AppKit instead of KeyboardShortcuts:
```swift
import AppKit
```

**Core pattern — register service provider + force cache refresh** (from RESEARCH.md Pattern 1):
```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = FlintServiceProvider.shared
        // Force Services cache update during development — harmless in production
        NSUpdateDynamicServices()
    }
}
```

**Wire into FlintApp** (mirrors `@State private var hotkeyManager = HotkeyManager()` in FlintApp.swift line 24):
```swift
// Add to FlintApp.swift before @State declarations:
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

**Notification name convention** (HotkeyManager.swift lines 17-19):
```swift
// Same `extension Notification.Name` pattern used throughout the project:
extension Notification.Name {
    static let showPopover = Notification.Name("com.lathe.showPopover")
    static let openWorkspace = Notification.Name("com.lathe.openWorkspace")
}
// Phase 3 additions follow same "lathe." / "com.lathe." prefix:
// static let serviceDidReceiveText = Notification.Name("lathe.serviceDidReceiveText")
// static let openOnboarding = Notification.Name("lathe.openOnboarding")
```

---

### `Core/Services/FlintServiceProvider.swift` (service, event-driven)

**Analog:** `Core/Services/ClipboardDetector.swift`

**Imports + class declaration pattern** (ClipboardDetector.swift lines 1-13):
```swift
import AppKit
import Observation

@Observable
@MainActor
final class ClipboardDetector {
```
FlintServiceProvider is NSObject (required for `@objc` Services handler), NOT `@Observable`:
```swift
import AppKit

final class FlintServiceProvider: NSObject, @unchecked Sendable {
    static let shared = FlintServiceProvider()
    private override init() {}
```

**Core pattern — read pasteboard, post notification** (mirrors ClipboardDetector's pasteboard read at lines 76-82):
```swift
// ClipboardDetector analog (lines 76-82):
guard isEnabled,
      let string = NSPasteboard.general.string(forType: .string),
      !string.isEmpty else {
    detectionResult = nil
    return
}
detectionResult = registry?.detect(from: string)

// FlintServiceProvider version — @objc selector name must match NSMessage in Info.plist:
@objc func openInFlint(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString>?
) {
    guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
    // Post notification — FlintApp receives on @MainActor (same pattern as HotkeyManager)
    NotificationCenter.default.post(
        name: .serviceDidReceiveText,
        object: nil,
        userInfo: ["text": text]
    )
}
```

**"Off-thread → main actor" dispatch pattern** (ClipboardDetector.swift lines 44-56):
```swift
// NSPasteboardDidChangeNotification handler dispatches to main actor:
Task { @MainActor [weak self] in
    self?.pasteboardDidChange()
}
// Services handler arrives on an arbitrary AppKit thread — same Task @MainActor wrapper applies
// if direct ToolSeed/WindowCoordinator calls are ever added here instead of via Notification.
```

---

### `App/WindowCoordinator.swift` — extend with 3 new methods (coordinator, request-response)

**Analog:** `App/WindowCoordinator.swift` (self-extend — copy the `openWorkspace()` / `openPreferences()` pattern exactly)

**Existing activation-policy dance to copy** (WindowCoordinator.swift lines 18-26):
```swift
func openWorkspace() {
    windowCount += 1
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    // Short delay before posting notification so window can become key
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(name: .openWorkspace, object: nil)
    }
}
```

**New `openOnboarding()` — copy structure verbatim, change notification name:**
```swift
func openOnboarding() {
    windowCount += 1
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(name: .openOnboarding, object: nil)
    }
}
```

**New `openToolViaService(toolId:)` — same dance, no separate notification needed (tool is opened via `ToolSeed` + `PopoverNavigationState` mutation in FlintApp's `.onReceive` handler):**
```swift
func openToolViaService(toolId: String) {
    windowCount += 1
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // Popover is presented via clipboard.isPopoverPresented binding (MenuBarExtraAccess)
        // Navigation to the specific tool is set by FlintApp's .onReceive block
        NotificationCenter.default.post(name: .showPopover, object: nil)
    }
}
```

**`windowWillClose()` pattern to add to `OnboardingWindowView`** (WindowCoordinator.swift lines 42-50):
```swift
func windowWillClose() {
    windowCount = max(0, windowCount - 1)
    if windowCount == 0 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
```

---

### `Core/Services/PreferencesStore.swift` — add `hasSeenOnboarding` key (service, CRUD)

**Analog:** `Core/Services/PreferencesStore.swift` (self-extend)

**Copy this Bool key pattern** (PreferencesStore.swift lines 72-74 for `showInDock`):
```swift
var showInDock: Bool {
    get { defaults.object(forKey: Keys.showInDock) as? Bool ?? false }
    set { defaults.set(newValue, forKey: Keys.showInDock) }
}
```

**New `hasSeenOnboarding` — same pattern, false default triggers onboarding on first run:**
```swift
// Add to MARK: - Onboarding (DIST-03) section:
var hasSeenOnboarding: Bool {
    get { defaults.object(forKey: Keys.hasSeenOnboarding) as? Bool ?? false }
    set { defaults.set(newValue, forKey: Keys.hasSeenOnboarding) }
}
```

**Add key constant** (copy from PreferencesStore.swift private enum Keys, lines 224-237):
```swift
// In private enum Keys:
static let hasSeenOnboarding = "lathe.hasSeenOnboarding"
```

Note: `defaults.bool(forKey:)` is also valid since a missing key returns `false` — either form is correct. The `object(forKey:) as? Bool ?? false` pattern is used throughout the file for consistency.

---

### `Core/Services/SparkleUpdaterService.swift` (service, request-response)

**Analog:** `Core/Services/HotkeyManager.swift`

**Class structure to copy** (HotkeyManager.swift lines 21-31):
```swift
@Observable
@MainActor
final class HotkeyManager {
    init() {
        KeyboardShortcuts.onKeyDown(for: .openFlint) {
            NotificationCenter.default.post(name: .showPopover, object: nil)
        }
    }
}
```

**SparkleUpdaterService adapts the same `@Observable @MainActor final class` shell:**
```swift
import Sparkle

@Observable
@MainActor
final class SparkleUpdaterService {
    private(set) var controller: SPUStandardUpdaterController?

    // Called from popover .onAppear — keeps Sparkle init off cold-start critical path
    func start() {
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller?.updater.checkForUpdates()
    }
}
```

**Service ownership in FlintApp** (mirrors FlintApp.swift lines 21-26):
```swift
// Existing @State services (FlintApp.swift lines 21-26):
@State private var historyStore = HistoryStore()
@State private var prefs = PreferencesStore()
@State private var clipboard = ClipboardDetector()
@State private var hotkeyManager = HotkeyManager()
@State private var toolRegistry = ToolRegistry()
@State private var toolSeed = ToolSeed()

// Add alongside existing services:
@State private var sparkle = SparkleUpdaterService()
```

**Call `.start()` in `.onAppear`** (mirrors `clipboard.start(registry: toolRegistry)` in MenuBarPopoverView.swift line 129):
```swift
// In MenuBarPopoverView or MenuBarExtra content's .onAppear:
.onAppear {
    searchFocused = true
    clipboard.start(registry: toolRegistry)
    sparkle.start()   // <-- add this line; defers Sparkle init off cold-start path
    // ... onboarding gate here too
}
```

---

### `App/FlintApp.swift` — extend (app entry / orchestrator, event-driven)

**Analog:** `App/FlintApp.swift` (self-extend)

**`@NSApplicationDelegateAdaptor` placement** — add before `@State` block (line 16):
```swift
// Before existing @State declarations:
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

**New WindowGroup for onboarding** — copy workspace WindowGroup pattern (FlintApp.swift lines 47-58):
```swift
// Existing workspace WindowGroup (lines 47-58):
WindowGroup(id: "workspace") {
    MainWindowView()
        .environment(historyStore)
        .environment(prefs)
        // ... other environments
}
.defaultSize(width: 900, height: 650)
.commandsRemoved()

// New onboarding WindowGroup — minimal environments, fixed size:
WindowGroup(id: "onboarding") {
    OnboardingWindowView()
        .environment(prefs)
        .preferredColorScheme(prefs.theme.colorScheme)
}
.defaultSize(width: 480, height: 360)
.windowResizability(.contentSize)
.commandsRemoved()
```

**Service notification receiver** — copy `.onReceive` pattern from MenuBarPopoverView.swift line 136:
```swift
// Existing .onReceive in MenuBarPopoverView:
.onReceive(NotificationCenter.default.publisher(for: .showPopover)) { _ in
    clipboard.isPopoverPresented = true
}

// New .onReceive blocks for Services routing (add to MenuBarExtra content):
.onReceive(NotificationCenter.default.publisher(for: .serviceDidReceiveText)) { notification in
    guard let text = notification.userInfo?["text"] as? String else { return }
    if let result = toolRegistry.detect(from: text) {
        toolSeed.set(toolId: result.toolId, value: text)
        WindowCoordinator.shared.openToolViaService(toolId: result.toolId)
        // Navigate to the tool via a published state change (mirrors clipboard accept in MenuBarPopoverView)
    } else {
        // No-match: open launcher with text staged in search field
        WindowCoordinator.shared.openLauncherWithStagedText(text)
    }
}

.onReceive(NotificationCenter.default.publisher(for: .openOnboarding)) { _ in
    // openWindow is @Environment in FlintApp scenes via WindowGroup id:
}
```

**Onboarding gate** — `.onAppear` on MenuBarExtra content (mirrors `clipboard.start(registry:)` call at MenuBarPopoverView.swift line 129):
```swift
.onAppear {
    if !prefs.hasSeenOnboarding {
        WindowCoordinator.shared.openOnboarding()
        // openWindow(id: "onboarding") called from the .onReceive handler above
    }
}
```

---

### `UI/OnboardingWindowView.swift` (UI component / window, request-response)

**Analog:** `UI/PreferencesView.swift`

**Environment injection pattern** (PreferencesView.swift lines 10-14):
```swift
struct PreferencesView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(HotkeyManager.self) private var hotkeyManager
    @Environment(HistoryStore.self) private var historyStore
```

OnboardingWindowView only needs `prefs`:
```swift
struct OnboardingWindowView: View {
    @Environment(PreferencesStore.self) private var prefs
```

**`windowWillClose()` in `.onDisappear`** (PreferencesView.swift lines 42-48):
```swift
// PreferencesView uses .onDisappear to restore .accessory:
.onDisappear {
    WindowCoordinator.shared.windowWillClose()
}
// OnboardingWindowView does the same:
.onDisappear {
    WindowCoordinator.shared.windowWillClose()
}
```

**Launch-at-login toggle** — copy exact pattern from PreferencesView.swift GeneralPreferencesTab lines 63-66:
```swift
@Bindable var prefs = prefs
// ...
Toggle("Launch at login", isOn: $prefs.launchAtLogin)
    .accessibilityLabel("Launch Flint at login")
    .help("Automatically start Flint when you log in to your Mac.")
```

**Window sizing** — fixed, not resizable (contrast with PreferencesView's `minWidth: 460, minHeight: 340`):
```swift
.frame(width: 480, height: 360)
// Pair with .windowResizability(.contentSize) in WindowGroup declaration in FlintApp
```

**Dismiss + set flag pattern:**
```swift
Button("Get Started") {
    prefs.hasSeenOnboarding = true
    // Close via environment dismiss (works for WindowGroup-based windows):
    dismiss()
}
// @Environment(\.dismiss) private var dismiss
```

**Accessibility pattern** — copy from WarningBannerView.swift lines 46-49:
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("...")
```

---

### `UI/Components/DropOverlayView.swift` (UI component / overlay, event-driven)

**Analog:** `UI/Components/WarningBannerView.swift`

**Stateless View struct with severity-tinted appearance** (WarningBannerView.swift lines 13-49):
```swift
struct WarningBannerView: View {
    let message: String
    let severity: BannerSeverity

    private var tintColor: Color {
        switch severity {
        case .warning: return .yellow
        case .error:   return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundColor(tintColor)
                .font(.system(size: 13))
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tintColor.opacity(0.15))
        .cornerRadius(6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
```

**DropOverlayView adapts this pattern as a full-surface overlay:**
```swift
struct DropOverlayView: View {
    // No stored properties — stateless, shown/hidden by isTargeted binding in parent
    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.12)
            VStack(spacing: 8) {
                Image(systemName: "doc.fill.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                Text("Drop file to load")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drop file to load")
    }
}
```

**`.isTargeted` overlay composition pattern** — the parent view uses SwiftUI overlay modifier, NOT a ZStack:
```swift
// Parent tool view adds:
.overlay {
    if isDragTargeted {
        DropOverlayView()
            .transition(.opacity.animation(.easeOut(duration: 0.12)))
    }
}
```

---

### `.onDrop` additions to tool views + launcher (modifier, file-I/O)

**Analog (binary tools):** `Tools/Base64/Base64ViewModel.swift` `encodeFileChunked` (lines 208-233) + `Tools/Hash/HashViewModel.swift` `startFileHash` (lines 105-136)

**Analog (text tools):** `Tools/Base64/Base64ViewModel.swift` `encodeFile` Task.detached pattern (lines 189-204)

**Off-main file processing pattern to copy** (Base64ViewModel.swift lines 188-205):
```swift
isProcessingFile = true
fileErrorMessage = nil

Task.detached(priority: .userInitiated) { [weak self] in
    do {
        let encoded = try await Self.encodeFileChunked(url: url, urlSafe: false)
        await MainActor.run { [weak self] in
            self?.isProcessingFile = false
            self?.output = encoded
            self?.outputDimmed = false
            self?.errorMessage = nil
        }
    } catch {
        await MainActor.run { [weak self] in
            self?.isProcessingFile = false
            self?.fileErrorMessage = "Could not read file"
        }
    }
}
```

**Error path uses `WarningBannerView`** (same mechanism already in place — see WarningBannerView.swift). Text tool ViewModels expose an `errorMessage: String?` property (see Base64ViewModel.swift line 29); text tools call:
```swift
await MainActor.run {
    viewModel.errorMessage = "File contains non-text data. Try Base64 or Hash."
}
```

**`onDrop` modifier placement** — add to root `VStack` of each tool view (analogous to how keyboard shortcut buttons are added to `.background()` in MenuBarPopoverView.swift lines 141-226):
```swift
@State private var isDragTargeted = false

// On root VStack of tool view:
.onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
    guard let provider = providers.first else { return false }
    _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
        guard let data = item as? Data,
              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
        Task {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                await MainActor.run { viewModel.input = text }   // triggers existing didSet → transform
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = "File contains non-text data. Try Base64 or Hash."
                }
            }
        }
    }
    return true
}
.overlay {
    if isDragTargeted {
        DropOverlayView()
            .transition(.opacity.animation(.easeOut(duration: 0.12)))
    }
}
```

**Binary tool drop (Base64, Hash)** — resolve URL then call existing entry point:
```swift
// HashViewModel already has startFileHash(url: URL) at line 105.
// Base64ViewModel has encodeFile() opening NSOpenPanel — add a parallel loadFile(url:) entry point.
// Pattern: resolve URL from drop → call existing off-main pipeline.
_ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
    guard let data = item as? Data,
          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
    Task { @MainActor in
        viewModel.startFileHash(url: url)   // existing method, no change
    }
}
```

---

## Shared Patterns

### Activation-Policy Dance
**Source:** `App/WindowCoordinator.swift` lines 18-50
**Apply to:** `openOnboarding()`, `openToolViaService()`, `openLauncherWithStagedText()` — all three new WindowCoordinator methods must follow the identical `.accessory → .regular → activate → 0.1s delay → post notification → restore .accessory on close` sequence.
```swift
windowCount += 1
NSApp.setActivationPolicy(.regular)
NSApp.activate(ignoringOtherApps: true)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    NotificationCenter.default.post(name: .<notificationName>, object: nil)
}
// Restore in windowWillClose() — already implemented, just call it from new windows' .onDisappear
```

### `@Observable @MainActor final class` Service Pattern
**Source:** `Core/Services/HotkeyManager.swift` lines 21-31, `Core/Services/ClipboardDetector.swift` lines 11-13
**Apply to:** `SparkleUpdaterService.swift`
All project services use this triple: `@Observable`, `@MainActor`, `final class`. No exceptions.

### Notification-Based Decoupling
**Source:** `Core/Services/HotkeyManager.swift` lines 25-28 (posts `.showPopover`) + `App/MenuBarPopoverView.swift` line 136 (receives via `.onReceive`)
**Apply to:** `FlintServiceProvider` → `FlintApp` bridge, onboarding open trigger.
The pattern: NSObject/background-thread source posts a `NotificationCenter` notification → `FlintApp` or a SwiftUI view receives via `.onReceive(NotificationCenter.default.publisher(for:))` on `@MainActor`.

### UserDefaults Bool Key Pattern
**Source:** `Core/Services/PreferencesStore.swift` lines 72-74 (`showInDock`)
**Apply to:** `hasSeenOnboarding` key in `PreferencesStore`.
```swift
var flagName: Bool {
    get { defaults.object(forKey: Keys.flagName) as? Bool ?? false }
    set { defaults.set(newValue, forKey: Keys.flagName) }
}
// Key string follows "lathe.<keyName>" convention (Keys enum, line 224+)
```

### Error State via `errorMessage: String?`
**Source:** `Tools/Base64/Base64ViewModel.swift` line 29, `Tools/Hash/HashViewModel.swift` line 41
**Apply to:** Drop error path in all tool ViewModels.
Tool views already display `errorMessage` via `WarningBannerView` or `InlineErrorView`; the drop handler sets `viewModel.errorMessage` to surface errors without adding any new UI components.

### `@Bindable` in SwiftUI Forms
**Source:** `UI/PreferencesView.swift` line 58 (`@Bindable var prefs = prefs`)
**Apply to:** `OnboardingWindowView` when binding to `prefs.launchAtLogin` and `prefs.hasSeenOnboarding`.
```swift
@Bindable var prefs = prefs
Toggle("Launch at login", isOn: $prefs.launchAtLogin)
```

### `Task.detached` for File I/O Off-Main
**Source:** `Tools/Base64/Base64ViewModel.swift` lines 188-205
**Apply to:** Text file loading in drop handler (via `Task` with `await MainActor.run`), binary file routing to existing `startFileHash(url:)` / `encodeFileChunked` pipelines.
Never read files on `@MainActor` — always `Task { ... await MainActor.run { ... } }` or `Task.detached`.

---

## No Analog Found

All files have close analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively.

| File | Note |
|------|------|
| `Core/Services/SparkleUpdaterService.swift` | SPUStandardUpdaterController is new external API (Sparkle 2.9.3); the class shell copies HotkeyManager exactly, but the Sparkle-specific init/method calls come from RESEARCH.md Pattern 3 (sparkle-project.org/documentation). |
| `App/AppDelegate.swift` | `NSApplicationDelegate` + `servicesProvider` is AppKit with no prior analog in this codebase; structural pattern comes from HotkeyManager, implementation details from RESEARCH.md Pattern 1. |

---

## Metadata

**Analog search scope:** `App/`, `Core/Services/`, `UI/`, `UI/Components/`, `Tools/Base64/`, `Tools/Hash/`
**Files scanned:** 13 Swift source files read in full
**Key patterns identified:**
- All new services: `@Observable @MainActor final class` shell (HotkeyManager / ClipboardDetector)
- All window opening: activation-policy dance in WindowCoordinator (copy `openWorkspace()` exactly)
- Cross-thread work: notification-post from NSObject handler → `.onReceive` on SwiftUI `@MainActor`
- File I/O: `Task.detached` + `await MainActor.run` (Base64ViewModel / HashViewModel)
- Error display: set `viewModel.errorMessage` → existing `WarningBannerView` renders it
- Preference flags: `defaults.object(forKey:) as? Bool ?? false` with `"lathe."` key prefix
**Pattern extraction date:** 2026-06-26
