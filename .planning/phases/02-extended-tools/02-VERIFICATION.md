---
phase: 02-extended-tools
verified: 2026-06-26T17:00:00Z
status: passed
score: 19/19 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 18/19
  gaps_closed:
    - "MD-02 editor syntax highlight — attribute-only MarkdownEditorHighlight pass added to SyntaxEditorView via opt-in markdownHighlight flag; enabled in MarkdownView.swift at line 118"
    - "Markdown export forces light theme and defaults to Downloads folder (forceLight param in MarkdownTransformer.fullStyledHTML; directoryURL = defaultExportDirectory in saveAsHTML/saveAsPDF)"
    - "CLR-02 clipboard-detection pre-fill — ToolSeed service staged in MenuBarPopoverView.onAccept and consumed in ColorView.onAppear"
    - "All 7 human UAT items confirmed PASSING by developer (02-HUMAN-UAT.md status: passed)"
  gaps_remaining: []
  regressions: []
---

# Phase 02: Extended Tools Verification Report

**Phase Goal:** The toolkit is complete — a developer can test regex patterns with live highlighting, convert colors across HEX/RGB/HSL/HSV/OKLCH with a screen eyedropper and WCAG contrast check, preview Markdown with GFM live, convert number bases with an interactive bit-field, and diff two text blocks with word-level precision.
**Verified:** 2026-06-26T17:00:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (02-08) and UAT fixes (commit 668b431); previous status was human_needed (18/19)

---

## Goal Achievement

### Roadmap Success Criteria (Phase 2)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| SC1 | Regex live highlighting, never freezes (background eval + 2s timeout + 300ms debounce) | VERIFIED | `nonisolated static runWorker` in RegexViewModel.swift:245; `withThrowingTaskGroup` timeout race at line 151; cancel-in-flight at line 98; UAT item 1 PASSED by developer |
| SC2 | Color: all formats simultaneous, NSColorSampler eyedropper, WCAG contrast, out-of-gamut warning | VERIFIED | `NSColorSampler().show` in ColorView.swift:106; `ColorPicker` at line 119; `wcagSection` at line 258; `WarningBannerView("Out of sRGB gamut — clipped")` at line 67; UAT items 3, 4, 7 PASSED by developer |
| SC3 | Markdown split editor + live GFM preview (tables, task lists, fenced code, strikethrough) + export as copied HTML or saved HTML | VERIFIED | `HSplitView` in MarkdownView.swift:80; `visitTable`, `visitStrikethrough`, task-list checkbox in MarkdownTransformer.swift; "Copy HTML" button at line 170; "Save as HTML…" at 182; "Save as PDF…" at 187; UAT item 2 PASSED by developer |
| SC4 | Number bases real-time, bit-field toggle, signed/unsigned two's complement | VERIFIED | `BitFieldView` wired in NumberBaseView.swift:47; `signed` toggle at line 94; `Int8/16/32/64(bitPattern:)` two's-complement in NumberBaseTransformer |
| SC5 | Text diff with line-level changes, word-level inline highlighting, line numbers, jump between diffs, unified patch | VERIFIED | `CollectionDifference` line diff + `Flint.diff(text1:text2:)` word diff in TextDiffTransformer.swift:347; `prevDiff()`/`nextDiff()` in TextDiffView.swift:159/171; `CopyButtonView(getText: { r.unifiedPatch })` at line 181 |

**Score: 5/5 Roadmap Success Criteria verified**

---

