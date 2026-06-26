---
phase: 02-extended-tools
verified: 2026-06-26T14:00:00Z
status: human_needed
score: 18/19 must-haves verified
overrides_applied: 0
gaps: []
human_verification:
  - test: "Regex never-freeze UAT: paste pattern (a+)+$ against 'aaaaaaaaaaaaaaaaaaaa!' in Regex Tester"
    expected: "UI stays fully responsive; timeout warning banner appears within ~2 seconds; last-good highlight remains visible but dimmed at 0.4 opacity"
    why_human: "CR-01 fix (nonisolated static runWorker) is confirmed in code, but the actual off-main-actor behaviour under catastrophic backtracking cannot be verified without running the app"
  - test: "Markdown PDF export: type some Markdown, open Save > 'Save as PDF…', pick a filename"
    expected: "A non-blank, visually styled PDF is written to disk at the selected path; no silent failure"
    why_human: "CR-02 fix (self-retaining MarkdownPDFExporter) is confirmed in code; actual WKWebView.createPDF completion requires a running app"
  - test: "Color eyedropper CLR-02: click the eyedropper button in Color Converter, hover over a coloured pixel on screen and select it"
    expected: "The canonical color updates to the picked colour across all format rows (HEX, RGB, HSL, HSV, OKLCH) with no permission dialog"
    why_human: "NSColorSampler().show() is present in code; zero-permission eyedropper UX must be confirmed at runtime"
  - test: "OKLCH out-of-gamut warning CLR-01/CLR-02: enter L=0.7 C=0.4 H=145 in the OKLCH fields"
    expected: "A warning banner 'Out of sRGB gamut — clipped' appears above the swatch"
    why_human: "The banner is wired to viewModel.outOfGamutWarning, which is driven by ColorTransformer.oklchToRGB.isOutOfGamut; requires runtime execution of the gamut check"
  - test: "MD-02 editor Markdown syntax highlight: open Markdown Previewer and type '# Hello **world**'"
    expected: "The editor shows visual syntax coloring (e.g. heading marker in a different color, bold markers highlighted)"
    why_human: "SyntaxEditorView is used as-is (plain NSTextView, isRichText=false); no attribute-only Markdown highlight pass was implemented. This check determines whether the bare monospace editor is acceptable to the developer as the v1 editor experience, or whether this constitutes a gap requiring a plan"
  - test: "All five tools visible and reachable via launcher and fuzzy search: open popover, type 'regex', 'color', 'markdown', 'base', 'diff'"
    expected: "Each tool appears in the results; selecting it opens the correct tool UI"
    why_human: "ToolRegistry registration verified in code; actual popover rendering requires the running app"
  - test: "Detection chain: copy '#3366FF' to clipboard, focus Flint"
    expected: "Detection banner offers 'Color Converter'; accepting it opens Color Converter pre-filled; copying JSON/a JWT/Base64 still routes to Phase-1 tools (no shadowing)"
    why_human: "ColorDefinition.detectionPredicate is narrow and correct in code; runtime detection chain behaviour across all 12 tools requires the running app"
---

# Phase 02: Extended Tools Verification Report

