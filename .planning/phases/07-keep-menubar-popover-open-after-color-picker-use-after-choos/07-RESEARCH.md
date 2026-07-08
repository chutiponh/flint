# Phase 7: Keep menubar popover open after color picker use - Research

**Researched:** 2026-07-08
**Domain:** AppKit window/key-status lifecycle vs. SwiftUI `MenuBarExtra(.window)` + MenuBarExtraAccess
**Confidence:** HIGH (mechanism verified from actual MenuBarExtraAccess 1.3.0 package source in the local SPM checkout) / MEDIUM (exact NSColorSampler/NSColorPanel key-window semantics — cross-verified via multiple community sources, no direct Apple doc text retrievable this session)

## Summary

The root cause is fully diagnosable from the vendored **MenuBarExtraAccess 1.3.0** source, which is checked out locally at
`~/Library/Developer/Xcode/DerivedData/Flint-*/SourcePackages/checkouts/MenuBarExtraAccess/Sources/MenuBarExtraAccess/MenuBarExtraAccess.swift`.
The package installs its own `NSWindow.didResignKeyNotification` observer on the popover's backing window (`MenuBarExtraAccess.swift` lines 190–218). That
handler is **unconditional**: whenever the popover window resigns key, it calls `window.close()` "as a failsafe" and then force-sets
`isMenuPresented = false` on the caller's binding — regardless of what value the app itself is currently holding in `clipboard.isPopoverPresented`.
**This means D-02's literal reading ("hold `isPopoverPresented` true / suppress the resign-key close") cannot be implemented by manipulating the binding
alone.** Holding the binding `true` does not stop the package's internal observer from closing the window; the binding will simply be overwritten back to
`false` by the package immediately after `window.close()` fires. There is no public API on `MenuBarExtraAccess` (or on SwiftUI's `MenuBarExtra`) to disable
or intercept that observer.

Given this ceiling, the only two viable levers are: (1) **prevent the resign-key from happening in the first place** by never letting the picker's window
steal key status, or (2) **re-present** (`isPopoverPresented = true` again) immediately after the forced close, driven by the picker's own lifecycle
notifications. Lever (1) is fully available for the eyedropper — `NSColorSampler` is a private, transient overlay (confirmed zero-permission, async
completion handler, WWDC 2019 session 210) that multiple community sources report as NOT reliably stealing app key-window status the way a normal window
does; empirically this needs a UAT check but the safe default is to treat lever (2) as the reliable path for both pickers since it requires no assumptions
about picker-specific key-window semantics. Lever (1) is **not available** for `NSColorPanel` in a supported way: `ColorPicker` creates and owns the shared
`NSColorPanel` internally: the app cannot subclass or change its style mask (would require private-API window swizzling, explicitly out of scope for a
"laziest reliable mechanism" project constraint). `NSColorPanel` genuinely becomes key window while open (confirmed via multiple cross-referenced sources
on `NSPanel`/`NSColorPanel` `.floating` level + no `.nonactivatingPanel` style mask by default), so its `didBecomeKeyNotification` fires and the popover's
`didResignKeyNotification` fires in response — this is the D-04 trigger that needs to keep re-presenting for the panel's ENTIRE open lifetime, not once.

**Primary recommendation:** Implement lever (2) — a "re-present on close" pattern — for both pickers, driven by two different signal sources: the
`NSColorSampler.show` completion handler (fires once, after the pick) for the eyedropper, and `NSColorPanel`'s own `isVisible` state polled via
`NSWindow.didBecomeKeyNotification` / `.didResignKeyNotification` / `.willCloseNotification` observers (fires repeatedly, for the panel's full open
duration) for D-04. This reuses `clipboard.isPopoverPresented` exactly as `WindowCoordinator.openToolViaService` and Pitfall #3 already do — no new
plumbing, no window subclassing, no private API. Use `introspectMenuBarExtraWindow` (already provided by MenuBarExtraAccess, currently unused in the
codebase) only if UAT reveals a race where re-presenting via the binding is not fast enough to avoid visible flicker; it exposes the actual `NSWindow` so a
direct `window.makeKeyAndOrderFront` call could be issued instead of a full SwiftUI-cycle re-present. Start without it — it is not required for the
mechanism to work.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Detect popover force-close (resign-key) | App shell (FlintApp / WindowCoordinator-adjacent) | — | Must observe `NSWindow` notifications on the popover's own backing window, which only the app shell has a stable handle to via `introspectMenuBarExtraWindow` or the existing `isPopoverPresented` binding cycle |
| Suppress/absorb the eyedropper's transient key-status change | Tool view (`ColorView.swift`) | App shell fallback | The eyedropper call site is local to `ColorView`; the completion handler is the natural place to trigger re-present, no cross-cutting state needed |
| Track NSColorPanel open/close for the FULL panel lifetime (D-04) | App shell (new lightweight coordinator OR `ColorViewModel`) | Tool view | `NSColorPanel.shared` is a process-wide singleton — its visibility notifications are not scoped to `ColorView`; observing them where the popover-survival logic lives (near `isPopoverPresented`) avoids splitting responsibility across two owners |
| Apply the picked `NSColor` to canonical RGBA | `ColorViewModel` | — | Already implemented (`updateFromNSColor`) — untouched by this phase |
| Popover presentation state | `ClipboardDetector.isPopoverPresented` (existing) | — | Single existing lever for programmatic show/dismiss — reused, not replaced |

## Standard Stack

### Core
No new dependencies. This phase is 100% AppKit/SwiftUI system API + the already-installed `MenuBarExtraAccess` 1.3.0 package.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MenuBarExtraAccess | 1.3.0 (pinned, already installed) | `isPresented` binding for `.window`-style `MenuBarExtra` | Already a project dependency (CLAUDE.md); confirmed via `Package.resolved` |
| AppKit (`NSColorSampler`, `NSColorPanel`, `NSWindow` notifications) | macOS 14.0+ | Picker invocation + key-window lifecycle observation | System framework, zero footprint, matches CLAUDE.md's native-first stance |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Notification-driven re-present | Subclass/swizzle the popover's `NSWindow` to override `resignKey()` | Requires private-API access to the SwiftUI-internal `MenuBarExtraWindow` class (confirmed only reachable via KVC/Mirror reflection in the package's own source — explicitly documented as fragile ("Note: this is not ideal, but it's currently the ONLY way")); rejected — violates "laziest reliable mechanism" and CLAUDE.md's non-hand-rolled preference |
| Notification-driven re-present | Custom `NSPanel` subclass with `.nonactivatingPanel` replacing `NSColorPanel.shared` | `ColorPicker` does not expose a way to substitute its internal panel; would require abandoning SwiftUI `ColorPicker` for a hand-rolled `NSViewRepresentable` wrapping `NSColorWell`/custom panel — large scope increase for a UX-polish phase; rejected |
| Notification-driven re-present | `introspectMenuBarExtraWindow` + direct `window.makeKeyAndOrderFront` | Viable *upgrade path* if notification-cycle re-present has visible flicker in UAT — keep in back pocket, not the initial implementation |

**Installation:** None — no new packages.

## Package Legitimacy Audit

Not applicable — this phase adds zero new external packages. `MenuBarExtraAccess` was already vetted and pinned (`Package.resolved`, version 1.3.0, `orchetect/MenuBarExtraAccess`, revision `33bb0e4b1e407feac791e047dcaaf9c69b25fd26`) prior to this phase; no re-audit required per the Package Legitimacy Gate protocol (which triggers only on *new* installs).

## Architecture Patterns

### System Architecture Diagram

```
User clicks eyedropper button (ColorView.swatchSection)
        │
        ▼
NSColorSampler().show { nsColor in ... }   ── async, main-thread completion
        │                                     (screen-overlay window may or may not
        │                                      steal key status — verify in UAT)
        ▼
   [If popover's NSWindow resigned key at any point during the overlay's
    lifetime → MenuBarExtraAccess's internal didResignKeyNotification
    observer force-closes the window AND sets isPopoverPresented = false]
        │
        ▼
Completion handler fires:
  1. viewModel.updateFromNSColor(nsColor)   (existing — unchanged)
  2. clipboard.isPopoverPresented = true    (NEW — re-present, D-03 mechanism
                                              reused as the D-02 delivery path)

─────────────────────────────────────────────────────────────

User clicks ColorPicker swatch (ColorView.swatchSection)
        │
        ▼
SwiftUI ColorPicker opens NSColorPanel.shared  ── becomes key window (floating panel)
        │
        ▼
Popover's NSWindow resigns key
        │
        ▼
MenuBarExtraAccess didResignKeyNotification observer:
  window.close() + isMenuPresented = false      (unconditional — cannot be suppressed)
        │
        ▼
NEW: App-level NSColorPanel open/close observer (installed once, e.g. in
     ColorViewModel.init or a small coordinator) detects panel is STILL
     visible (isVisible == true) and re-presents:
        clipboard.isPopoverPresented = true
        │
        ▼
[Loop: every time the panel regains key focus after a transient
 resign — e.g. user clicks elsewhere then back on the panel — the
 popover may resign key again; the observer keeps re-presenting for
 as long as NSColorPanel.shared.isVisible == true (D-04)]
        │
        ▼
NSColorPanel.shared closes (user clicks the panel's close button)
        │
        ▼
willCloseNotification observed → stop re-presenting; leave popover
in whatever state isPopoverPresented naturally settles to (open,
per D-04 "stays open the whole time")
```

### Recommended Project Structure
No new files strictly required — the pattern fits inside existing files:
```
Tools/Color/
├── ColorView.swift        # eyedropper completion handler gets the 1-line re-present
├── ColorViewModel.swift   # NEW: NSColorPanel open/close observers (owns the picker's
│                          #      full-lifetime state, mirrors updateFromNSColor's role
│                          #      as "where picker events land")
App/
├── WindowCoordinator.swift # optional: add a documented Pitfall #N entry once implemented,
                             # mirroring the existing Pitfall #3 prior art
```

### Pattern 1: Re-present after eyedropper completion (D-02/D-03 for NSColorSampler)
**What:** Since the popover MAY be force-closed by MenuBarExtraAccess's internal resign-key observer during the sampler overlay, unconditionally
re-assert `isPopoverPresented = true` in the `NSColorSampler` completion handler, immediately after applying the picked color. This is idempotent — if the
popover never actually closed (because the sampler didn't steal key status), setting `isPopoverPresented = true` when it's already `true` is a no-op per
the package's `setPresented` (`MenuBarExtraUtils.swift` — it compares `currentState` and only toggles if the value differs).
**When to use:** Every `NSColorSampler().show { }` completion, unconditionally — cheap and safe whether or not the close actually happened.
**Example:**
```swift
// Source: existing ColorView.swift §141-146 + ClipboardDetector.isPopoverPresented (Core/Services/ClipboardDetector.swift)
Button {
    NSColorSampler().show { nsColor in
        guard let nsColor else { return }
        viewModel.updateFromNSColor(nsColor)
        clipboard.isPopoverPresented = true   // NEW: re-present unconditionally (D-03 mechanism)
    }
} label: {
    Label("Pick color from screen", systemImage: "eyedropper")
        .labelStyle(.iconOnly)
        .frame(width: 28, height: 28)
}
```
`clipboard` is already available in `ColorContentView` via `@Environment(ClipboardDetector.self) private var clipboard` (see existing usage at
`ColorView.swift` line 235 inside `formatRowsSection`'s `.onReceive(.selectOutputRow)` handler) — no new environment plumbing needed.

### Pattern 2: Track NSColorPanel's full open lifetime for continuous re-present (D-04)
**What:** Install `NotificationCenter` observers for `NSWindow.didResignKeyNotification` / `.didBecomeKeyNotification` scoped to `NSColorPanel.shared`
(filter `notification.object as? NSWindow === NSColorPanel.shared`), plus `.willCloseNotification` to know when to stop. While the panel `isVisible`,
every time the *popover's* window resigns key (detected indirectly — the popover's `isPopoverPresented` binding flips to `false` because the package's
own observer already forced that), re-assert `isPopoverPresented = true`. The simplest robust implementation: whenever `clipboard.isPopoverPresented`
transitions to `false` AND `NSColorPanel.shared.isVisible == true`, immediately re-set it to `true`. This makes `ClipboardDetector` (or a thin wrapper)
the single place that encodes "don't let the popover die while the color panel is up" — no separate observer needed on the panel's key-notifications at
all, since we only care about the *effect* (popover closed) not the *cause*.
**When to use:** Install once at popover/view-model lifetime (e.g. `ColorViewModel.init` or a `.onAppear` in `ColorContentView`), tear down on
`.onDisappear` to avoid leaking an observer when the Color tool isn't the active view.
**Example:**
```swift
// Illustrative — actual implementation decision for planner: where this observer lives
// (ColorViewModel vs. a dedicated small coordinator) is Claude's discretion per CONTEXT.md.
import AppKit
import Combine

// Option A: didSet-based watchdog on the existing ClipboardDetector (minimal diff, D-04 friendly)
// Core/Services/ClipboardDetector.swift — conceptual addition, NOT a locked implementation:
var isPopoverPresented: Bool = false {
    didSet {
        if isPopoverPresented {
            checkPasteboard(force: true)
        } else {
            detectionResult = nil
            // D-04: if the system Color Panel is still open, the popover must not stay closed.
            if NSColorPanel.shared.isVisible {
                isPopoverPresented = true   // re-present immediately; re-enters didSet, isPopoverPresented already true → no infinite loop (guarded by `if isPopoverPresented` branch above running its idempotent re-check path)
            }
        }
    }
}
```
This "watchdog on the falling edge" pattern is deliberately narrow: it does not need to know *why* the popover closed (eyedropper, ColorPanel, or a
genuine user-initiated dismiss) — it only refuses to let it stay closed while `NSColorPanel.shared.isVisible` is true. A genuine user click-away while the
panel is closed passes through untouched.
**Caution — user-initiated dismiss while panel is open:** If the user explicitly wants to dismiss the popover while the ColorPanel is still floating
(e.g. clicking away), this watchdog will fight them and re-open it, by design per D-04 ("stays open the whole time"). This is the locked behavior, not a
bug — but the planner should have a task that explicitly UAT-verifies this is the desired final UX for the click-elsewhere case, since D-04 does not
explicitly address user-initiated dismiss-while-panel-open as a distinct case from "the picker itself takes key focus."

### Anti-Patterns to Avoid
- **Subclassing/swizzling the popover's internal `MenuBarExtraWindow`:** The package's own source (`MenuBarExtraUtils.swift` lines 341–348, 300–310)
  documents that even *reading* metadata off this window requires `Mirror`/KVC reflection into private SwiftUI internals, with an explicit code comment
  "this is not ideal, but it's currently the ONLY way." Overriding its `resignKey()`/`close()` behavior would require far more fragile private-API
  interception. Rejected per the "laziest reliable mechanism" project directive.
- **Trying to prevent `NSColorPanel` from becoming key window:** `ColorPicker` owns `NSColorPanel.shared` creation; there is no supported SwiftUI or
  AppKit hook to force it into `.nonactivatingPanel` / `becomesKeyOnlyIfNeeded = true` mode without replacing `ColorPicker` entirely with a custom
  `NSViewRepresentable`. Out of scope for this phase (CONTEXT.md scope boundary: "Not touching color conversion, format output, or the Color tool's UI").
- **Setting `isPopoverPresented = true` inside a tight polling loop / Timer:** Unnecessary — event-driven (`didSet` on the existing observable property,
  or `NotificationCenter` observers) is zero-cost when idle and reacts instantly, matching the project's stated 0% idle CPU pattern precedent
  (`ClipboardDetector`'s own doc comment: "Uses NSPasteboardDidChangeNotification (0% idle CPU)").

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Programmatic popover show/dismiss for `.window`-style `MenuBarExtra` | Custom `NSStatusItem` + `NSPopover` management (abandoning `MenuBarExtra`) | `MenuBarExtraAccess`'s `isPresented` binding (already installed) | SwiftUI has no native API for this (FB10185203, confirmed still true); the package is already the project's chosen solution, don't re-architect around this phase's problem |
| Detecting "is the system color panel currently open" | Custom NSApplication-wide window-scanning helper | `NSColorPanel.shared.isVisible` | Direct, documented AppKit property — zero reason to scan `NSApp.windows` when the singleton exposes this directly |
| Re-showing a force-closed `.window` `MenuBarExtra` | Manual `NSWindow` `makeKeyAndOrderFront` + z-order/positioning math | Re-toggle the existing `isPopoverPresented` binding | The package's `setPresented`/`togglePresented` already handles the correct `NSStatusItem.button?.performClick` sequence that properly resets internal state (`button?.state`, highlight, etc.) — bypassing it with raw `NSWindow` calls would desync the package's internal book-keeping (`setKnownPresented`) |

**Key insight:** Every piece of this problem already has a system-level or package-level primitive; the phase's job is *sequencing* those primitives
(watch for close → re-assert), not building new window-management infrastructure.

## Common Pitfalls

### Pitfall 1: Assuming `isPopoverPresented = true` prevents the close
**What goes wrong:** Developer sets `clipboard.isPopoverPresented = true` right before invoking the picker (or holds it true across the call) expecting
this to "pin" the window open, and is confused when the popover still visibly closes.
**Why it happens:** The close is driven by an independent `NSWindow.didResignKeyNotification` observer installed *inside* `MenuBarExtraAccess`
(`MenuBarExtraAccess.swift` lines 200–217) that calls `window.close()` directly on the `NSWindow`, then force-sets the bound `Bool` to `false` via
`isMenuPresented = false`. This observer does not consult the current value of `isMenuPresented`/`isPopoverPresented` before acting — it is a one-way
"resign key → always close" rule, not a two-way sync.
**How to avoid:** Treat every close as guaranteed to happen once key status is lost; the only lever is *reacting* to the close (re-present), not
preventing it via the binding.
**Warning signs:** Popover flickers closed then instantly reopens (expected under the re-present pattern) vs. popover stays permanently closed despite
"looks correct" binding code (indicates the re-present trigger isn't firing — check the completion handler/observer wiring, not the binding logic).

### Pitfall 2: Re-present logic creates an infinite re-open loop on legitimate user dismiss
**What goes wrong:** If the "re-present when it closes" logic is too broad (e.g. "always re-present on any close"), a user's normal click-outside-to-dismiss
gesture gets fought by the app and the popover refuses to close at all.
**Why it happens:** `didResignKeyNotification` fires for ALL causes of losing key status, not just picker-related ones — including the user clicking
another app, clicking the menu bar icon again, or Cmd-Tab.
**How to avoid:** Gate the re-present strictly on picker-specific state: for the eyedropper, only re-present inside its own completion handler (naturally
scoped — fires once per invocation, cannot mis-fire for unrelated dismissals). For the ColorPanel, gate on `NSColorPanel.shared.isVisible == true` at the
moment of the close — once the user closes the panel, `isVisible` becomes `false` and the watchdog stops re-asserting, so a subsequent legitimate
click-away dismisses normally.
**Warning signs:** Popover cannot be dismissed at all after ever having opened the ColorPicker once (even after the panel is long closed) — indicates the
gate condition isn't re-evaluating `isVisible` fresh on each close, or the observer wasn't torn down.

### Pitfall 3: Observer registered multiple times (leak / multiplied re-present calls)
**What goes wrong:** If the `NSColorPanel` watchdog (Pattern 2) is installed via `.onAppear` without a matching guard, opening/closing the Color tool
repeatedly re-registers `NotificationCenter` observers, causing the re-present call to fire N times per close after N tool visits.
**Why it happens:** This is a documented anti-pattern already caught once in this exact codebase — `ClipboardDetector.start()`'s own doc comment: "CR-02:
remove existing observer before re-registering to prevent multiplied handlers... without this guard, N appearances → N active observers → N redundant
handler invocations per change."
**How to avoid:** If implementing via `didSet` on an `@Observable` property (Pattern 2's Option A), there is no separate observer lifecycle to manage —
it's just a property observer, immune to this class of bug. If implementing via explicit `NotificationCenter.addObserver` (only needed if watching
`NSColorPanel`'s own become/resign-key directly rather than piggybacking on the existing `isPopoverPresented` `didSet`), follow the exact CR-02 guard
pattern already established in `ClipboardDetector.start()`.
**Warning signs:** Debug log (`MENUBAREXTRAACCESS_DEBUG_LOGGING`) shows the resign-key/re-present cycle firing multiple times per single actual close
event.

### Pitfall 4: Eyedropper's transient overlay behavior is unverified in this exact configuration
**What goes wrong:** Planning assumes `NSColorSampler` definitely steals key status (or definitely doesn't) without confirming against this specific
`.window`-style `MenuBarExtra` + MenuBarExtraAccess combination.
**Why it happens:** `NSColorSampler` is documented (WWDC 2019 session 210, Apple docs metadata) as a zero-permission async overlay, but no source found
in this research session states definitively whether its presentation affects `NSApp`'s key window the same way a standard `NSWindow`/`NSPanel` does —
some community reports (Damian Mehers' `keyWindow` blog post found in this research) note popups can set `keyWindow` to `nil` transiently even for
non-panel UI.
**How to avoid:** Apply the eyedropper's re-present unconditionally (Pattern 1) regardless of whether the close is confirmed to happen — it's a no-op
if the popover never actually closed (verified: `MenuBarExtraUtils.setPresented` short-circuits when `state == currentState`), so there's no cost to
"defensive" re-present here. This sidesteps the need to definitively resolve the open question before planning.
**Warning signs:** N/A for planning purposes — this pitfall is resolved by making the fix unconditionally safe rather than requiring the answer.

## Code Examples

### Existing re-present prior art in this codebase (WindowCoordinator §66-77)
```swift
// Source: App/WindowCoordinator.swift, existing code — Pitfall #3 prior art for D-03
/// Open the menubar popover positioned on the matched tool (DIST-01, retained per user decision).
/// Copies openWorkspace()'s activation-policy dance so the popover appears above the source app
/// (Pitfall #3). The popover is presented via the existing MenuBarExtraAccess isPopoverPresented
/// binding driven by .showPopover.
func openToolViaService(toolId: String) {
    windowCount += 1
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(name: .showPopover, object: nil)
    }
}
```
Note: this existing pattern re-presents via a `NotificationCenter` post that (elsewhere, not shown in the read excerpt) presumably sets
`clipboard.isPopoverPresented = true`. This phase's re-present is simpler — no activation-policy dance is needed since the app is already active/frontmost
(the picker was invoked from within the already-open popover), so a direct `clipboard.isPopoverPresented = true` assignment is sufficient; the
`NSApp.setActivationPolicy(.regular)` dance in `WindowCoordinator` exists to solve a *different* problem (bringing the app forward from an external
trigger like macOS Services), not applicable here.

### MenuBarExtraAccess's internal force-close (why the fix must be reactive, not preventive)
```swift
// Source: MenuBarExtraAccess 1.3.0 package source (local SPM checkout),
// Sources/MenuBarExtraAccess/MenuBarExtraAccess.swift lines 200-217
didResignKey: { window in
    // it's possible for a window to resign key without actually closing, so let's
    // close it as a failsafe.
    if window.isVisible {
        window.close()
    }
    MenuBarExtraUtils.setKnownPresented(for: .index(index), state: false)
    isMenuPresented = false
}
```
This is unconditional — it does not check any state the app controls before running. This is the single most load-bearing fact for this phase's plan: any
task that assumes the binding alone can suppress the close should be rejected in plan review.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| N/A — this is a narrow, currently-unsolved gap in `MenuBarExtra`/`MenuBarExtraAccess`, not a case of an outdated pattern being replaced | Reactive re-present pattern (this research's recommendation) | N/A | No 1st-party or widely-documented 3rd-party fix exists for `.window`-style `MenuBarExtra` losing focus to system pickers; this project must establish its own pattern (confirmed no matching GitHub issues/discussions found on `orchetect/MenuBarExtraAccess`) |

**Deprecated/outdated:** None identified — the relevant APIs (`NSColorSampler`, `NSColorPanel`, `MenuBarExtra`, `MenuBarExtraAccess` 1.3.0) are all current
as of macOS 14+/Xcode 16+.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSColorSampler`'s transient overlay may or may not actually cause the popover's `NSWindow` to resign key in this exact `.window`-style `MenuBarExtra` + MenuBarExtraAccess 1.3.0 configuration — not directly confirmed against Apple's official doc text this session (WebFetch returned only page titles, not body text, for `developer.apple.com/documentation/appkit/nscolorsampler`) | Pitfall 4, Summary | Low — the recommended fix (Pattern 1, unconditional re-present) is a no-op if the assumption is wrong, so no plan changes needed regardless of the answer; flagged only for completeness |
| A2 | `NSColorPanel.shared` defaults to `isFloatingPanel = true`, `level = .floating`, and does NOT default to `.nonactivatingPanel`/`becomesKeyOnlyIfNeeded = true` — sourced from community/WebSearch synthesis (Fazm Blog, philz.blog "Curious Case of NSPanel's Nonactivating Style Mask Flag"), NOT confirmed against literal Apple doc body text this session | Summary, Architecture Patterns, Pitfall 4 | Medium — if `NSColorPanel` turns out to NOT reliably become key window in practice, the D-04 "continuous re-present while panel open" mechanism (Pattern 2) may fire more or less often than expected; the `isVisible`-gated watchdog design is robust to either outcome (it only reacts to actual `isPopoverPresented` transitions to `false`, so if the panel never causes a close, the watchdog simply never fires — safe either way) |
| A3 | No existing GitHub issue/discussion on `orchetect/MenuBarExtraAccess` documents this exact ColorPicker/ColorSampler-vs-popover-close interaction — searched via `gh api` (returned empty) and WebFetch on the issues page (confirmed "Issues 0" / issue creation restricted) and discussions | Summary, State of the Art | Low — confirms this project needs to originate its own fix rather than adopt a documented one; does not change the recommended approach |

## Open Questions

1. **Does the eyedropper actually cause a visible close-then-reopen flicker, or does it never resign key at all?**
   - What we know: `NSColorSampler` is a zero-permission async transient overlay (confirmed). MenuBarExtraAccess's force-close is triggered strictly by
     `NSWindow.didResignKeyNotification` on the popover's own window.
   - What's unclear: Whether the sampler's overlay presentation causes `NSApp`'s key window to change away from the popover, or whether it's drawn in a way
     that doesn't compete for key status (some overlay-style system UI, e.g. Spotlight-adjacent panels, don't always take key window).
   - Recommendation: Implement Pattern 1 (unconditional re-present in the completion handler) regardless — it's safe either way. Have the plan include a
     UAT/manual verification task specifically watching for visible flicker on eyedropper use; if flicker is visible, that confirms the close IS happening
     and the fix IS necessary (informational, not blocking).

2. **Does re-presenting via `isPopoverPresented = true` inside `didSet` (Pattern 2, Option A) risk any SwiftUI observation re-entrancy issue, given this
   project's known "@Observable computed UserDefaults pitfall" (per MEMORY.md)?**
   - What we know: The memory note warns specifically about binding SwiftUI controls to *computed* properties on `PreferencesStore` where writes drop.
     `ClipboardDetector.isPopoverPresented` is a stored property with a `didSet`, not a computed property — a different shape.
   - What's unclear: Whether re-entrant assignment inside `didSet` (setting `isPopoverPresented = true` from within its own `didSet` when the new value was
     `false`) is safe under Swift's property-observer semantics, or whether it needs to be deferred (e.g. via `DispatchQueue.main.async`) to avoid
     re-entering `didSet` synchronously mid-observation.
   - Recommendation: Planner should treat this as a small, testable implementation detail — Swift property observers DO support re-entrant assignment
     within `didSet` (it will re-invoke `didSet` for the new assignment, but since the guard is `if isPopoverPresented { ... } else { ...; if condition {
     isPopoverPresented = true } }`, the re-entrant call takes the `if isPopoverPresented` (true) branch which does not recurse further) — this is standard
     Swift behavior, not exotic, but should get a manual verification pass in UAT given the project's history of `@Observable` surprises.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependencies beyond the already-installed Xcode toolchain and the already-vetted
`MenuBarExtraAccess` package (confirmed present in `Package.resolved`). No new installs, no new registry checks required.

## Validation Architecture

Skipped — `.planning/config.json` has `workflow.nyquist_validation: false` explicitly set.

Note for planner: this phase's correctness is fundamentally about AppKit window-focus lifecycle timing, which is not meaningfully unit-testable via
`FlintTests`' existing XCTest suite (confirmed: all 17 existing test files target pure transformers/view-models, none touch `NSWindow`/key-status
behavior). Verification for this phase should be **manual UAT** (open Color tool → eyedropper → confirm popover stays/reopens; open Color tool →
ColorPicker → confirm popover stays open live while adjusting → close panel → confirm normal dismiss still works), not automated tests. The planner should
scope verification tasks accordingly rather than attempting to force this into `FlintTests`.

## Security Domain

`security_enforcement` is not set in `.planning/config.json` (absent = enabled per protocol), but this phase has no auth, session, input-validation-from-
untrusted-source, or cryptography surface — it is pure local UI window-lifecycle logic operating on already-trusted in-process AppKit/SwiftUI state. No
ASVS category applies.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | N/A — no auth surface |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | No | N/A — no external/untrusted input; `NSColor` values come from OS-native pickers, not user-typed strings (unlike `updateFromHex` etc., which are out of scope for this phase) |
| V6 Cryptography | No | N/A |

No STRIDE-relevant threat patterns apply — this is a single-user, offline, non-sandboxed desktop app's window-focus bug fix with no network, no
persistence, and no privilege boundary crossed.

## Sources

### Primary (HIGH confidence)
- MenuBarExtraAccess 1.3.0 package source, local SPM checkout — `Sources/MenuBarExtraAccess/MenuBarExtraAccess.swift` (full file read, 308 lines): the
  `didResignKey`/`didBecomeKey` observer wiring (lines 190–218) is the single most load-bearing finding in this research.
- MenuBarExtraAccess 1.3.0 package source — `Sources/MenuBarExtraAccess/MenuBarExtraUtils/MenuBarExtraUtils.swift` (full file read, 422 lines):
  `setPresented`/`setKnownPresented`/`togglePresented` idempotency behavior (confirms unconditional re-present is safe/cheap).
- MenuBarExtraAccess 1.3.0 package source — `Sources/MenuBarExtraAccess/NSStatusItem Extensions.swift`, `NSWindow Extensions.swift`, `MenuBarExtra Window
  Introspection.swift` (all read in full): confirms `introspectMenuBarExtraWindow` API exists and is currently unused in Flint's codebase (`grep` returned
  zero matches), and confirms `setPresented(state:)`'s short-circuit-on-equal-state logic.
- Flint's own codebase: `App/FlintApp.swift`, `App/WindowCoordinator.swift`, `Core/Services/ClipboardDetector.swift`, `Tools/Color/ColorView.swift`,
  `Tools/Color/ColorViewModel.swift`, `.planning/phases/07-.../07-CONTEXT.md`, `.planning/STATE.md`, `.planning/config.json` — all read directly.

### Secondary (MEDIUM confidence)
- WebSearch: "NSColorSampler show completion handler async main thread screen capture permission" — cross-referenced 3+ independent sources (Stackademic
  blog, Apple doc metadata, WWDC 2019 session 210 transcript) confirming zero-permission, async, main-thread-safe completion.
- WebSearch: "MenuBarExtra window style ColorPicker closes popover NSColorPanel key window workaround Swift" — confirms via Apple Feedback report
  FB11984872 (referenced in `feedback-assistant/reports` issue #383) that `.window`-style `MenuBarExtra` has no 1st-party programmatic dismiss/re-present
  API, consistent with why `MenuBarExtraAccess` exists at all.
- WebSearch cross-reference on `NSColorPanel` default floating/key-window behavior (Fazm Blog "SwiftUI Floating Panel: NSPanel Patterns," philz.blog "The
  Curious Case of NSPanel's Nonactivating Style Mask Flag") — consistent across 2 independent sources but not confirmed against literal Apple doc body
  text (WebFetch on `developer.apple.com/documentation/appkit/nscolorpanel` returned only the page title, not rendered body content, both attempts this
  session).

### Tertiary (LOW confidence)
- WebSearch: Damian Mehers' blog "Detecting when a SwiftUI MenuBarExtra with window style is opened" — noted as a data point that `NSApp.keyWindow`
  observation is a known-fragile technique for MenuBarExtra state detection generally; used only to corroborate that key-window semantics around
  MenuBarExtra popovers are widely reported as finicky, not as a specific technical claim relied upon in the recommendation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; existing `MenuBarExtraAccess` 1.3.0 pin verified directly from `Package.resolved`.
- Architecture (root-cause mechanism): HIGH — read the actual package source performing the force-close; this is not an inference, it's the literal code.
- Architecture (NSColorSampler/NSColorPanel exact key-window semantics in this specific integration): MEDIUM — cross-verified via multiple independent
  community sources, but Apple's own doc body text could not be retrieved this session (WebFetch tool returned only page titles for both
  `NSColorSampler` and `NSColorPanel` doc pages); recommendation is designed to be safe/correct regardless of the exact answer (see Assumptions A1/A2).
- Pitfalls: HIGH — Pitfall 1–3 derive directly from package source code and this codebase's own prior documented pitfall (`ClipboardDetector`'s CR-02
  comment); Pitfall 4 is explicitly flagged as an open question rather than asserted as fact.

**Research date:** 2026-07-08
**Valid until:** 60 days (stable AppKit/SwiftUI APIs + a pinned, already-installed package version; not fast-moving) — re-verify if `MenuBarExtraAccess`
is upgraded past 1.3.0, since a future version could change or remove the unconditional `didResignKey` force-close behavior this research depends on.
