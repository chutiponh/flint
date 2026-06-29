---
phase: 03-polish-distribution
verified: 2026-06-29T00:00:00Z
status: passed
score: 7/7 gap-closure must-haves verified (DIST-02 drag-drop blocker closed)
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 4/4 source-verified (DIST-02 drag-drop blocked at UAT)
  gaps_closed:
    - "Dragging a text file onto a tool (or the launcher) loads its contents — DIST-02 blocker (UAT Tests 5-8)"
    - "Launcher detect()-routing pre-fills the matched tool for all detectable tools, not just Color"
    - "A popover-independent, always-visible path opens the drag-drop workspace"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Signed/notarized DMG + Gatekeeper (DIST-03) — credential-gated"
    expected: "release.sh archives, exports Developer ID, notarytool returns Accepted, staples, spctl reports Notarized Developer ID"
    why_human: "Requires Apple Developer enrollment + Developer ID cert — explicitly deferred by user. Out of scope for this DIST-02 gap-closure run; tracked in the base verification."
  - test: "Sparkle v0.0.1→v0.0.2 update dry-run (DIST-04) — credential-gated"
    expected: "Real EdDSA key generated, dry-run-update.sh drives a working update"
    why_human: "Requires EdDSA key generation + credential-gated pipeline — explicitly deferred. Out of scope for this DIST-02 gap-closure run."
  - test: "Full-app VoiceOver audit (INFRA-15) — live focus order"
    expected: "VoiceOver announces meaningful labels with logical focus order, no traps"
    why_human: "Live screen-reader session required; source label coverage already audited (47/48 GOOD). Out of scope for this DIST-02 gap-closure run."
---

# Phase 3: Polish & Distribution Verification Report — DIST-02 Gap-Closure Re-Verification

**Phase Goal:** Flint is in users' hands — it passes Gatekeeper, auto-updates via Sparkle, accepts dragged files and selected text, and every tool is accessible via VoiceOver.
**Scope of this run:** `--gaps-only` re-verification of the single outstanding blocker — **DIST-02 drag-and-drop** (UAT Tests 5-8), closed by gap-closure plans 03-06 and 03-07. The rest of Phase 03 was source-verified in the prior pass and is not re-litigated here.
**Verified:** 2026-06-29
**Status:** passed (for the DIST-02 gap)
**Re-verification:** Yes — after gap closure (previous status `human_needed`, DIST-02 blocked at UAT)

## Verdict

**The DIST-02 drag-and-drop blocker is CLOSED.** Root cause (the `MenuBarExtra(.window)` NSPanel dismissing on the Finder click required to grab a file — Apple FB11984872) is resolved by routing drops to the normal `WindowGroup(id: "workspace")` → `MainWindowView`, which survives resign-key. Every must-have from both gap-closure plans is verified in source, the app target builds (BUILD SUCCEEDED, freshly run by the verifier — not trusting the SUMMARY claim), and UAT Tests 5, 6, 7, 8 are all marked **pass** at the human checkpoint.

## Goal Achievement

### Observable Truths (gap-closure must_haves)

| # | Truth (source) | Status | Evidence |
|---|----------------|--------|----------|
| 1 | Each of the 6 detectable tool views consumes its own seed once on appear | ✓ VERIFIED | grep confirms `toolSeed.consume(for: "<id>")` in all six: json-formatter, base64, url-encoder, jwt-decoder, timestamp, uuid-generator. Each writes the correct property — JSON/Base64/URL/Timestamp → `input`, JWT → `token`, UUID → `inspectInput` — and all 6 `var` properties exist in their ViewModels |
| 2 | Seed-consume is one-shot and runs AFTER VM init | ✓ VERIFIED | Optional-VM views (JSON/Base64/URL/JWT): consume sits inside the same `.onAppear` after the `if viewModel == nil { … }` block (lines verified 24-34). Init-VM views (Timestamp/UUID): fresh `.onAppear` with direct (non-optional) write. `ToolSeed.consume(for:)` clears after read (ColorView-proven pattern) |
| 3 | Workspace window is a launcher-routing drop target via detect() | ✓ VERIFIED | `MainWindowView.swift:77-93` `.fileDrop(onText:)` calls `toolRegistry.detect(from: text)` → on match `toolSeed.set(...)` + `selectedToolId = result.toolId`; `toolRegistry.detect` and `selectedToolId = result.toolId` both present |
| 4 | Binary/oversized/no-match drops surface a post-drop warning, never a crash | ✓ VERIFIED | `WarningBannerView` rendered in detail-pane VStack (lines 41-55) driven by `dropError`; `onError` sets `dropError`; no-match sets a non-destructive notice (D-03 analog). Dismiss button present (`accessibilityLabel "Dismiss notice"`) |
| 5 | Drag overlay shows during drag | ✓ VERIFIED | `DropOverlayView(label: "Drop to open in best tool")` in `.overlay { if isDragTargeted … }` (lines 94-99) |
| 6 | Always-visible, popover-independent path opens the workspace | ✓ VERIFIED | `macwindow` button appended to the unconditionally-rendered `searchBar` HStack (lines 357-369), NOT the empty-state welcome VStack; action mirrors hidden ⌘N (`openWorkspace()` + `openWindow(id: "workspace")` + dismiss). 2 `openWorkspace()` call sites confirmed |
| 7 | The affordance carries the exact VoiceOver label / artifact string | ✓ VERIFIED | `.accessibilityLabel("Open Flint in a resizable window to drag and drop files")` present verbatim |