**Phase Goal:** The toolkit is complete — a developer can test regex patterns with live highlighting, convert colors across HEX/RGB/HSL/HSV/OKLCH with a screen eyedropper and WCAG contrast check, preview Markdown with GFM live, convert number bases with an interactive bit-field, and diff two text blocks with word-level precision.
**Verified:** 2026-06-26T14:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Roadmap Success Criteria (Phase 2)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| SC1 | Regex live highlighting, never freezes (background eval + 2s timeout + 300ms debounce) | VERIFIED | `nonisolated static runWorker` in RegexViewModel.swift:245; `withThrowingTaskGroup` timeout race at line 151; cancel-in-flight at line 98 |
| SC2 | Color: all formats simultaneous, NSColorSampler eyedropper, WCAG contrast, out-of-gamut warning | VERIFIED | `NSColorSampler().show` in ColorView.swift:106; `ColorPicker` at line 119; `wcagSection` at line 258; `WarningBannerView("Out of sRGB gamut — clipped")` at line 67 |
| SC3 | Markdown split editor + live GFM preview (tables, task lists, fenced code, strikethrough) + export as copied HTML or saved HTML | VERIFIED | `HSplitView` in MarkdownView.swift:80; `visitTable`, `visitStrikethrough`, task-list checkbox in MarkdownTransformer.swift; "Copy HTML" button at line 170; "Save as HTML…" at line 182; "Save as PDF…" at line 187 |
| SC4 | Number bases real-time, bit-field toggle, signed/unsigned two's complement | VERIFIED | `BitFieldView` wired in NumberBaseView.swift:47; `signed` toggle at line 94; `Int8/16/32/64(bitPattern:)` two's-complement in NumberBaseTransformer |
| SC5 | Text diff with line-level changes, word-level inline highlighting, line numbers, jump between diffs, unified patch | VERIFIED | `CollectionDifference` line diff + `Flint.diff(text1:text2:)` word diff in TextDiffTransformer.swift:347; `prevDiff()`/`nextDiff()` in TextDiffView.swift:159/171; `CopyButtonView(getText: { r.unifiedPatch })` at line 181 |

**Score: 5/5 Roadmap Success Criteria verified**

---

