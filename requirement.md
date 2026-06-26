# macOS Flint — Product Requirements Document

> A native SwiftUI menubar application for macOS that provides essential developer utilities, designed for speed, offline use, and deep system integration.

---

## 1. Overview

### 1.1 Product Vision

A lightweight, native macOS developer toolkit that lives in the menubar and gives developers instant access to common encoding, formatting, and transformation utilities — without a browser, without a subscription, and without an internet connection.

### 1.2 Goals

- Zero friction: open a tool in under 1 second via global hotkey or menubar
- Fully offline — no network dependency for any core tool
- Native macOS experience: respects system appearance, accessibility, and conventions
- Clipboard-first workflow: auto-detect content type on paste or focus
- Persistent history across sessions

### 1.3 Non-Goals (v1)

- Cloud sync or account system
- Mobile / iOS version
- Plugin marketplace
- Collaboration features

---

## 2. Platform & Technical Requirements

| Requirement | Specification |
|---|---|
| Platform | macOS 14.0 (Sonoma) and later |
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Architecture | MVVM |
| Distribution | Direct download (.dmg) first; Mac App Store as v2 target |
| Sandboxing | Not sandboxed (v1) to allow clipboard, file access; sandboxed for App Store v2 |
| Min RAM | 50 MB idle |
| Min Storage | < 20 MB app bundle |

---

## 3. Application Architecture

### 3.1 App Structure

```
FlintApp (MenuBarExtra)
├── MenuBarPopover          ← Quick launcher (default view)
│   ├── SearchBar
│   ├── ToolGrid / ToolList
│   └── RecentTools
└── MainWindow              ← Full workspace (detachable)
    ├── Sidebar (tool categories)
    ├── ToolContentView     ← Active tool panel
    └── HistoryPanel        ← Optional right sidebar
```

### 3.2 Entry Points

1. **Menubar icon** — click to open popover
2. **Global hotkey** — `⌘⇧Space` (configurable) to open/focus app
3. **macOS Services** — right-click selected text → "Open in Flint" → routes to best-matching tool
4. **Dock icon** — optional, togglable in preferences

### 3.3 Window Modes

- **Popover mode** (default): compact floating panel attached to menubar icon, ~480×600px
- **Window mode**: detached resizable window for complex tools, min 800×600px
- Tools remember their last mode per tool

---

## 4. Core Features

### 4.1 Clipboard Auto-Detection

When the app gains focus or the user switches to a tool, auto-detect clipboard content and suggest the appropriate tool.

**Detection Rules (priority order):**

| Detected Pattern | Suggested Tool |
|---|---|
| Valid JSON string | JSON Formatter |
| `ey...` (JWT pattern) | JWT Decoder |
| Base64-decodable string | Base64 Decoder |
| URL-encoded characters (`%20` etc.) | URL Encoder/Decoder |
| Valid URL | URL Parser |
| Pure numeric, 10 digits | Unix Timestamp |
| Hex color (`#RRGGBB`) | Color Converter |
| UUID pattern | UUID Inspector |
| Regex pattern (`/pattern/flags`) | Regex Tester |

Auto-detect is non-destructive: a banner appears with "Detected: JWT — Open JWT Decoder?" and the user can dismiss or accept.

### 4.2 History

- Last 100 transformations stored locally using `UserDefaults` or SQLite
- Each history item records: tool name, input, output, timestamp
- History is accessible per-tool and globally
- History items are re-openable (click to restore input/output into tool)
- User can pin, delete, or clear all history
- History is searchable

### 4.3 Search

- Global fuzzy search across all tools accessible from the popover
- Searches tool names, descriptions, and history items
- Keyboard navigable (↑↓ arrows, Enter to open)

### 4.4 Favorites / Pinning

- Users can pin up to 6 tools to the quick-access toolbar in the popover
- Default pinned tools: JSON Formatter, Base64, URL Encoder, JWT Decoder, Timestamp, UUID Generator

---

## 5. Tool Specifications

### 5.1 JSON Formatter & Validator

**Purpose:** Format, minify, and validate JSON