**Score:** 7/7 gap-closure truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Tools/JSONFormatter/JSONFormatterView.swift` | consume("json-formatter") → input | ✓ VERIFIED | line 31-32, after VM init |
| `Tools/Base64/Base64View.swift` | consume("base64") → input | ✓ VERIFIED | line 33-34, after VM init |
| `Tools/URLEncoder/URLView.swift` | consume("url-encoder") → input | ✓ VERIFIED | line 32-33, after VM init |
| `Tools/JWT/JWTView.swift` | consume("jwt-decoder") → token | ✓ VERIFIED | line 34-35, after VM init |
| `Tools/Timestamp/TimestampView.swift` | consume("timestamp") → input | ✓ VERIFIED | line 29-30, fresh onAppear |
| `Tools/UUID/UUIDView.swift` | consume("uuid-generator") → inspectInput | ✓ VERIFIED | line 33-34, fresh onAppear |
| `UI/MainWindowView.swift` | detect-routing drop + WarningBannerView + selectedToolId + overlay + ToolSeed env | ✓ VERIFIED | all 6 grep gates pass; banner in detail-pane VStack (documented deviation) |
| `UI/MenuBarPopoverView.swift` | always-visible Open-in-Window affordance | ✓ VERIFIED | button in searchBar; exact a11y string; ≥2 openWorkspace() |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| MainWindowView.fileDrop onText | toolRegistry.detect + toolSeed.set | detect-routing | ✓ WIRED | line 81-82 |
| MainWindowView detect result | selectedToolId | sidebar selection | ✓ WIRED | `selectedToolId = result.toolId` line 83 |
| MenuBarPopoverView searchBar button | WindowCoordinator.openWorkspace + openWindow | always-visible button | ✓ WIRED | lines 359-361 |
| FlintApp WindowGroup("workspace") | MainWindowView | `.environment(toolSeed)` | ✓ WIRED | FlintApp.swift:64-70 — ToolSeed injected so `@Environment(ToolSeed.self)` resolves in the workspace subtree |
| 6 tool views | ToolSeed.consume | `.onAppear` after VM init | ✓ WIRED | seeded by detect→set, consumed once on the routed tool's appear |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| MainWindowView | `selectedToolId` / dropped `text` | live Finder drop → FileDropHandler off-main URL resolve → detect() | ✓ real (untrusted file text, same path tools already accept) | ✓ FLOWING |
| 6 tool views | `viewModel.input`/`token`/`inspectInput` | `toolSeed.consume` of the value `toolSeed.set` by detect-routing | ✓ real (the dropped text, one-shot) | ✓ FLOWING |

No hollow props or hardcoded-empty seeds: the seed value originates from a real dropped file routed through `detect()`. Confirmed end-to-end by the human checkpoint (Test 8 pre-fill).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| App target builds with all 8 modified files | `xcodebuild -scheme Flint -configuration Debug build` | **BUILD SUCCEEDED** (run by verifier, not trusting SUMMARY) | ✓ PASS |
| 6 seed-consume gates | grep per tool view | all present, correct property writes | ✓ PASS |
| MainWindowView 6-gate | grep detect/seed.set/selectedToolId/overlay/banner/env | all present | ✓ PASS |
| Affordance gate | grep exact a11y string + ≥2 openWorkspace | present; count=2 | ✓ PASS |
| Claimed commits exist | `git log` f7ab0ad b855d5a 5369e67 4bfda79 9fb10df | all 5 present | ✓ PASS |
| UAT Tests 5-8 | human checkpoint re-run | all 4 = pass | ✓ PASS (human-verified) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DIST-02 | 03-06 / 03-07 | All tools accept dragged files; launcher routing pre-fills | ✓ SATISFIED | Drag-drop now reachable via stable workspace window; detect-routing pre-fills all 6 detectable tools; UAT Tests 5-8 pass |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TBD/FIXME/XXX in any of the 8 modified files | — | Clean |

No debt markers, no stubs, no hardcoded-empty data flowing to render in the gap-closure files.

### Documented Deviation (accepted)

03-07 PLAN specified `.safeAreaInset(edge: .top)` for the post-drop banner. During the human checkpoint this floated the banner across the full window width, overlapping the sidebar and toolbar. It was corrected to render inside the **detail-pane VStack** above the tool view, plus a visible × dismiss button (`accessibilityLabel "Dismiss notice"`). This deviation is verified present in source (MainWindowView.swift:38-55) and was approved by the user at the blocking human checkpoint. It improves the UX and does not weaken the must-have ("post-drop warning, never a crash"). No override entry needed — the deviation is within the artifact `contains: "WarningBannerView"` requirement, which is satisfied.

### Human Verification Required

None for the DIST-02 gap — UAT Tests 5-8 were already re-run and approved at the blocking human checkpoint in plan 03-07. The three `human_verification` items carried in frontmatter (DIST-03 notarized DMG, DIST-04 Sparkle dry-run, INFRA-15 live VoiceOver) are **out of scope for this gaps-only run** — they are credential-gated / live-session deferrals tracked from the base verification and unaffected by the drag-drop closure.

### Gaps Summary

No remaining DIST-02 gaps. The blocker that left Phase 03 at `human_needed` is fully closed at every level:
- **Plan 06** wired one-shot `ToolSeed.consume` into all 6 detectable tool views (the pre-existing half of Test 8) — verified present and correctly placed after VM init.
- **Plan 07** gave the (already-correct) drop logic a stable host: `MainWindowView` is now a detect-routing drop target with overlay + post-drop banner, and the popover gained an always-visible, popover-independent entry point in the search-bar chrome.
- The app target **builds** (verifier-run), all claimed commits exist, and **UAT Tests 5, 6, 7, 8 all pass** at the human checkpoint.

The only items keeping the broader phase from a clean `passed` are the credential-gated distribution steps and the live VoiceOver audit — both explicitly deferred by the user and outside this gap-closure scope.

---

_Verified: 2026-06-29_
_Verifier: Claude (gsd-verifier)_