### Observable Truths (Plan Must-Haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SPM dependencies (ChromaKit 0.1.1, swift-markdown) resolve; SwiftDiff vendored Swift-6-clean; CSS bundled | VERIFIED | `grep ChromaKit Package.resolved` → FOUND; `grep swift-markdown Package.resolved` → FOUND; `grep .characters SwiftDiff/` → 0 matches; `github-markdown.css` = 253 lines, `prefers-color-scheme` present |
| 2 | User can enter regex pattern with g/i/m/s/x flag toggles and multi-line test string (RGX-01) | VERIFIED | Five `Toggle(.checkbox)` flag controls wired to `viewModel.flags` in RegexView.swift:232–268; `SyntaxEditorView` for test string |
| 3 | Matches highlight live, color-coded per capture group, with match-count badge; never freezes UI (RGX-02) | VERIFIED (code) | `applyHighlights` with `GroupColorPalette` per-group background attributes in RegexView.swift:125; match-count badge at line 311; `nonisolated static runWorker` ensures off-main eval. UAT needed for runtime freeze behaviour |
| 4 | Results table shows index, position, full match, and named + numbered capture groups (RGX-03) | VERIFIED | `DisclosureGroup("Match Results")` at RegexView.swift:337 rendering `index`, `position`, `matchedString`, `numberedGroups`, `namedGroups` from `RegexMatch` struct |
| 5 | Replace mode previews substitution; Patterns menu inserts email/URL/phone/date/IP presets (RGX-04) | VERIFIED | `Toggle("Enable Replace Mode")` at RegexView.swift:372; `Menu` with 5 presets including Email, URL (HTTP/HTTPS), IPv4 at lines 211–217; `RegexTransformer.substitute` called from ViewModel |
| 6 | Catastrophic backtracking pattern never freezes UI — timeout warning shows, last-good highlight stays dimmed (RGX-02 D-02) | VERIFIED (code) | `withThrowingTaskGroup` race at RegexViewModel.swift:151; `timedOut=true`, `outputDimmed=true`, message at lines 188–190. Runtime UAT required — see human verification |
| 7 | User can input HEX, RGB, HSL, HSV, OKLCH and see all formats simultaneously with swatch + alpha (CLR-01) | VERIFIED | All 5 `formatRow` sections in ColorView.swift:135–193; CR-03 fix: `normalizedHue` in ColorTransformer.swift:170 maps hue=360→red correctly |
| 8 | NSColorSampler eyedropper + system ColorPicker (CLR-02) | VERIFIED (code) | `NSColorSampler().show` at ColorView.swift:106; `ColorPicker` at line 119. Runtime UAT required |
| 9 | R/G/B and H/S/L sliders interactive (CLR-03) | VERIFIED | `slidersSection` at ColorView.swift:230 with R/G/B sliders at 234–236 and H/S/L/saturation/value sliders at 238+ |
| 10 | WCAG AA/AAA contrast result for two colors; any format copies in one click (CLR-04) | VERIFIED | `wcagSection` at ColorView.swift:258; `WCAGResults` computed by `ColorTransformer.wcagContrastRatio`; `CopyButtonView` per format row |
| 11 | Split editor/preview with live GFM (tables, task lists, fenced code, strikethrough), debounced (MD-01) | VERIFIED | `HSplitView`/segmented toggle in MarkdownView.swift; `scheduleRender()` with 300ms debounce; all GFM node visitors in MarkdownTransformer.swift |
| 12 | Editor highlights Markdown syntax; preview highlights fenced code blocks (MD-02) | PARTIAL | **Editor:** `SyntaxEditorView` has `isRichText=false` — plain monospace only, no attribute-based Markdown syntax coloring. **Preview:** `github-markdown.css` provides `pre code` block background + monospace font styling but no per-language token coloring. The plan must-have explicitly requires "Editor highlights Markdown syntax" which is unimplemented. ROADMAP SC3 does NOT require editor syntax highlighting and is met. |
| 13 | User can export as copied HTML, saved .html, or saved .pdf (MD-03) | VERIFIED (code) | "Copy HTML" button at MarkdownView.swift:170; "Save as HTML…" at 182; "Save as PDF…" at 187; CR-02 fix: `MarkdownPDFExporter` self-retaining via `strongSelf` at lines 240/248. PDF export runtime UAT required |
| 14 | Word count and reading-time footer; toolbar inserts bold/italic/link/image/code/table (MD-04) | VERIFIED | `wordCountText`/`readingTimeText` in footer at MarkdownView.swift:153/162; 7 toolbar buttons at lines 293–316 |
| 15 | User can type in binary, octal, decimal, or hex and all bases update in real time (NUM-01) | VERIFIED | 4 `TextField` rows bound to `binText`/`octText`/`decText`/`hexText` in NumberBaseView.swift; `update(from:text:)` in ViewModel triggers `deriveAllFields()` |
| 16 | Bit-length selector (8/16/32/64) and signed/unsigned toggle with two's-complement (NUM-02) | VERIFIED | `Picker` segmented at NumberBaseView.swift:77–87 for 8/16/32/64; `Toggle("Signed")` at line 94; `Int8/16/32/64(bitPattern:)` dispatch in NumberBaseTransformer |
| 17 | Interactive bit-field toggles individual bits and updates all fields (NUM-03) | VERIFIED | `BitFieldView` wired at NumberBaseView.swift:47 with `onToggle` calling `viewModel.pattern = newPattern; syncFieldsFromViewModel()` |
| 18 | Side-by-side and unified diff view toggle; line-level with word-level inline highlights, line numbers, color coding (DIFF-01, DIFF-02) | VERIFIED | `DiffViewMode` picker at TextDiffView.swift:91; `HSplitView` for side-by-side; `DiffLine` carries `wordSegments` from `Flint.diff()`; `DiffLineRowView` colors added/removed/unchanged lines |
| 19 | Jump to next/previous diff; copy unified patch; ignore-whitespace and ignore-case toggles (DIFF-03, DIFF-04) | VERIFIED | `prevDiff()`/`nextDiff()` buttons at TextDiffView.swift:159/171; `CopyButtonView(getText: { r.unifiedPatch })` at line 181; `Toggle("Ignore Whitespace")` at line 80; `Toggle("Ignore Case")` at line 84 |

**Score: 18/19 must-haves verified** (MD-02 editor syntax highlight is PARTIAL — plan truth not fully met; ROADMAP SC3 is met)

---

### Three Critical Bug Fixes (commit 55e63a6) — Confirmed Present

