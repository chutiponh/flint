# Phase 2: Extended Tools - Context

**Gathered:** 2026-06-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 completes the toolkit with the five remaining extended tools: **Regex Tester, Color Converter, Markdown Previewer, Number Base Converter, and Text Diff**. Each is built as a new `Definition` + pure `Transformer` + `@Observable ViewModel` + `View` quad registered in `ToolRegistry`, exactly like the seven Phase-1 tools. New dependencies added this phase: **ChromaKit** (OKLCH ↔ NSColor), **swift-markdown** (GFM parsing) + **WKWebView** (preview/PDF), and **SwiftDiff** (word-level inline diff). `CollectionDifference` (native) handles line-level diff.

This discussion clarified **HOW** each tool's UX behaves. The package stack, layered architecture, the frozen `ToolDefinition` shape, and the Phase-1 UX conventions (live-debounce, inline-error/last-good, per-field copy, search-driven launcher, detection banner) are already locked and are NOT re-decided here — they carry forward.

</domain>

<decisions>
## Implementation Decisions

### Carried Forward from Phase 1 (apply to ALL five tools)
- **CF-01:** Live, debounced transform (~150ms) for lightweight conversion (Color, Number Base). Heavy/iterative ops stay safe: Regex uses background eval + 2s timeout (see D-02); Markdown preview is debounced. (Phase 1 D-10)
- **CF-02:** Graceful inline errors that never blank output — keep the last valid output visible but dimmed on malformed mid-typing input. (Phase 1 D-11)
- **CF-03:** Per-field/per-row copy buttons on every output, plus a primary "Copy output/all". Reuse `CopyButtonView` / `View+CopyButton`. (Phase 1 D-12)
- **CF-04:** Tools live in the search-first launcher with the two-stage Esc and persistent top search bar. Regex and hex-color are already in the first-match-wins detection predicate chain (Phase 1 D-06) — wire their `detectionPredicate` accordingly.
- **CF-05:** Tools that benefit from more space (Markdown split, Text Diff side-by-side) render compact in the ~480-wide popover and roomy in the existing resizable main window (`MainWindowView`).

### Regex Tester (RGX)
- **D-01:** **Vertical-stack layout** in the popover: pattern field + flag toggles (g/i/m/s/x) row → multi-line test-string editor (highlighted live) → collapsible match-results table (index, position, full match, named + numbered capture groups per RGX-03) → replace-mode section with substitution preview (RGX-04).
- **D-02:** **Background eval with a 2s timeout + 300ms debounce.** On timeout (catastrophic backtracking), show an inline warning ("Pattern too slow — possible catastrophic backtracking") and **keep the last-good highlight dimmed** (mirrors CF-02). UI must never freeze (RGX-02).
- **D-03:** Capture groups are **color-coded per group** in the highlighted test string with a match-count badge (RGX-02).
- **D-04:** Common-pattern library (email, URL, phone, date, IP) accessed via a compact **"Patterns ▾" dropdown menu** next to the pattern field — selecting one inserts it (RGX-04).

### Color Converter (CLR)
- **D-05:** **All formats as editable rows.** Large preview swatch at top, then one editable row per format — HEX, RGB, HSL, HSV, OKLCH — each with its own copy button. Editing any field updates all others live; alpha supported (CLR-01).
- **D-06:** Eyedropper (**NSColorSampler**, zero-permission screen pick) and system color panel (SwiftUI **`ColorPicker`** wrapping NSColorPanel) buttons sit near the swatch (CLR-02). R/G/B + H/S/L sliders are interactive and sync with the fields (CLR-03).
- **D-07:** WCAG AA/AAA **contrast checker is a collapsible section** below the converter: the current color is one swatch, a second color picker supplies the other; show AA/AAA pass/fail for normal + large text (CLR-04). One tool, one navigation entry.
- **D-08:** **Out-of-gamut OKLCH → gamut-clip + warning badge.** Show the clipped (nearest in-sRGB) HEX/RGB so the swatch stays meaningful, plus a warning badge ("Out of sRGB gamut — clipped"). Reuse `WarningBannerView`.