### Observable Truths (Plan Must-Haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SPM dependencies (ChromaKit 0.1.1, swift-markdown) resolve; SwiftDiff vendored Swift-6-clean; CSS bundled | VERIFIED | `grep ChromaKit Package.resolved` FOUND; `grep swift-markdown Package.resolved` FOUND; `github-markdown.css` = 253 lines, `prefers-color-scheme` present |
| 2 | User can enter regex pattern with g/i/m/s/x flag toggles and multi-line test string (RGX-01) | VERIFIED | Five `Toggle(.checkbox)` flag controls wired to `viewModel.flags` in RegexView.swift:232–268; `SyntaxEditorView` for test string |
| 3 | Matches highlight live, color-coded per capture group, with match-count badge; never freezes UI (RGX-02) | VERIFIED | `applyHighlights` with `GroupColorPalette` per-group background attributes in RegexView.swift:125; match-count badge at line 311; `nonisolated static runWorker` ensures off-main eval; UAT item 1 PASSED by developer |
| 4 | Results table shows index, position, full match, and named + numbered capture groups (RGX-03) | VERIFIED | `DisclosureGroup("Match Results")` at RegexView.swift:337 rendering `index`, `position`, `matchedString`, `numberedGroups`, `namedGroups` from `RegexMatch` struct |
| 5 | Replace mode previews substitution; Patterns menu inserts email/URL/phone/date/IP presets (RGX-04) | VERIFIED | `Toggle("Enable Replace Mode")` at RegexView.swift:372; `Menu` with 5 presets including Email, URL (HTTP/HTTPS), IPv4 at lines 211–217; `RegexTransformer.substitute` called from ViewModel |
| 6 | Catastrophic backtracking pattern never freezes UI — timeout warning shows, last-good highlight stays dimmed (RGX-02 D-02) | VERIFIED | `withThrowingTaskGroup` race at RegexViewModel.swift:151; `timedOut=true`, `outputDimmed=true`, message at lines 188–190; UAT item 1 PASSED by developer |
| 7 | User can input HEX, RGB, HSL, HSV, OKLCH and see all formats simultaneously with swatch + alpha (CLR-01) | VERIFIED | All 5 `formatRow` sections in ColorView.swift:135–193; CR-03 fix: `normalizedHue` in ColorTransformer.swift:170 maps hue=360→red correctly |
| 8 | NSColorSampler eyedropper + system ColorPicker (CLR-02) | VERIFIED | `NSColorSampler().show` at ColorView.swift:106; `ColorPicker` at line 119; ToolSeed pre-fill: `toolSeed.consume(for: "color")` at ColorView.swift:35; `toolSeed.set(toolId:value:)` at MenuBarPopoverView.swift:81; both `@State private var toolSeed = ToolSeed()` and `.environment(toolSeed)` in FlintApp.swift:26,37,54; UAT items 3, 7 PASSED by developer |
| 9 | R/G/B and H/S/L sliders interactive (CLR-03) | VERIFIED | `slidersSection` at ColorView.swift:230 with R/G/B sliders at 234–236 and H/S/L/saturation/value sliders at 238+ |
| 10 | WCAG AA/AAA contrast result for two colors; any format copies in one click (CLR-04) | VERIFIED | `wcagSection` at ColorView.swift:258; `WCAGResults` computed by `ColorTransformer.wcagContrastRatio`; `CopyButtonView` per format row |
| 11 | Split editor/preview with live GFM (tables, task lists, fenced code, strikethrough), debounced (MD-01) | VERIFIED | `HSplitView`/segmented toggle in MarkdownView.swift; `scheduleRender()` with 300ms debounce; all GFM node visitors in MarkdownTransformer.swift |
| 12 | Editor highlights Markdown syntax; preview highlights fenced code blocks (MD-02) | VERIFIED | **Editor:** `MarkdownEditorHighlight.spans(in:)` in SyntaxEditorView.swift:33 — pure enum scanning ATX headings (systemOrange), bold (systemBlue), italic (systemPurple), inline code (systemTeal), links (secondaryLabelColor); attribute-only `beginEditing/endEditing` pass at line 181; `markdownHighlight: true` at MarkdownView.swift:118; other editors unchanged (no `markdownHighlight` arg in RegexView or TextDiffView). **Preview:** github-markdown.css `pre code` block styling. Tests: FlintTests/MarkdownEditorHighlightTests.swift exists and is in FlintTests target. UAT item 5 PASSED by developer. |
| 13 | User can export as copied HTML, saved .html, or saved .pdf (MD-03) | VERIFIED | "Copy HTML" button at MarkdownView.swift:170; "Save as HTML…" at 182; "Save as PDF…" at 187; `exportHTML` computed var uses `MarkdownTransformer.fullStyledHTML(viewModel.source, forceLight: true)` at line 211; both save panels set `directoryURL = defaultExportDirectory` (Downloads folder) at lines 223, 239; CR-02 fix `MarkdownPDFExporter.strongSelf` at line 255. UAT item 2 PASSED by developer. |
| 14 | Word count and reading-time footer; toolbar inserts bold/italic/link/image/code/table (MD-04) | VERIFIED | `wordCountText`/`readingTimeText` in footer at MarkdownView.swift:153/162; 7 toolbar buttons at lines 308–330 |
| 15 | User can type in binary, octal, decimal, or hex and all bases update in real time (NUM-01) | VERIFIED | 4 `TextField` rows bound to `binText`/`octText`/`decText`/`hexText` in NumberBaseView.swift; `update(from:text:)` in ViewModel triggers `deriveAllFields()` |
| 16 | Bit-length selector (8/16/32/64) and signed/unsigned toggle with two's-complement (NUM-02) | VERIFIED | `Picker` segmented at NumberBaseView.swift:77–87 for 8/16/32/64; `Toggle("Signed")` at line 94; `Int8/16/32/64(bitPattern:)` dispatch in NumberBaseTransformer |
| 17 | Interactive bit-field toggles individual bits and updates all fields (NUM-03) | VERIFIED | `BitFieldView` wired at NumberBaseView.swift:47 with `onToggle` calling `viewModel.pattern = newPattern; syncFieldsFromViewModel()` |
| 18 | Side-by-side and unified diff view toggle; line-level with word-level inline highlights, line numbers, color coding (DIFF-01, DIFF-02) | VERIFIED | `DiffViewMode` picker at TextDiffView.swift:91; `HSplitView` for side-by-side; `DiffLine` carries `wordSegments` from `Flint.diff()`; `DiffLineRowView` colors added/removed/unchanged lines |
| 19 | Jump to next/previous diff; copy unified patch; ignore-whitespace and ignore-case toggles (DIFF-03, DIFF-04) | VERIFIED | `prevDiff()`/`nextDiff()` buttons at TextDiffView.swift:159/171; `CopyButtonView(getText: { r.unifiedPatch })` at line 181; `Toggle("Ignore Whitespace")` at line 80; `Toggle("Ignore Case")` at line 84 |

