# Phase 3: Polish & Distribution - Context

**Gathered:** 2026-06-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 gets Flint into users' hands. Four deliverables, no new tools:
**(1) macOS Services menu integration** — select text anywhere, route it to the best-matching tool pre-filled (DIST-01).
**(2) File drag-and-drop** — drop text files into any tool, binary files into Base64/Hash (DIST-02).
**(3) Signed/notarized DMG + first-run onboarding** — passes Gatekeeper, greets new users (DIST-03).
**(4) Sparkle auto-update** — EdDSA-signed appcast, v0.0.1→v0.0.2 validated locally before v1.0, public key in Info.plist from first release (DIST-04).

This discussion clarified **HOW** Services routing, drag-and-drop, onboarding, and update cadence behave. The package/tooling stack is already locked in `CLAUDE.md` (Sparkle 2.9.3, `xcrun notarytool`, create-dmg 8.1.0, SMAppService) and is NOT re-decided here. The `ToolSeed` + `ToolRegistry.detect()` mechanism (built Phase 1, see code_context) is the reused substrate for both Services routing and drag-drop pre-fill — frozen, carries forward.

</domain>

<decisions>
## Implementation Decisions

### Carried Forward (apply across Phase 3)
- **CF-01:** Reuse `ToolRegistry.detect(from:)` (first-match-wins chain, Phase 1 D-06) + `ToolSeed.set/consume` (one-shot pre-fill) for BOTH Services routing and launcher-routed drops. No new detection abstraction.
- **CF-02:** Never crash / never freeze the UI on bad input (INFRA-17/18) governs every drop and routed payload — oversized/binary/invalid-UTF-8 handled gracefully, heavy work off-main.
- **CF-03:** Not sandboxed in v1 (PROJECT.md constraint) — Services, arbitrary-file drop, and SMAppService launch-at-login all rely on this. Hardened Runtime is ON (release entitlements already exclude `get-task-allow`).

### Services Menu Routing (DIST-01)
- **D-01:** **One smart entry** in the system Services menu ("Open in Flint" / equivalent) — not per-tool entries. Keeps every app's Services submenu to a single item.
- **D-02:** **Auto-open the best-matched tool, pre-filled.** On Services invoke, run `detect()` on the selected text and open the matched tool immediately via `ToolSeed` — skip the detection banner. Rationale: Services is a deliberate "send to Flint" intent, unlike passive clipboard sniffing (which keeps the D-04 Accept/Dismiss banner). This is an intentional divergence from Phase 1 D-04, scoped to Services.
- **D-03:** **No-match fallback → open the search-first launcher with the text staged** in the search/input area so the user picks a tool manually. Never a dead end; never guesses a wrong tool.

### Drag-and-Drop (DIST-02)
- **D-04:** **Open-tool-only routing.** A file dropped onto an open tool loads into THAT tool. Dropping onto the **launcher** reads the file's text contents, runs `detect()`, and routes to the best tool (mirrors Services D-02). A drop never yanks the user out of a tool they deliberately opened.
- **D-05:** **Whole-surface drop target with a drag-over overlay** ("Drop file to load") — no permanent dedicated drop zone consuming layout in the ~480pt popover. Generous target, zero permanent UI cost.
- **D-06:** **Graceful, async, validated.** Text tools reject binary/oversized files with an inline error banner (reuse `WarningBannerView`) — never crash. Binary tools (Base64 B64-04, Hash HASH-02) process **any** file off-main with progress, reusing the existing chunked-file pipeline. No hard universal size cap — the legitimate large-file-hash path that works today is preserved.