### Markdown Previewer (MD)
- **D-09:** **Toggle in popover, split in window.** Narrow popover shows a segmented Editor/Preview toggle (one pane at a time); the resizable main window shows true side-by-side editor|preview. Live rendering is debounced (MD-01).
- **D-10:** Editor highlights Markdown syntax; preview highlights fenced code blocks (MD-02). GFM features required: tables, task lists, strikethrough, fenced code.
- **D-11:** **Styled, GitHub-like HTML.** Preview and exported HTML/PDF use a bundled GitHub-flavored stylesheet, **CSS inlined** (self-contained, fully offline). Export targets: copied HTML, saved `.html`, saved `.pdf` via `WKWebView.createPDF` (MD-03).
- **D-12:** **Formatting toolbar above the editor pane** (bold/italic/link/image/code/table, shown when editing); **word-count + reading-time in a thin status footer** (MD-04). Layout scales to both popover and window.

### Number Base Converter (NUM)
- **D-13:** Editable binary/octal/decimal/hex fields all update in real time from any input (NUM-01). Bit-length selector 8/16/32/64 and signed/unsigned toggle with correct two's-complement display for negatives across all widths (NUM-02).
- **D-14:** **Interactive bit-field as wrapped rows grouped by nibble (4-bit) / byte**, with small gaps and bit-index labels — readable at 64-bit in the 480pt popover. Toggling any bit flips it and updates all number fields; overflow handled gracefully (NUM-03).

### Text Diff (DIFF)
- **D-15:** **Two stacked text editors (Original / Changed)** for input. After diffing, **default to unified view in the popover**; **side-by-side in the resizable window**. The side-by-side ↔ unified toggle is always present (DIFF-01).
- **D-16:** Line-level diff via native `CollectionDifference`; **word-level inline highlighting within changed lines via SwiftDiff**. Added/removed/unchanged color coding + line numbers (DIFF-02).
- **D-17:** Jump to next/previous difference; copy the diff as a **unified patch** (DIFF-03). Ignore-whitespace and ignore-case toggles (DIFF-04).