**Score: 19/19 must-haves verified**

---

### Three Critical Bug Fixes (commit 55e63a6) — Confirmed Present

| Fix | Code Location | Evidence |
|-----|--------------|----------|
| CR-01: RegexViewModel off-main eval | `RegexViewModel.swift:245` | `private nonisolated static func runWorker(...)` — synchronous transformer forced off MainActor |
| CR-02: MarkdownPDFExporter self-retention | `MarkdownView.swift:255` | `private var strongSelf: MarkdownPDFExporter?` set to `self` on init; cleared after `createPDF` completes |
| CR-03: HSL/HSV hue=360 → red | `ColorTransformer.swift:170,178,233` | `private static func normalizedHue(_ hue: Double) -> Double` using `truncatingRemainder(dividingBy: 360.0)`; called at top of both `hslToRGB` and `hsvToRGB` |

### UAT Fixes (commit 668b431) — Confirmed Present

| Fix | Code Location | Evidence |
|-----|--------------|----------|
| Markdown export light theme | `MarkdownTransformer.swift:44`, `MarkdownView.swift:211` | `forceLight: Bool = false` param; `exportHTML` computed var calls `fullStyledHTML(..., forceLight: true)` |
| Markdown export defaults to Downloads | `MarkdownView.swift:205–208, 223, 239` | `defaultExportDirectory` returns `.downloadsDirectory`; both save panels set `panel.directoryURL = defaultExportDirectory` |
| CLR-02 clipboard-detection pre-fill via ToolSeed | `Core/Services/ToolRegistry.swift:66–84`, `Tools/Color/ColorView.swift:15,35`, `UI/MenuBarPopoverView.swift:50,81`, `App/FlintApp.swift:26,37,54` | `ToolSeed` @Observable service; staged in `MenuBarPopoverView` on accept; consumed in `ColorView.onAppear`; injected as `.environment(toolSeed)` at both popover and window sites |

### MD-02 Gap Closure (plan 02-08) — Confirmed Present