### Onboarding (DIST-03)
- **D-07:** **One focused welcome window on first run** — dismissible, shown once, never again. It must cover the two things a brand-new menubar-app user must know: (a) "Flint lives in your menubar" pointing at the icon (the #1 "where did it go" risk for a no-Dock-icon app), (b) teach the `⌘⇧Space` global hotkey, and (c) a single button to enable Launch at Login (SMAppService). No multi-step carousel.

### Auto-Update (DIST-04)
- **D-08:** **Auto-check in background, prompt to install.** Sparkle checks automatically; on finding an update, show the standard Sparkle prompt with release notes and let the user install (with restart). Sparkle's default behavior — respects user control, well-understood. Not silent auto-install.
- **D-09:** **Single stable channel.** One appcast, stable only. The roadmap's v0.0.1→v0.0.2 step is pipeline-proving on that same channel. No beta/channel opt-in in v1 (YAGNI — add later if a beta audience appears).

### Claude's Discretion
- Exact Services entry label/glyph, the precise no-match staging affordance (search field vs. a generic text input), drag-over overlay styling/animation, the file-size threshold at which a binary tool switches to progress UI, the welcome window's exact copy/layout/illustration, and all codesign/notarytool/create-dmg/appcast plumbing mechanics — left to the builder, consistent with macOS HIG, Light/Dark/accent, VoiceOver labels (INFRA-14/15), and never-crash/never-freeze.
- Whether the welcome window also surfaces a "Check for Updates" affordance or a link to preferences is a builder call.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` § "Polish & Distribution (DIST)" — DIST-01..04 exact acceptance wording.
- `.planning/ROADMAP.md` § "Phase 3: Polish & Distribution" — goal and 4 success criteria (Services pre-fill, text+binary drag-drop without blocking, signed/notarized DMG + first-run onboarding, Sparkle EdDSA + v0.0.1→v0.0.2 validation + public key in Info.plist from first release).

### Stack, Tooling & Pitfalls (authoritative — locked)
- `CLAUDE.md` (repo root) — the locked Phase-3 toolchain: **Sparkle 2.9.3** (EdDSA appcast, delta, XPC installer), **`xcrun notarytool`** (altool is dead), **create-dmg 8.1.0** (Node 20+, notarization-ready DMG), **SMAppService** (launch-at-login, macOS 13+, works non-sandboxed), Sparkle requires Hardened Runtime + Developer ID signing. Also the "What NOT to Use" table (no altool, no Squirrel).
- `.planning/research/SUMMARY.md` — layered architecture + the **`ToolDefinition`/`ToolRegistry` central abstraction (FROZEN)** that Services routing and drag-drop must route through, plus the critical pitfalls (esp. #2 activation-policy dance — relevant to bringing the onboarding/workspace window to front; #6 cold-start budget — onboarding must not regress it).
- `requirement.md` (repo root) — full PRD; authoritative reference for Services, drag-drop, distribution, and onboarding intent.

### Prior-Phase Decisions (carry forward)
- `.planning/phases/01-infrastructure-core-tools/01-CONTEXT.md` — D-04..D-06 (detection banner / first-match-wins chain) that Services D-02 deliberately diverges from; D-10/D-11 (live transform, last-good output); two-stage Esc and search-first launcher that D-03/D-04 route back to.
- `.planning/phases/02-extended-tools/02-CONTEXT.md` — CF-03 per-field copy and `WarningBannerView` reuse (relevant to D-06 drop errors); popover-vs-window duality.

### Project-Level Decisions
- `.planning/PROJECT.md` § "Key Decisions" / "Constraints" — not-sandboxed-in-v1 (required for Services + arbitrary file drop + SMAppService), direct `.dmg`-first distribution, native-frameworks-first, performance targets (cold start <500ms — onboarding must not regress it), never-crash-on-bad-input.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Core/Services/ToolRegistry.swift` — `detect(from:) -> DetectionResult?` (first-match-wins chain) is the routing brain for Services (D-02) and launcher-routed drops (D-04). FROZEN — do not edit the `tools` array; the file already carries the "sanctioned append" marker, no further appends needed for Phase 3.
- `Core/Services/ToolRegistry.swift` → `ToolSeed` (`@Observable @MainActor`, `set(toolId:value:)` / `consume(for:)`) — the one-shot pre-fill mechanism. Services and drop both stage a seed, then open the tool which consumes it on `.onAppear`. Already the wiring used by the clipboard-accept path.
- `UI/Components/WarningBannerView.swift` (`.warning`/`.error`) — reuse for D-06 wrong-type/oversized drop errors.
- `App/WindowCoordinator.swift` — `openWorkspace()` / `openPreferences()` activation-policy dance (`.accessory`→`.regular`→activate→restore). The onboarding window (D-07) and any Services-triggered tool surface needs this same dance to appear above the frontmost app.
- Existing chunked-file processing in Base64 (B64-04) and Hash (HASH-02) tools — the off-main, progress-reporting path D-06 reuses for binary-file drops.
- `Core/Services/PreferencesStore.swift` + SMAppService launch-at-login (built INFRA-13) — the onboarding "Enable Launch at Login" button (D-07) toggles the existing setting, doesn't build new.

### Established Patterns
- Clipboard-accept already does `ToolSeed.set` → open tool → `consume(for:)`. Services routing (D-02) and launcher-routed drops (D-04) are the same pattern with a different trigger source; **divergence is only that Services skips the banner** and auto-opens.
- Window surfacing requires the `WindowCoordinator` activation-policy dance (Pitfall #2) — applies to the new onboarding window.
- `Resources/Flint-release.entitlements` — Hardened Runtime on, `get-task-allow` deliberately absent. Sparkle + Developer ID signing + notarization build on this; do not add sandbox entitlements (v1 not sandboxed).

### Integration Points
- **Services**: declare `NSServices` in Info.plist + an `NSApplication`-level service provider that receives the pasteboard text, calls `detect()`, stages a `ToolSeed`, and opens the popover/tool (or launcher on no-match).
- **Drag-drop**: SwiftUI `onDrop`/`dropDestination` on the tool surface + launcher; route via `detect()` for launcher drops, direct-load for open-tool drops.
- **Sparkle**: add SPM dep, embed EdDSA public key in Info.plist, ship/host the appcast; wire an updater controller. v0.0.1→v0.0.2 dry-run before v1.0.
- **DMG**: `Flint.xcodeproj` Archive → Developer ID sign → `notarytool submit --wait` → staple → `create-dmg`. Info.plist gains the EdDSA key + (if needed) Sparkle feed URL.
- `App/FlintApp.swift` — service ownership point; an updater/Services service provider and a first-run-onboarding gate hook in here (or a small dedicated service in `Core/Services`).

</code_context>

<specifics>
## Specific Ideas

- **Services ≠ clipboard, intentionally.** The user explicitly chose to send text to Flint, so Services auto-opens the matched tool (D-02) — a deliberate divergence from the passive clipboard banner (Phase 1 D-04). Downstream agents should not "fix" this into consistency.
- **The "where did it go?" problem is the onboarding's real job.** Flint has no Dock icon by default; a fresh user can install it and not know it's running. The welcome window's first duty (D-07) is pointing at the menubar icon and teaching `⌘⇧Space` — everything else is secondary.
- **Preserve the working large-file path.** D-06 explicitly rejects a blanket size cap because Base64/Hash already stream large files off-main; a global cap would regress a shipped capability.

</specifics>

<deferred>
## Deferred Ideas

- **Stable + beta update channels** — considered for D-09, deferred. Add a beta opt-in only when there's a beta audience (v1 ships single stable channel).
- **Per-tool Services entries** — considered for D-01, rejected for v1 (clutters every app's Services submenu). The single smart entry covers the need.

(Pre-existing deferrals tracked in `.planning/STATE.md` / REQUIREMENTS.md v2: cloud sync, App Store sandboxing, opt-in crash reporting, long-hash completion notification, additional tools.)

</deferred>

---

*Phase: 3-Polish & Distribution*
*Context gathered: 2026-06-26*