### Claude's Discretion
- Exact debounce/timeout fine-tuning, nibble-vs-byte grouping choice for the bit-field, swatch size, toolbar icon glyphs (SF Symbols), the precise GitHub stylesheet contents, animation/transition styling, and spacing are left to the builder — consistent with macOS HIG, Light/Dark/accent support, and VoiceOver labels on all interactive elements (INFRA-14/15 conventions).
- Which (if any) of the five new tools occupy default pinned slots vs search-only is a builder call (Phase 1 already filled the 6 pins with core tools).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — RGX-01..04, CLR-01..04, MD-01..04, NUM-01..03, DIFF-01..04 (the 19 Phase-2 requirement IDs and their exact acceptance wording).
- `.planning/ROADMAP.md` § "Phase 2: Extended Tools" — goal and 5 success criteria (including the background-eval/2s-timeout/300ms-debounce, eyedropper + WCAG, GFM live preview, bit-field two's-complement, and word-level inline-diff requirements).

### Architecture, Stack & Pitfalls (authoritative — locked)
- `.planning/research/SUMMARY.md` — recommended stack and the layered architecture; the **`ToolDefinition`/`ToolRegistry` central abstraction (FROZEN — must not change)** and the 11 critical pitfalls (esp. #5 NSTextView re-render guard — relevant to Regex/Markdown/Diff editors).
- `CLAUDE.md` (repo root) — Technology Stack tables and native-vs-package decisions specifically covering this phase: **ChromaKit 0.1.1** (OKLCH), **swift-markdown 0.8.0 → WKWebView** (Markdown + PDF), **SwiftDiff** (word-level) + **CollectionDifference** (line-level), **HighlightSwift 1.1.0** (display highlighting) / custom NSTextStorage for editable highlighting, **NSColorSampler** + **NSColorPanel/ColorPicker** (color). Also the "What NOT to Use" table.
- `requirement.md` (repo root) — full PRD, authoritative feature reference for all five tools.
- `.planning/phases/01-infrastructure-core-tools/01-CONTEXT.md` — Phase-1 UX decisions D-01..D-13 that carry forward (live-debounce, inline-error/last-good, per-field copy, launcher navigation, detection banner, two-stage Esc).

### Project-Level Decisions
- `.planning/PROJECT.md` § "Key Decisions" and § "Constraints" — performance targets (clipboard detect <100ms, hotkey-to-popover <200ms, cold start <500ms), not-sandboxed-in-v1, native-frameworks-first, never-crash-on-bad-input.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Core/Models/ToolDefinition.swift` (FROZEN) + `Core/Services/ToolRegistry.swift` — every new tool registers here with `id/name/category/keywords/sfSymbol/detectionPredicate/makeView`.
- `Core/Models/ToolCategory.swift` — existing categories: encoding, formatting, conversion, generation, analysis. Likely mapping: Regex→analysis, Color→conversion, Markdown→formatting, Number Base→conversion, Text Diff→analysis.
- `UI/Components/SyntaxEditorView.swift` — `NSViewRepresentable` editable code editor with the re-render guard (Pitfall #5); reuse for Regex test string, Markdown editor, and Diff inputs.
- `UI/Components/CodeDisplayView.swift` — HighlightSwift read-only display; reuse for Markdown code-block highlighting / read-only output.
- `UI/Components/WarningBannerView.swift` (`.warning`/`.error` severities) — reuse for OKLCH out-of-gamut (D-08) and Regex timeout (D-02).
- `UI/Components/CopyButtonView.swift` + `Core/Extensions/View+CopyButton.swift` — per-field copy (CF-03) across all five tools.
- `UI/Components/ToolShortcutActions.swift` — shared ⌘⇧C copy-output / ⌘Delete clear-input observers; new tools should adopt it.
- `UI/MainWindowView.swift` — the resizable window used for the roomy side-by-side layouts (Markdown split D-09, Diff side-by-side D-15).

### Established Patterns
- Per-tool MVVM quad: pure `*Transformer` (no UI imports, unit-tested — see `FlintTests/*TransformerTests.swift`) + `@Observable *ViewModel` (debounce, last-good-output, error state) + `*View` (per-field copy) + `*Definition` (registry entry). All five new tools follow this; each transformer needs its own `*TransformerTests`.
- Live-vs-safe transform split (CF-01): Color/Number Base are pure synchronous transforms; Regex eval must run off the main actor with a timeout; Markdown render is debounced.

### Integration Points
- New SPM packages (ChromaKit, swift-markdown, SwiftDiff) added to `Flint.xcodeproj/.../swiftpm/Package.resolved` (currently: GRDB, HighlightSwift, KeyboardShortcuts, MenuBarExtraAccess, UUIDv7).
- `HistoryStore` (GRDB) records every transform — new tools route through it via the existing pipeline; no secrets involved in these five tools, so no schema-exclusion concerns.
- `ToolRegistry` detection chain — Regex and hex-color predicates slot into the existing first-match-wins order (Phase 1 D-06).

</code_context>

<specifics>
## Specific Ideas

- The popover-vs-window duality is a deliberate, recurring pattern this phase: tools that want space (Markdown editor/preview, Text Diff side-by-side) stay compact (toggle/stacked/unified) in the ~480pt popover and expand to side-by-side in the existing resizable main window.
- "Never freeze the UI" for Regex is the single hardest UX constraint — the 2s-timeout + keep-last-good behavior (D-02) is the explicit, non-negotiable design.
- Markdown export should look finished out of the box (GitHub-styled, self-contained CSS) rather than bare semantic HTML — the PDF in particular should be presentable.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase-2 scope. (Pre-existing deferrals tracked in `.planning/STATE.md`: JSONPath tab → v2, JSON semantic diff → v2, App Store sandboxing → v2. UUID v7 was resolved in Phase 1 via the leodabus/UUIDv7 package.)

</deferred>

---

*Phase: 2-Extended Tools*
*Context gathered: 2026-06-26*