**Features:**
- Pretty-print with configurable indent (2 or 4 spaces, or tab)
- Minify (compact) mode
- Real-time validation with inline error highlighting (line + column)
- JSONPath query input to extract nested values
- Syntax highlighting using `NSTextView` + custom highlighter
- Sort keys alphabetically (toggle)
- Copy output button
- Diff view: paste two JSON objects and compare

**Input:** Text area (paste or drag file)
**Output:** Formatted text area + copy button

---

### 5.2 Base64 Encoder / Decoder

**Purpose:** Encode and decode Base64 strings

**Features:**
- Encode text → Base64
- Decode Base64 → text
- URL-safe Base64 variant support (`-` and `_` instead of `+` and `/`)
- File mode: encode a file to Base64 or decode Base64 to a downloadable file
- Show decoded byte length and character count
- Auto-detect and switch encode/decode direction

**Input:** Text area or file drop zone
**Output:** Text area + copy button

---

### 5.3 URL Encoder / Decoder

**Purpose:** Encode and decode URL components

**Features:**
- Encode (percent-encoding) text for use in URL query params
- Decode percent-encoded strings
- Full URL parser mode: break a URL into scheme, host, path, query params, fragment
- Query param editor: table view of key-value pairs, editable, with add/delete rows
- Rebuild URL from edited params
- Copy individual components

**Input:** Text area
**Output:** Encoded/decoded string + URL breakdown table

---

### 5.4 JWT Decoder

**Purpose:** Decode and inspect JSON Web Tokens

**Features:**
- Split JWT into header, payload, signature sections with color-coded labels
- Pretty-print header and payload as formatted JSON
- Show expiry (`exp`) as human-readable date/time + countdown (e.g., "Expires in 2h 14m" or "EXPIRED 3 days ago")
- Validate signature using a user-supplied secret (HMAC-SHA256/384/512)
- Algorithm display (from `alg` field)
- Claims table: standard claims (`iss`, `sub`, `aud`, `exp`, `iat`, `nbf`) highlighted separately from custom claims
- Warning banners: expired token, `alg: none`, missing standard claims

**Input:** JWT string (single text field)
**Output:** Three expandable panels (Header / Payload / Signature) + claims table

---

### 5.5 Unix Timestamp Converter

**Purpose:** Convert between Unix timestamps and human-readable dates

**Features:**
- Input: Unix timestamp (seconds or milliseconds, auto-detected)
- Output: formatted date in multiple timezones simultaneously
  - Local timezone
  - UTC
  - User-configurable additional timezones (stored in preferences)
- Reverse: input a date/time → output Unix timestamp
- "Now" button: insert current timestamp
- Relative time display: "3 days ago", "in 2 hours"
- ISO 8601 output format option

**Input:** Numeric field or date picker
**Output:** Timezone table

---

### 5.6 Hash Generator

**Purpose:** Generate cryptographic hashes of text or files

**Algorithms:** MD5, SHA-1, SHA-256, SHA-384, SHA-512, CRC32

**Features:**
- Input text or drop a file
- Show all algorithm outputs simultaneously in a table
- HMAC mode: add a secret key to generate keyed hashes
- Uppercase / lowercase toggle for output
- Copy individual hash with one click
- File hashing: shows file size and all hashes after processing

**Input:** Text area or file drop zone
**Output:** Hash results table

---

### 5.7 UUID Generator & Inspector

**Purpose:** Generate and inspect UUIDs

**Features:**
- Generate single or bulk UUIDs (up to 1000 at once)
- Version support: v1 (time-based), v4 (random), v5 (namespace+name SHA1), v7 (time-ordered, sortable)
- Parse/inspect a UUID: show version, variant, timestamp (for v1/v7), and component breakdown
- Bulk generation exports to clipboard (newline-separated) or as a CSV/JSON array
- Nil UUID display
- Uppercase/lowercase toggle

**Input:** Numeric count field + version selector
**Output:** UUID list with copy-all button

---

### 5.8 Regex Tester

**Purpose:** Test regular expressions against input text

**Features:**
- Pattern input field with flags (g, i, m, s, x) toggles
- Test string multi-line text area
- Real-time match highlighting in the test string (color-coded per capture group)
- Match results table: match index, position, full match, capture groups
- Named capture group support
- Replace mode: substitution string field + preview of replaced output
- Common pattern library (email, URL, phone, date, IP address) as quick-insert
- Match count badge

