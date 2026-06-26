# Phase 3: Polish & Distribution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-26
**Phase:** 3-Polish & Distribution
**Areas discussed:** Services routing, Drag-and-drop UX, Onboarding flow, Update cadence

---

## Services Routing

### What happens on Services invoke

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-open best tool | Run detect() on the selection, open the matched tool pre-filled immediately via ToolSeed; skip the banner. Deliberate route-to-tool intent. | ✓ |
| Launcher + banner | Open launcher, stage text, show the same Accept/Dismiss detection banner as clipboard (D-04). Adds a click. | |
| You decide | Builder picks. | |

**User's choice:** Auto-open best tool

### No-match fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Open launcher, pre-filled | Open the search-first launcher with text staged so the user picks a tool manually. Never a dead end. | ✓ |
| Open a default tool | Fall back to a default (e.g. Text Diff/JSON) pre-filled. Risks wrong tool / confusing output. | |
| You decide | Builder picks. | |

**User's choice:** Open launcher, pre-filled

### Services menu entries

| Option | Description | Selected |
|--------|-------------|----------|
| One smart entry | Single "Open in Flint" service that auto-detects the right tool. Clean menu footprint. | ✓ |
| Per-tool entries | Multiple entries (Format JSON, Decode Base64…). Precise but clutters every app's Services submenu. | |
| You decide | Builder picks. | |

**User's choice:** One smart entry

**Notes:** Services is treated as a deliberate "send to Flint" action — an intentional divergence from the passive clipboard-detection banner (Phase 1 D-04), scoped only to Services.

---

## Drag-and-Drop UX

### Which tool receives the dropped file

| Option | Description | Selected |
|--------|-------------|----------|
| Open tool only | Drop onto an open tool goes into that tool; drop onto launcher runs detect() on file text contents and routes. Predictable. | ✓ |
| Always auto-route | Every drop re-runs detection and may switch tools, even onto an open tool. Can yank the user out of a deliberately-opened tool. | |
| You decide | Builder picks. | |

**User's choice:** Open tool only

### Drop target affordance

| Option | Description | Selected |
|--------|-------------|----------|
| Whole surface + overlay | Entire tool/popover surface droppable; drag-over shows a highlighted "Drop file to load" overlay. No permanent layout cost. | ✓ |
| Explicit drop zone | Visible dashed drop-box in each tool. Discoverable but eats layout in the 480pt popover. | |
| You decide | Builder picks. | |

**User's choice:** Whole surface + overlay

### Edge cases (wrong-type / oversized)

| Option | Description | Selected |
|--------|-------------|----------|
| Validate + async + reject gracefully | Text tools reject binary/oversized with inline error (never crash); binary tools (Base64/Hash) process any file off-main with progress, reusing chunked-file pattern. | ✓ |
| Hard size cap with message | Refuse any file over a fixed cap everywhere. Simpler, but blocks the legitimate large-file-hash use case that already works. | |
| You decide | Builder picks. | |

**User's choice:** Validate + async + reject gracefully

**Notes:** No blanket size cap — the existing off-main large-file Base64/Hash path is preserved.

---

## Onboarding Flow

| Option | Description | Selected |
|--------|-------------|----------|
| One focused welcome window | Single first-run window: "Flint lives in your menubar" (point at icon) + teach ⌘⇧Space + one button to enable Launch at Login. Dismissible, shown once. | ✓ |
| Multi-step tour | 3–4 panel carousel through tools/history/detection/hotkey/prefs. Thorough but most users skip tours; more UI to maintain. | |
| Just open the launcher | No dedicated onboarding; pop the launcher once on first run. Minimal, risks "menubar app vanished" confusion. | |

**User's choice:** One focused welcome window

**Notes:** The core risk for a no-Dock-icon menubar app is users not knowing it's running or how to summon it — onboarding's primary job is the menubar pointer + hotkey.

---

## Update Cadence

### How updates surface

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-check, prompt to install | Sparkle checks in background; on finding an update, show the standard prompt with release notes; user installs with restart. Sparkle default. | ✓ |
| Silent auto-install | Download/install silently, apply on next launch, no prompt. Lowest friction but takes control away; surprising for a dev tool. | |
| Manual check only | No background checks; user triggers "Check for Updates…". Conservative, but most users never check. | |

**User's choice:** Auto-check, prompt to install

### Channels

| Option | Description | Selected |
|--------|-------------|----------|
| Single stable channel | One appcast, stable only; v0.0.1→v0.0.2 is pipeline-proving on the same channel. | ✓ |
| Stable + beta channels | Beta opt-in in Preferences now, separate appcast. More infra before there's a beta audience. | |
| You decide | Builder picks. | |

**User's choice:** Single stable channel

---

## Claude's Discretion

- Services entry label/glyph, no-match staging affordance details, drag-over overlay styling, binary-tool progress threshold, welcome-window copy/layout/illustration, and all codesign/notarytool/create-dmg/appcast plumbing.
- Whether the welcome window also surfaces "Check for Updates" or a preferences link.

## Deferred Ideas

- Stable + beta update channels → add when a beta audience exists.
- Per-tool Services entries → rejected for v1 (Services submenu clutter); single smart entry covers it.