| Fix | Code Location | Evidence |
|-----|--------------|----------|
| CR-01: RegexViewModel off-main eval | `RegexViewModel.swift:245` | `private nonisolated static func runWorker(...)` — synchronous transformer forced off MainActor |
| CR-02: MarkdownPDFExporter self-retention | `MarkdownView.swift:240,248` | `private var strongSelf: MarkdownPDFExporter?` set to `self` on init; cleared after `createPDF` completes |
| CR-03: HSL/HSV hue=360 → red | `ColorTransformer.swift:170,178,233` | `private static func normalizedHue(_ hue: Double) -> Double` using `truncatingRemainder(dividingBy: 360.0)`; called at top of both `hslToRGB` and `hsvToRGB` |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Tools/TextDiff/SwiftDiff/diff.swift` | Vendored Myers diff, Swift-6-clean, `public func diff(text1:text2:)` | VERIFIED | Exists; no `.characters` tokens; `func diff` present |
| `Resources/github-markdown.css` | 40+ lines, `prefers-color-scheme` dark | VERIFIED | 253 lines; dark mode media query present |
| `FlintTests/SwiftDiffVendorTests.swift` | Vendor correctness tests | VERIFIED | File exists in FlintTests/ |
| `Tools/Regex/RegexTransformer.swift` | Pure matches/substitute, `enum RegexTransformer` | VERIFIED | Foundation-only; no SwiftUI import; `enum RegexTransformer` with `matches` and `substitute` |
| `Tools/Regex/RegexViewModel.swift` | Off-main eval, `withThrowingTaskGroup`, `ToolShortcutActions` | VERIFIED | All three present; `nonisolated static runWorker` for CR-01 |
| `Tools/Regex/RegexView.swift` | Pattern + flags + test editor + results table + replace | VERIFIED | `.toolShortcuts(viewModel)` applied; all sections present |
| `Tools/Regex/RegexDefinition.swift` | id "regex", category .analysis, `detectionPredicate: nil` | VERIFIED | Matches specification |
| `Tools/Color/ColorTransformer.swift` | HEX/RGB/HSL/HSV/OKLCH math, WCAG, gamut check | VERIFIED | All format conversions; `normalizedHue` CR-03 fix; `relativeLuminance` with 0.03928 threshold (IN-02 open) |
| `Tools/Color/ColorView.swift` | Swatch + eyedropper + format rows + sliders + WCAG | VERIFIED | All sections present; `NSColorSampler().show` wired |
| `Tools/Color/ColorDefinition.swift` | id "color", hex detection predicate | VERIFIED | Narrow `#RGB/#RRGGBB/#RRGGBBAA` predicate present |
| `Tools/Markdown/MarkdownTransformer.swift` | swift-markdown AST→HTML, GFM features | VERIFIED | Full GFM visitor including tables, strikethrough, task lists, fenced code |
| `Tools/Markdown/MarkdownView.swift` | Split editor/preview + toolbar + footer + export | VERIFIED | `HSplitView`; toolbar 7 buttons; footer; PDF export via `MarkdownPDFExporter` |
| `UI/Components/WebPreviewView.swift` | WKWebView, JS-off, nav-blocked, identical-HTML guard | VERIFIED | `allowsContentJavaScript = false`; `lastLoadedHTML` guard; navigation policy blocks links |
| `Tools/NumberBase/NumberBaseTransformer.swift` | 4-base conversion, two's complement, bit-toggle | VERIFIED | All bases; `Int8/16/32/64(bitPattern:)` signed; `toggleBit`; `UInt64.max` for w64 mask |
| `UI/Components/BitFieldView.swift` | Interactive bit toggle grid, MSB-left, VoiceOver labels | VERIFIED | Pure SwiftUI; 8 bits/row; `accessibilityLabel("Bit N, value 0/1")` per button |
| `Tools/TextDiff/TextDiffTransformer.swift` | Line diff via CollectionDifference + word diff via SwiftDiff | VERIFIED | `difference(from:)` + `Flint.diff(text1:text2:)` both called |
| `Tools/TextDiff/TextDiffView.swift` | Side-by-side/unified, next/prev, copy patch, ignore toggles | VERIFIED | All four DIFF requirements present |
| `Core/Services/ToolRegistry.swift` | All 5 Phase-2 `*Definition.make()` calls appended | VERIFIED | 12 total `Definition.make()` calls; all 5 Phase-2 tools present; Phase-1 tools unchanged |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `RegexDefinition.swift` | `RegexView` | `makeView` factory | VERIFIED | `makeView: { @MainActor in AnyView(RegexView()) }` at line 27 |
| `RegexViewModel.swift` | `RegexTransformer` | `nonisolated static runWorker` | VERIFIED | `RegexTransformer.matches` called at RegexViewModel.swift:252 inside `nonisolated static` worker |
| `ColorDefinition.swift` | hex detection | `detectionPredicate` | VERIFIED | Narrow `#RGB/#RRGGBB/#RRGGBBAA` predicate in ColorDefinition.swift |
| `ToolRegistry.swift` | All 5 Phase-2 definitions | `tools` array append | VERIFIED | Lines 31–35 of ToolRegistry.swift |
| `MarkdownView.swift` | `MarkdownPDFExporter` | `saveAsPDF()` | VERIFIED | `MarkdownPDFExporter.export(html:to:)` called at MarkdownView.swift:229 |
| `NumberBaseView.swift` | `BitFieldView` | `BitFieldView(pattern:width:onToggle:)` | VERIFIED | Wired at NumberBaseView.swift:47–56; `onToggle` updates `viewModel.pattern` |
| `TextDiffTransformer.swift` | SwiftDiff `diff()` | `Flint.diff(text1:text2:)` | VERIFIED | Qualified module call at TextDiffTransformer.swift:347 |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `RegexView` → match highlight | `viewModel.matches` | `RegexTransformer.matches()` via `runWorker` | Yes — NSRegularExpression on real input | FLOWING |
| `ColorView` → format rows | `viewModel.canonicalRGBA` | `ColorTransformer.parseHex/hslToRGB/etc.` on user input | Yes — pure math transforms | FLOWING |
| `MarkdownView` → `WebPreviewView` | `viewModel.html` | `MarkdownTransformer.fullStyledHTML(source)` with bundled CSS | Yes — swift-markdown AST parse | FLOWING |
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
| RGX-02 | 02-02, 02-07 | Live highlighting, never freeze | SATISFIED (code) | nonisolated static runWorker + withThrowingTaskGroup |
| RGX-03 | 02-02 | Results table: index, position, full match, capture groups | SATISFIED | DisclosureGroup("Match Results") with RegexMatch fields |
| RGX-04 | 02-02 | Replace mode + pattern library | SATISFIED | replaceMode toggle + Menu with 5 presets |
| CLR-01 | 02-03 | All formats (HEX/RGB/HSL/HSV/OKLCH) simultaneous + alpha | SATISFIED | 5 formatRow sections; normalizedHue CR-03 fix |
| CLR-02 | 02-03 | NSColorSampler eyedropper + system color panel | SATISFIED (code) | NSColorSampler().show + ColorPicker |
| CLR-03 | 02-03 | R/G/B, H/S/L sliders interactive | SATISFIED | slidersSection with all sliders |
| CLR-04 | 02-03 | WCAG AA/AAA contrast checker | SATISFIED | wcagSection + WCAGResults |
| MD-01 | 02-04 | Split editor/preview, live GFM, debounced | SATISFIED | HSplitView + debounced scheduleRender + full GFM visitors |
| MD-02 | 02-04 | Editor highlights Markdown syntax; preview highlights code blocks | PARTIAL | Editor: plain SyntaxEditorView (no attribute-based Markdown highlight). Preview: CSS-only pre/code block styling (no token coloring). ROADMAP SC3 is met; requirement only partially met |
| MD-03 | 02-04 | Export: copied HTML, saved .html, saved .pdf | SATISFIED (code) | Copy HTML button + Save as HTML + Save as PDF (self-retaining exporter) |
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