**Input:** Pattern field + test string text area
**Output:** Highlighted text area + matches table

---

### 5.9 Color Converter

**Purpose:** Convert colors between formats and pick colors from screen

**Features:**
- Input formats: HEX (`#RRGGBB`, `#RGB`), RGB (`rgb(r,g,b)`), HSL (`hsl(h,s%,l%)`), HSV, OKLCH
- Output all formats simultaneously
- Color preview swatch (large, rounded rect)
- System color picker integration (`NSColorPanel`)
- Screen color picker: click an eyedropper button → pick any pixel from screen using `NSColorSampler`
- Adjust sliders (R/G/B or H/S/L) interactively
- Opacity/alpha support
- Contrast ratio checker: input two colors, show WCAG AA/AAA compliance result
- Copy any format with one click

**Input:** Text field (any format) or color picker
**Output:** All format representations + preview swatch

---

### 5.10 Markdown Previewer

**Purpose:** Write and preview Markdown with live rendering

**Features:**
- Split view: left (editor) / right (rendered preview), resizable divider
- Live rendering as user types (debounced ~200ms)
- Syntax highlighting in editor for Markdown syntax
- GitHub Flavored Markdown (GFM) support: tables, strikethrough, task lists, fenced code blocks
- Code block syntax highlighting in preview
- Export options: copy as HTML, save as `.html`, save as `.pdf` via `WKWebView`
- Word count and reading time estimate
- Toolbar shortcuts: bold, italic, link, image, code, table insert

**Input:** Text editor (left pane)
**Output:** Rendered HTML preview (right pane, `WKWebView`)

---

### 5.11 Number Base Converter

**Purpose:** Convert numbers between bases

**Features:**
- Input in any base: binary (2), octal (8), decimal (10), hexadecimal (16)
- Show all representations simultaneously and update in real-time as user types in any field
- Bit-length selector: 8, 16, 32, 64-bit
- Signed / unsigned toggle
- Two's complement display for negative numbers
- Bit-field visual: 8 toggleable bit buttons for 8-bit; updates all fields when bits are flipped

---

### 5.12 Text Diff Viewer

**Purpose:** Compare two text blocks and highlight differences

**Features:**
- Side-by-side or unified diff view (toggle)
- Line-level diff with word-level highlighting within changed lines
- Added (green), removed (red), unchanged (neutral) color coding
- Line numbers
- Jump to next/previous difference buttons
- Copy diff as unified patch format
- Ignore whitespace toggle
- Ignore case toggle

**Input:** Two text areas (left = original, right = changed)
**Output:** Diff view inline below or side by side

---

## 6. Settings & Preferences

Accessible via `⌘,` or menubar → Preferences.

### 6.1 General

| Setting | Default | Options |
|---|---|---|
| Launch at login | Off | On / Off |
| Show in Dock | Off | On / Off |
| Global hotkey | `⌘⇧Space` | Configurable key binding |
| Default open mode | Popover | Popover / Window |
| Clipboard auto-detect | On | On / Off |

### 6.2 Appearance

| Setting | Default | Options |
|---|---|---|
| Theme | System | Light / Dark / System |
| Code font | SF Mono | SF Mono / JetBrains Mono / Fira Code / Menlo |
| Font size | 13 | 11–18 |

### 6.3 History

| Setting | Default |
|---|---|
| Enable history | On |
| Max history items | 100 |
| Clear history on quit | Off |

### 6.4 Tools

- Pinned tools (drag-to-reorder, max 6)
- Per-tool default settings (e.g., default JSON indent, default hash algorithms shown)
- Configurable additional timezones for timestamp tool

---

## 7. Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Open / focus app | `⌘⇧Space` (global, configurable) |
| Open Preferences | `⌘,` |
| Close popover / window | `Esc` |
| Switch to next tool | `⌘]` |
| Switch to previous tool | `⌘[` |
| Focus search | `⌘F` |
| Copy output | `⌘⇧C` |
| Paste and auto-detect | `⌘⇧V` |
| Clear input | `⌘⌫` |
| Toggle history panel | `⌘H` |
| New window (detach) | `⌘N` |

Each tool may define additional local shortcuts (e.g., `⌘↑` to format, `⌘⇧M` to minify in JSON tool).