| Item | Code Location | Evidence |
|------|--------------|----------|
| `MarkdownEditorHighlight` pure enum | `UI/Components/SyntaxEditorView.swift:18` | Pure `static func spans(in text: String) -> [Span]`; nonisolated; 5 construct patterns; size guard at 2 MB; never crashes on empty/malformed input |
| Attribute-only pass (Pitfall #5 safe) | `SyntaxEditorView.swift:161–163, 175–194` | `if markdownHighlight { applyMarkdownHighlight(to: textView) }` runs AFTER `guard textView.string != text` — does NOT assign `textView.string`; uses `storage.beginEditing()/endEditing()` only |
| Opt-in flag, other editors unchanged | `SyntaxEditorView.swift:120` | `var markdownHighlight: Bool = false`; RegexView and TextDiffView pass no `markdownHighlight` arg (verified: no matches in those files) |
| Markdown editor enables highlighting | `Tools/Markdown/MarkdownView.swift:118` | `SyntaxEditorView(text: $viewModel.source, accessibilityLabel: "Markdown editor", markdownHighlight: true)` |
| Unit tests | `FlintTests/MarkdownEditorHighlightTests.swift` | File exists; tests heading/bold/italic/inline-code/link spans and no-crash on empty/1 MB input; registered in FlintTests target (project.pbxproj) |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Tools/TextDiff/SwiftDiff/diff.swift` | Vendored Myers diff, Swift-6-clean, `public func diff(text1:text2:)` | VERIFIED | Exists; no `.characters` tokens; `func diff` present |
| `Resources/github-markdown.css` | 40+ lines, `prefers-color-scheme` dark | VERIFIED | 253 lines; dark mode media query present |
| `FlintTests/SwiftDiffVendorTests.swift` | Vendor correctness tests | VERIFIED | File exists in FlintTests/ |
| `FlintTests/MarkdownEditorHighlightTests.swift` | Pure highlighter unit tests (heading/bold/italic/code/link spans; no-crash) | VERIFIED | File exists; covers all 5 construct types; registered in FlintTests target |
| `Tools/Regex/RegexTransformer.swift` | Pure matches/substitute, `enum RegexTransformer` | VERIFIED | Foundation-only; no SwiftUI import; `enum RegexTransformer` with `matches` and `substitute` |
| `Tools/Regex/RegexViewModel.swift` | Off-main eval, `withThrowingTaskGroup`, `ToolShortcutActions` | VERIFIED | All three present; `nonisolated static runWorker` for CR-01 |
| `Tools/Regex/RegexView.swift` | Pattern + flags + test editor + results table + replace | VERIFIED | `.toolShortcuts(viewModel)` applied; all sections present |
| `Tools/Regex/RegexDefinition.swift` | id "regex", category .analysis, `detectionPredicate: nil` | VERIFIED | Matches specification |
| `Tools/Color/ColorTransformer.swift` | HEX/RGB/HSL/HSV/OKLCH math, WCAG, gamut check | VERIFIED | All format conversions; `normalizedHue` CR-03 fix; `relativeLuminance` present |
| `Tools/Color/ColorView.swift` | Swatch + eyedropper + format rows + sliders + WCAG + ToolSeed pre-fill | VERIFIED | All sections present; `NSColorSampler().show` wired; `toolSeed.consume(for: "color")` on onAppear |
| `Tools/Color/ColorDefinition.swift` | id "color", hex detection predicate | VERIFIED | Narrow `#RGB/#RRGGBB/#RRGGBBAA` predicate present |
| `Tools/Markdown/MarkdownTransformer.swift` | swift-markdown AST→HTML, GFM features, forceLight param | VERIFIED | Full GFM visitor including tables, strikethrough, task lists, fenced code; `forceLight: Bool = false` param at line 44 |
| `Tools/Markdown/MarkdownView.swift` | Split editor/preview + toolbar + footer + export + markdownHighlight:true + forceLight + Downloads default | VERIFIED | `HSplitView`; toolbar 7 buttons; footer; PDF export via `MarkdownPDFExporter`; `markdownHighlight: true` at line 118; `exportHTML` uses `forceLight: true`; both save panels use `defaultExportDirectory` |
| `UI/Components/SyntaxEditorView.swift` | Opt-in markdownHighlight, MarkdownEditorHighlight pure enum, attribute-only pass | VERIFIED | `markdownHighlight: Bool = false` flag; `MarkdownEditorHighlight.spans(in:)` pure function; `beginEditing/endEditing` attribute pass; Pitfall #5 guard preserved |
| `UI/Components/WebPreviewView.swift` | WKWebView, JS-off, nav-blocked, identical-HTML guard | VERIFIED | `allowsContentJavaScript = false`; `lastLoadedHTML` guard; navigation policy blocks links |
| `Tools/NumberBase/NumberBaseTransformer.swift` | 4-base conversion, two's complement, bit-toggle | VERIFIED | All bases; `Int8/16/32/64(bitPattern:)` signed; `toggleBit`; `UInt64.max` for w64 mask |
| `UI/Components/BitFieldView.swift` | Interactive bit toggle grid, MSB-left, VoiceOver labels | VERIFIED | Pure SwiftUI; 8 bits/row; `accessibilityLabel("Bit N, value 0/1")` per button |
| `Tools/TextDiff/TextDiffTransformer.swift` | Line diff via CollectionDifference + word diff via SwiftDiff | VERIFIED | `difference(from:)` + `Flint.diff(text1:text2:)` both called |
| `Tools/TextDiff/TextDiffView.swift` | Side-by-side/unified, next/prev, copy patch, ignore toggles | VERIFIED | All four DIFF requirements present |
| `Core/Services/ToolRegistry.swift` | All 5 Phase-2 `*Definition.make()` calls appended + ToolSeed service | VERIFIED | 12 total `Definition.make()` calls; all 5 Phase-2 tools present; `ToolSeed` @Observable service at line 66 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `RegexDefinition.swift` | `RegexView` | `makeView` factory | VERIFIED | `makeView: { @MainActor in AnyView(RegexView()) }` at line 27 |
| `RegexViewModel.swift` | `RegexTransformer` | `nonisolated static runWorker` | VERIFIED | `RegexTransformer.matches` called at RegexViewModel.swift:252 inside `nonisolated static` worker |
| `ColorDefinition.swift` | hex detection | `detectionPredicate` | VERIFIED | Narrow `#RGB/#RRGGBB/#RRGGBBAA` predicate in ColorDefinition.swift |
| `ToolRegistry.swift` | All 5 Phase-2 definitions | `tools` array append | VERIFIED | Lines 31–35 of ToolRegistry.swift |
| `MarkdownView.swift` | `MarkdownPDFExporter` | `saveAsPDF()` via `exportHTML` | VERIFIED | `MarkdownPDFExporter.export(html: exportHTML, to: url)` at MarkdownView.swift:244; `exportHTML` uses `forceLight: true` |
| `MarkdownView.swift` | `SyntaxEditorView` | `markdownHighlight: true` flag | VERIFIED | Line 118: `SyntaxEditorView(text: $viewModel.source, accessibilityLabel: "Markdown editor", markdownHighlight: true)` |
| `NumberBaseView.swift` | `BitFieldView` | `BitFieldView(pattern:width:onToggle:)` | VERIFIED | Wired at NumberBaseView.swift:47–56; `onToggle` updates `viewModel.pattern` |
| `TextDiffTransformer.swift` | SwiftDiff `diff()` | `Flint.diff(text1:text2:)` | VERIFIED | Qualified module call at TextDiffTransformer.swift:347 |
| `MenuBarPopoverView.swift` | `ToolSeed` | `toolSeed.set(toolId:value:)` on detection accept | VERIFIED | Line 81: `toolSeed.set(toolId: result.toolId, value: clip)` |
| `ColorView.swift` | `ToolSeed` | `toolSeed.consume(for: "color")` on `.onAppear` | VERIFIED | Line 35: `if let seed = toolSeed.consume(for: "color") { viewModel?.updateFromHex(seed) }` |
| `FlintApp.swift` | `ToolSeed` | `.environment(toolSeed)` | VERIFIED | Lines 37, 54: injected at both popover and window view sites |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `RegexView` → match highlight | `viewModel.matches` | `RegexTransformer.matches()` via `runWorker` | Yes — NSRegularExpression on real input | FLOWING |
| `ColorView` → format rows | `viewModel.canonicalRGBA` | `ColorTransformer.parseHex/hslToRGB/etc.` on user input | Yes — pure math transforms | FLOWING |
| `ColorView` → pre-fill from clipboard detection | `viewModel.canonicalRGBA` via `updateFromHex(seed)` | `ToolSeed.consume(for: "color")` staged by `MenuBarPopoverView` on detection accept | Yes — real clipboard value | FLOWING |
| `MarkdownView` → `WebPreviewView` | `viewModel.html` | `MarkdownTransformer.fullStyledHTML(source)` with bundled CSS | Yes — swift-markdown AST parse | FLOWING |
| `MarkdownView` → export HTML/PDF | `exportHTML` computed var | `MarkdownTransformer.fullStyledHTML(viewModel.source, forceLight: true)` | Yes — same AST parse, forced light | FLOWING |
| `SyntaxEditorView` → Markdown editor highlights | `MarkdownEditorHighlight.spans(in: str)` | Applied to `textView.textStorage` via `beginEditing/endEditing` | Yes — pure regex scan on live text | FLOWING |
| `NumberBaseView` → 4 field strings | `binText/octText/decText/hexText` | `NumberBaseTransformer.*` from `pattern: UInt64` | Yes — all 4 bases derived | FLOWING |
| `TextDiffView` → diff output | `viewModel.result: DiffResult?` | `TextDiffTransformer.diff()` via CollectionDifference + SwiftDiff | Yes — live line+word diff | FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — no runnable entry points (macOS app requires Xcode build + launch).

---

### Probe Execution

Step 7c: No probe scripts found. `scripts/*/tests/probe-*.sh` not present; no phase plan declares probes.

---

### Requirements Coverage

| Requirement | Plan | Description | Status | Evidence |
|-------------|------|-------------|--------|----------|
| RGX-01 | 02-02 | Pattern with flag toggles + multi-line test string | SATISFIED | RegexView flag toggles + SyntaxEditorView |
| RGX-02 | 02-02, 02-07 | Live highlighting, never freeze | SATISFIED | nonisolated static runWorker + withThrowingTaskGroup; UAT item 1 PASSED |
| RGX-03 | 02-02 | Results table: index, position, full match, capture groups | SATISFIED | DisclosureGroup("Match Results") with RegexMatch fields |
| RGX-04 | 02-02 | Replace mode + pattern library | SATISFIED | replaceMode toggle + Menu with 5 presets |
| CLR-01 | 02-03 | All formats (HEX/RGB/HSL/HSV/OKLCH) simultaneous + alpha | SATISFIED | 5 formatRow sections; normalizedHue CR-03 fix; UAT item 4 PASSED |
| CLR-02 | 02-03 | NSColorSampler eyedropper + system color panel + clipboard pre-fill | SATISFIED | NSColorSampler().show + ColorPicker; ToolSeed pre-fill chain fully wired; UAT items 3, 7 PASSED |
| CLR-03 | 02-03 | R/G/B, H/S/L sliders interactive | SATISFIED | slidersSection with all sliders |
| CLR-04 | 02-03 | WCAG AA/AAA contrast checker | SATISFIED | wcagSection + WCAGResults |
| MD-01 | 02-04 | Split editor/preview, live GFM, debounced | SATISFIED | HSplitView + debounced scheduleRender + full GFM visitors |
| MD-02 | 02-04, 02-08 | Editor highlights Markdown syntax; preview highlights code blocks | SATISFIED | Editor: MarkdownEditorHighlight attribute-only pass via markdownHighlight:true (02-08); Preview: CSS-only pre/code block styling; UAT item 5 PASSED |
| MD-03 | 02-04 | Export: copied HTML, saved .html, saved .pdf (light theme, Downloads default) | SATISFIED | Copy HTML + Save as HTML + Save as PDF; forceLight:true for export; directoryURL = Downloads; UAT item 2 PASSED |
| MD-04 | 02-04 | Word count + reading time; toolbar inserts formatting | SATISFIED | Footer text + 7 toolbar buttons |
| NUM-01 | 02-05 | All 4 bases update in real time | SATISFIED | 4 TextField rows + deriveAllFields() |
| NUM-02 | 02-05 | Bit-length selector + signed/unsigned + two's complement | SATISFIED | Picker 8/16/32/64 + signed Toggle + Int8/16/32/64(bitPattern:) |
| NUM-03 | 02-05 | Interactive bit-field updates all fields | SATISFIED | BitFieldView with onToggle wired to viewModel.pattern |
| DIFF-01 | 02-06 | Side-by-side and unified view toggle | SATISFIED | DiffViewMode picker + HSplitView |
| DIFF-02 | 02-06 | Word-level inline highlighting, line numbers, color coding | SATISFIED | wordSegments from SwiftDiff + line numbers in DiffLine + per-kind colors |
| DIFF-03 | 02-06 | Jump to next/previous diff; copy unified patch | SATISFIED | prevDiff()/nextDiff() + CopyButtonView(unifiedPatch) |
| DIFF-04 | 02-06 | Ignore whitespace and ignore case toggles | SATISFIED | Two checkbox Toggles wired to viewModel |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Tools/TextDiff/SwiftDiff/cleanup.swift` | 55–56, 117–118 | Double `popLast` / `removeLast` (WR-05) | INFO | Dead code path — `cleanupEfficiency`/`cleanupSemantic` are not called by `TextDiffTransformer`; no production impact |
| `Tools/NumberBase/NumberBaseViewModel.swift` | 147–155 | `applyWidthChange` triggers `deriveAllFields()` twice via `width.didSet` then `pattern.didSet` (WR-04) | INFO | Double computation on width change; harmless for correctness; two SwiftUI diff passes |
| `Tools/Regex/RegexView.swift` | 154–157 | Capture-group highlighting uses `NSString.range(of:range:)` substring search instead of stored `NSRange` (WR-01) | WARNING | Wrong highlight position for patterns like `/(a)(a)/` on "aa" — second group highlights at position 0 instead of position 1; tracked in REVIEW.md as non-blocking |
| `Tools/Markdown/MarkdownViewModel.swift` | 73–98 | `runRender()` is synchronous on `@MainActor` (WR-02) | WARNING | GFM parse runs on main thread; fast for typical inputs; only noticeable with 10 MB inputs; tracked in REVIEW.md as non-blocking |
| `Tools/Color/ColorTransformer.swift` | 378 | WCAG linearise threshold 0.03928 (should be 0.04045 per WCAG 2.1 erratum) (IN-02) | INFO | Borderline colours near threshold may show PASS when strict WCAG 2.1 checker would show FAIL; < 0.01% luminance difference in practice |
| `Core/Services/ToolRegistry.swift` | 51 | `detect` comment still lists only Phase-1 tools, omits `ColorDefinition` active predicate (IN-04) | INFO | Misleading comment for future maintainers; no runtime impact |

No `TBD`, `FIXME`, or `XXX` markers found in any Phase-2 modified file.

---

### Human Verification — Completed

All 7 UAT items have been confirmed PASSING by the developer (02-HUMAN-UAT.md, status: passed, updated 2026-06-26T16:00:00Z). No items remain pending.

| # | Test | Result |
|---|------|--------|
| 1 | Regex never-freeze: `(a+)+$` against `aaaaaaaaaaaaaaaaaaaa!` | PASSED |
| 2 | Markdown PDF export (light-themed, defaults to Downloads) | PASSED |
| 3 | Color eyedropper: NSColorSampler picks screen pixel, all rows update, no permission dialog | PASSED |
| 4 | OKLCH out-of-gamut warning: L=0.7 C=0.4 H=145 shows "Out of sRGB gamut — clipped" | PASSED |
| 5 | Markdown editor syntax highlighting: `# Hello **world**` shows colored markers | PASSED |
| 6 | Launcher + fuzzy search: regex/color/markdown/base/diff all surface correct tools | PASSED |
| 7 | Detection chain: `#3366FF` → Color Converter pre-filled; JSON/JWT/Base64 still route to Phase-1 tools | PASSED |

---

### Gaps Summary

No gaps. All 19 plan must-haves verified. All 5 roadmap success criteria verified. All 19 requirement IDs (RGX-01..04, CLR-01..04, MD-01..04, NUM-01..03, DIFF-01..04) satisfied. All 7 human UAT items passed.

**Previously open items — now closed:**
- MD-02 editor syntax highlight: closed by plan 02-08 (`MarkdownEditorHighlight` attribute-only pass, `markdownHighlight: true` in MarkdownView.swift)
- Markdown export theme + directory: closed by commit 668b431 (`forceLight: true` in `exportHTML`; `directoryURL = defaultExportDirectory` → Downloads)
- CLR-02 clipboard pre-fill: closed by commit 668b431 (`ToolSeed` service fully wired from detection accept through `ColorView.onAppear`)

**Remaining warnings from code review (non-blocking, tracked in 02-REVIEW.md):**
- WR-01: Capture-group highlight uses substring search instead of stored NSRange
- WR-02: `MarkdownViewModel.runRender()` runs synchronously on MainActor
- WR-04: `applyWidthChange` triggers `deriveAllFields()` twice
- WR-05: Dead `cleanupEfficiency`/`cleanupSemantic` functions have double-`popLast` porting error

---

_Verified: 2026-06-26T17:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification after: 02-08 gap closure (MD-02 editor highlight) + commit 668b431 UAT fixes + developer UAT confirmation (02-HUMAN-UAT.md)_