### Human Verification Required

#### 1. Regex Never-Freeze (RGX-02, CR-01 runtime confirmation)

**Test:** Open Regex Tester; paste pattern `(a+)+$` into pattern field; paste `aaaaaaaaaaaaaaaaaaaa!` (20 a's + exclamation) into test string.
**Expected:** The app remains fully responsive throughout typing; within ~2 seconds a warning banner appears: "Pattern too slow — possible catastrophic backtracking"; the last-good highlight (if any) stays visible at reduced opacity; the UI never becomes unresponsive.
**Why human:** The `nonisolated static runWorker` fix is confirmed in source, but actual MacOS Swift concurrency off-main scheduling under catastrophic backtracking requires running the app.

#### 2. Markdown PDF Export (MD-03, CR-02 runtime confirmation)

**Test:** Open Markdown Previewer; type `# Hello World` and some prose; click "Save ▾" → "Save as PDF…"; choose a filename and click Save.
**Expected:** A non-blank, visually styled PDF file appears at the chosen path; no silent failure; if a write error occurs an alert is shown.
**Why human:** The `MarkdownPDFExporter.strongSelf` self-retention fix is confirmed in source; WKWebView.createPDF async completion and the ARC lifecycle require a running app.

#### 3. Color Eyedropper (CLR-02, runtime)

**Test:** Open Color Converter; click the eyedropper (magnifying-glass) button; hover over a brightly-coloured area of another window and click.
**Expected:** All format rows (HEX, RGB, HSL, HSV, OKLCH) update to the picked colour; no system permission dialog is shown.
**Why human:** `NSColorSampler().show()` is code-confirmed; the zero-permission eyedropper UX requires runtime.

#### 4. OKLCH Out-of-Gamut Warning (CLR-01)

**Test:** In Color Converter, enter OKLCH values L=0.7, C=0.4, H=145.
**Expected:** The warning banner "Out of sRGB gamut — clipped" appears above the swatch.
**Why human:** `outOfGamutWarning` is driven by `GamutResult.isOutOfGamut` from `oklchToLinearSRGB_unclamped`; the specific threshold values require runtime execution.

#### 5. MD-02 Editor Syntax Highlight — Developer Decision Required

**Test:** Open Markdown Previewer; type `# Hello **world**` and observe the editor pane.
**Expected per requirement:** The heading `#` marker and `**bold**` delimiters should appear with distinct visual syntax coloring in the editor.
**Actual:** The editor uses `SyntaxEditorView` with `isRichText=false` — plain monospace text, no syntax attribute pass applied. The plan explicitly specified "Markdown-syntax attribute-only highlight pass (re-entrancy guarded, never reset .string)" but this was not implemented. The REQUIREMENTS.md requirement MD-02 is only partially met.
**Developer decision required:** Determine whether the plain-monospace editor is acceptable for v1 (accepting the MD-02 partial implementation), or whether a gap-closure plan is needed to add the attribute-only Markdown syntax highlight pass.

#### 6. Launcher Visibility and Fuzzy Search

**Test:** Open the app popover; type "regex", "color", "markdown", "base", "diff" one at a time.
**Expected:** Each query surfaces the corresponding tool in the launcher results.
**Why human:** ToolRegistry.search() keyword matching is code-confirmed; the live popover UI requires a running app.

#### 7. Detection Chain Correctness (INFRA-06)

**Test:** Copy `#3366FF` to clipboard; switch to Flint. Then separately copy a JSON string and a JWT and confirm they still route to JSON Formatter and JWT Decoder respectively.
**Expected:** Hex color routes to Color Converter; no existing Phase-1 tool detection is shadowed.
**Why human:** ColorDefinition.detectionPredicate is narrow and code-confirmed; the full first-match-wins chain across 12 tools requires a running app.

---

### Gaps Summary

No blocking gaps against ROADMAP Success Criteria. All 5 roadmap success criteria are verified in code.

**MD-02 partial implementation** (plan must-have only): The Markdown editor uses plain `SyntaxEditorView` with `isRichText=false`, providing no attribute-based Markdown syntax coloring. The plan explicitly required a "Markdown-syntax attribute-only highlight pass." ROADMAP SC3 does NOT require editor syntax highlighting and is fully met. This is a plan-vs-implementation deviation that requires a developer decision (see human verification item 5 above).

**Remaining warnings from code review (non-blocking):**
- WR-01: Capture-group highlight uses substring search instead of stored NSRange (wrong position for duplicate group text patterns)
- WR-02: `MarkdownViewModel.runRender()` runs synchronously on MainActor (jank risk for large inputs)
- WR-04: `applyWidthChange` triggers `deriveAllFields()` twice
- WR-05: Dead `cleanupEfficiency`/`cleanupSemantic` functions have double-`popLast` porting error

All four warnings are tracked in `02-REVIEW.md` as "non-blocking polish tracked for a later pass."

---

_Verified: 2026-06-26T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