---

## 8. macOS System Integration

### 8.1 Services Menu

Register a macOS Service so users can select text anywhere, right-click → Services → Flint → [Tool Name]. Route to best-matching tool with text pre-filled.

### 8.2 Drag & Drop

All tools accept drag-and-drop of:
- Plain text files (`.txt`, `.json`, `.md`, `.csv`, etc.)
- Files for binary tools (Base64, Hash Generator)

### 8.3 Appearance

- Fully supports Light and Dark mode via `@Environment(\.colorScheme)`
- Respects system accent color
- Supports macOS Accessibility: VoiceOver labels on all interactive elements, Dynamic Type font scaling

### 8.4 Notifications (Optional, v1.1)

- Optional: notify when a long hash operation on a large file completes

---

## 9. Data & Privacy

- **All processing is local** — no data ever leaves the device
- History stored in `~/Library/Application Support/Flint/history.db` (SQLite)
- Preferences stored in `UserDefaults` (standard `~/Library/Preferences/`)
- No analytics, no telemetry, no crash reporting in v1 (opt-in Sentry in v2)
- No network entitlement required

---

## 10. Project Structure (Suggested Xcode Layout)

```
Flint/
├── App/
│   ├── FlintApp.swift          ← @main, MenuBarExtra setup
│   └── AppDelegate.swift
├── Core/
│   ├── ClipboardDetector.swift
│   ├── HistoryStore.swift
│   ├── HotkeyManager.swift        ← CGEventTap or KeyboardShortcuts package
│   └── PreferencesStore.swift
├── Tools/
│   ├── JSONFormatter/
│   │   ├── JSONFormatterView.swift
│   │   └── JSONFormatterViewModel.swift
│   ├── Base64/
│   ├── URLEncoder/
│   ├── JWT/
│   ├── Timestamp/
│   ├── Hash/
│   ├── UUID/
│   ├── Regex/
│   ├── Color/
│   ├── Markdown/
│   ├── NumberBase/
│   └── TextDiff/
├── UI/
│   ├── MenuBarPopoverView.swift
│   ├── MainWindowView.swift
│   ├── SidebarView.swift
│   ├── HistoryPanelView.swift
│   └── Components/
│       ├── CopyButton.swift
│       ├── DetectionBanner.swift
│       └── SyntaxHighlightedTextView.swift
└── Resources/
    ├── Assets.xcassets
    └── Flint.entitlements
```

---

## 11. Recommended Swift Packages

| Package | Purpose | URL |
|---|---|---|
| `KeyboardShortcuts` | Global hotkey registration | github.com/sindresorhus/KeyboardShortcuts |
| `Highlightr` | Syntax highlighting in NSTextView | github.com/raspu/Highlightr |
| `SwiftDiff` | Text diffing algorithm | github.com/turbolent/SwiftDiff |
| `Ink` | Markdown parsing (fast, pure Swift) | github.com/johnsundell/Ink |
| `GRDB` | SQLite for history store | github.com/groue/GRDB.swift |

---

## 12. Phased Delivery

### Phase 1 — Core (MVP)
JSON Formatter, Base64, URL Encoder, JWT Decoder, Unix Timestamp, Hash Generator, UUID Generator

Infrastructure: menubar app skeleton, popover + window modes, clipboard detection, history, search, preferences, global hotkey.

### Phase 2 — Extended Tools
Regex Tester, Color Converter, Markdown Previewer, Number Base Converter, Text Diff Viewer

### Phase 3 — Polish & Distribution
macOS Services integration, drag & drop, App Store preparation (sandboxing), onboarding flow, auto-update (Sparkle framework)

---

## 13. Acceptance Criteria

- [ ] App launches in < 500ms cold start
- [ ] All tools operate fully offline
- [ ] Global hotkey opens popover from any app within 200ms
- [ ] Clipboard auto-detect fires within 100ms of app focus
- [ ] History persists across app restarts
- [ ] All tools copy output to clipboard in one click
- [ ] App respects system Light/Dark mode with zero visual artifacts
- [ ] No tool crashes on malformed input (all inputs validated gracefully)
- [ ] Memory usage < 100MB under normal usage
- [ ] VoiceOver labels present on all interactive UI elements
