---
phase: 02-extended-tools
reviewed: 2026-06-26T12:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - Tools/Regex/RegexTransformer.swift
  - Tools/Regex/RegexViewModel.swift
  - Tools/Regex/RegexView.swift
  - Tools/Regex/RegexDefinition.swift
  - Tools/Color/ColorTransformer.swift
  - Tools/Color/ColorViewModel.swift
  - Tools/Color/ColorView.swift
  - Tools/Color/ColorDefinition.swift
  - Tools/Markdown/MarkdownTransformer.swift
  - Tools/Markdown/MarkdownViewModel.swift
  - Tools/Markdown/MarkdownView.swift
  - Tools/Markdown/MarkdownDefinition.swift
  - Tools/NumberBase/NumberBaseTransformer.swift
  - Tools/NumberBase/NumberBaseViewModel.swift
  - Tools/NumberBase/NumberBaseView.swift
  - Tools/NumberBase/NumberBaseDefinition.swift
  - Tools/TextDiff/TextDiffTransformer.swift
  - Tools/TextDiff/TextDiffViewModel.swift
  - Tools/TextDiff/TextDiffView.swift
  - Tools/TextDiff/TextDiffDefinition.swift
  - Tools/TextDiff/SwiftDiff/diff.swift
  - Tools/TextDiff/SwiftDiff/cleanup.swift
  - Tools/TextDiff/SwiftDiff/common.swift
  - UI/Components/WebPreviewView.swift
  - UI/Components/BitFieldView.swift
  - Core/Services/ToolRegistry.swift
findings:
  critical: 3
  warning: 5
  info: 4
  total: 12
critical_fixed: 3
warnings_fixed: 1
status: criticals_resolved
resolution_commit: 55e63a6
---

> **Resolution (2026-06-26):** All 3 Critical findings fixed in commit `55e63a6`
> (CR-01 regex off-main eval, CR-02 PDF exporter lifetime, CR-03 hue-360 → red),
> plus WR-03 (export error surfacing). Full test suite passes. Remaining warnings
> (WR-01 group-range highlight, WR-02 main-thread markdown render, WR-04 double-derive,
> WR-05 dead cleanup popLast) are non-blocking polish tracked for a later pass.

# Phase 02: Code Review Report

**Reviewed:** 2026-06-26T12:00:00Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

All five extended tools (Regex Tester, Color Converter, Markdown Previewer, Number Base Converter, Text Diff) plus shared UI components and ToolRegistry were reviewed. The implementations are structurally sound and show careful attention to INFRA-17 (never crash on bad input), XSS hardening, and the layered MVVM architecture. Three blockers require immediate attention before shipping: the Regex never-freeze guarantee is violated by a Swift concurrency isolation error, PDF export silently never completes due to an ARC lifecycle bug, and hue=360 produces the wrong color (black instead of red) in both HSL and HSV conversions.

---

## Critical Issues

### CR-01: RegexViewModel — Transformer Runs On MainActor, Freezing the UI

**File:** `Tools/Regex/RegexViewModel.swift:155`
**Issue:** The design comment claims the transformer "runs entirely non-isolated (off MainActor)" and the code comment at line 149 states the same. However, `withThrowingTaskGroup` child tasks created via `group.addTask { }` inside a `@MainActor`-isolated async function inherit the actor context of their enclosing scope. `RegexTransformer.matches()` is a fully synchronous function with no `await` points. It therefore runs to completion on the MainActor without yielding. A catastrophically backtracking pattern blocks the main thread for up to the full 2-second timeout window — the exact outcome D-02 and the "never freeze" contract prohibit.

The timeout sentinel (`Task.sleep(for: .seconds(2))`) runs on a background thread, but the MainActor is already blocked by the worker child task, so `group.next()` can never be polled and the race cannot fire until after the backtracking scan finishes.

**Fix:** Add `nonisolated` (via a detached wrapper or `@Sendable` closure) so the heavy computation runs off the MainActor:

```swift
// In runEval, replace the worker addTask with:
group.addTask { @Sendable in
    // Explicitly non-isolated: runs on cooperative thread pool, not MainActor
    let matchResult = RegexTransformer.matches(
        pattern: pattern,
        flags: flags,
        in: text
    )
    var substitution: Result<String, RegexTransformer.TransformError>? = nil
    if replaceMode && !template.isEmpty {
        substitution = RegexTransformer.substitute(
            pattern: pattern, flags: flags, in: text, template: template
        )
    }
    return EvalResult.completed(matchResult: matchResult, substitutionResult: substitution)
}
```

Swift 6 will infer `@Sendable` closures as non-isolated when there is no explicit actor annotation, but the `@MainActor` class context can propagate implicitly. Making the closure `@Sendable` with no actor annotation, or extracting the call to a `nonisolated static func` in a separate struct, guarantees off-main execution. Verify with `-strict-concurrency=complete`.

---

### CR-02: MarkdownView — PDF Export Coordinator Deallocated Before Callback Fires

**File:** `Tools/Markdown/MarkdownView.swift:214-242`
**Issue:** `saveAsPDF()` creates a local `coordinator` variable (line 224), sets it as `tempWebView.navigationDelegate` (line 230), and then discards it at line 242 with `_ = coordinator`. `WKWebView.navigationDelegate` is declared `weak var` by WebKit. The `coordinator` local is the sole strong owner, and it goes out of scope when `saveAsPDF()` returns. ARC immediately releases it. The `webView(_:didFinish:)` callback never fires (the delegate pointer is nil), `pendingPDFExport` is never called, and the PDF is silently never written to disk. The user experience is: user picks a filename, nothing happens, no error shown.

**Fix:** Retain the coordinator and `tempWebView` until the export completes, either by lifting them into `@State`, or by using the existing `previewCoordinator` `@State` variable that is already declared in `MarkdownContentView` but never populated:

```swift
// In MarkdownContentView, add an @State for the temp webview:
@State private var pdfExportCoordinator: WebPreviewView.Coordinator? = nil
@State private var pdfExportWebView: WKWebView? = nil

private func saveAsPDF() {
    let panel = NSSavePanel()
    // ... panel setup ...
    guard panel.runModal() == .OK, let url = panel.url else { return }

    let config = WKWebViewConfiguration()
    config.defaultWebpagePreferences.allowsContentJavaScript = false
    let tempWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1200),
                                configuration: config)
    let coordinator = WebPreviewView.Coordinator()
    coordinator.webView = tempWebView
    tempWebView.navigationDelegate = coordinator
    coordinator.pendingPDFExport = {
        let pdfConfig = WKPDFConfiguration()
        tempWebView.createPDF(configuration: pdfConfig) { [self] result in
            if case .success(let data) = result {
                try? data.write(to: url)
            }
            // Release after export
            self.pdfExportCoordinator = nil
            self.pdfExportWebView = nil
        }
    }
    // Retain both until the callback fires
    pdfExportCoordinator = coordinator
    pdfExportWebView = tempWebView
    tempWebView.loadHTMLString(viewModel.html, baseURL: nil)
}
```

---

### CR-03: ColorTransformer — hue=360 Produces Wrong Color (Black Instead of Red)

**File:** `Tools/Color/ColorTransformer.swift:177-184` and `235-242`
**Issue:** Both `hslToRGB` and `hsvToRGB` use a `switch h { ... case 300..<360: ... default: (r1,g1,b1) = (0,0,0) }` for the hue dispatch. The range `300..<360` excludes the value `360.0` exactly. When a user types `360` into the HSL or HSV hue field (or when the hue slider reaches its maximum with `min(360, newValue)`), `h == 360.0` falls to `default`, producing solid black `(0,0,0)`. Hue 360 is mathematically equivalent to hue 0 and should produce the same red. This is reachable via: hue slider at maximum, or typing "360" in the H field.

**Fix:** Normalize hue into `[0, 360)` before the switch in both functions, or add `case 360:` as an alias for `case 0`:

```swift
// Add to the top of hslToRGB and hsvToRGB, after extracting `let h = hsla.hue`:
let h = hsla.hue.truncatingRemainder(dividingBy: 360.0)  // maps 360 → 0, safe for 0...360
// Then the existing switch covers all cases correctly.
```

The same fix applies to `hsvToRGB`. Additionally, `updateFromHSL` / `updateFromHSV` in `ColorViewModel.swift` pass the raw parsed value without normalization, so the fix must be in the transformer, not the caller.

---

## Warnings

### WR-01: RegexView — Capture-Group Highlighting Uses String Search Instead of Stored Ranges

**File:** `Tools/Regex/RegexView.swift:153-166`
**Issue:** Per-capture-group highlight positions are resolved via `NSString.range(of:range:)` — a substring search of the group's text within the full-match range (line 154-157). This finds the *first occurrence* of the group's text within the match, not the *actual captured position*. For patterns like `/(a)(a)/` on the input `"aa"`, both groups capture `"a"`. The second group's range is resolved to position 0 (first `"a"`) rather than position 1. Groups with repeated substrings are therefore highlighted at the wrong position.

`RegexMatch` stores `numberedGroups: [String]` (text only) but not the `NSRange` for each group. The transformer at line 108 computes `match.range(at: g)` and has the correct range; it should be stored.

**Fix:** Add `let groupRanges: [NSRange]` to `RegexMatch` and populate it in `RegexTransformer.matches`. Use those ranges directly in `applyHighlights` instead of the substring search.

---

### WR-02: MarkdownViewModel — `runRender` Runs on MainActor, Blocking Heavy Renders

**File:** `Tools/Markdown/MarkdownViewModel.swift:73-98`
**Issue:** `runRender()` is a synchronous function that calls `MarkdownTransformer.fullStyledHTML(source)` — which includes a full GFM parse pass (swift-markdown AST walk + string building) on potentially multi-MB inputs. The `Debounce.schedule` closure calls `await self?.runRender()` which hops to the `@MainActor` and runs synchronously there. While markdown parsing is generally fast, the 10 MB input limit allows inputs that are noticeably slow (e.g., deeply-nested lists). This does not have the catastrophic risk of regex backtracking but can still cause jank during the render hop.

**Fix:** Extract the heavy transform into an `async` function that uses `Task.detached` or a `nonisolated` function:

```swift
private func runRender() async {
    let source = self.source  // capture on MainActor
    let result = await Task.detached(priority: .userInitiated) {
        MarkdownTransformer.fullStyledHTML(source)
    }.value
    // Back on MainActor (implicit hop):
    switch result { ... }
}
```

---

### WR-03: MarkdownView — Save as HTML Silently Discards Write Errors

**File:** `Tools/Markdown/MarkdownView.swift:211`
**Issue:** `try? viewModel.html.write(to: url, atomically: true, encoding: .utf8)` silently swallows any write error. On a full disk, a permissions error, or a network path that disconnects mid-write, the user receives no feedback — they selected a file path but nothing appears on disk.

**Fix:**
```swift
do {
    try viewModel.html.write(to: url, atomically: true, encoding: .utf8)
} catch {
    // Show an alert or surface an error state
    NSAlert(error: error).runModal()
}
```

---

### WR-04: NumberBaseViewModel — `applyWidthChange` Calls `deriveAllFields` Twice

**File:** `Tools/NumberBase/NumberBaseViewModel.swift:147-156`
**Issue:** `applyWidthChange` sets `width = newWidth` (line 148), which triggers `width.didSet { deriveAllFields() }`, and then sets `pattern = masked` (line 155), which triggers `pattern.didSet { deriveAllFields() }`. `deriveAllFields()` runs twice per width change. Each call formats all four number representations. This is harmless for correctness but wastes CPU and can cause two SwiftUI diff passes per UI update — relevant because `deriveAllFields` updates four `@Observable` published strings.

**Fix:**
```swift
func applyWidthChange(_ newWidth: BitWidth) {
    let masked = pattern & newWidth.mask
    let hadOverflow = masked != pattern
    if hadOverflow { overflowWarning = true }
    // Suppress intermediate didSet by assigning both at once via a local helper,
    // or by adding a private _width backing store to avoid triggering didSet:
    _width = newWidth   // bypass didSet
    pattern = masked    // single deriveAllFields
}
```

Alternatively, add an `isApplyingWidthChange: Bool` flag to suppress the `width.didSet` call.

---

### WR-05: cleanup.swift — Double `popLast` Removes Two Equalities Instead of One

**File:** `Tools/TextDiff/SwiftDiff/cleanup.swift:55-56` and `117-118`
**Issue:** Both `cleanupEfficiency` and `cleanupSemantic` call `equalities.removeLast()` immediately followed by `_ = equalities.popLast()`. This removes *two* elements from the equalities stack when only one should be popped. The original Google Diff Match and Patch algorithm (JavaScript reference) only pops one element in this position. The second call is a porting error.

The immediate production risk is low: neither `cleanupEfficiency` nor `cleanupSemantic` is called anywhere in the production code path (the vendored `diff()` function uses only `mergeDiffs`). However, these are `public func` exports that are dead but callable, and they would produce incorrect diff output if invoked.

**Fix:** Remove the redundant second call at each site:
```swift
// line 55: keep equalities.removeLast(), remove line 56
equalities.removeLast()
// _ = equalities.popLast()  ← delete this line

// Same fix at line 117-118
```

---

## Info

### IN-01: `previewCoordinator` State Variable Is Declared but Never Used

**File:** `Tools/Markdown/MarkdownView.swift:46`
**Issue:** `@State private var previewCoordinator: WebPreviewView.Coordinator? = nil` is declared in `MarkdownContentView` but never assigned or read. It was presumably intended as the retention mechanism for PDF export (see CR-02) but was never connected. It represents dead state.

**Fix:** Remove the declaration until CR-02 is fixed; then repurpose it as the retention variable for the export coordinator.

---

### IN-02: WCAG Luminance Uses Legacy 0.03928 Threshold

**File:** `Tools/Color/ColorTransformer.swift:370`
**Issue:** The WCAG 2.1 specification erratum updated the linearization threshold from 0.03928 to 0.04045. The code uses 0.03928 and comments that it is "the WCAG spec value." This differs from what most modern WCAG checkers report. The practical difference is negligible (affects only colors near that threshold by less than 0.01% luminance) but can cause a borderline color to show PASS when a strict WCAG 2.1 checker would show FAIL.

**Fix:** Change `0.03928` to `0.04045` to match the IEC 61966-2-1 transfer function and current WCAG 2.1 practice.

---

### IN-03: Regex Loop Iterates Once for Zero Capture Groups

**File:** `Tools/Regex/RegexTransformer.swift:106-113`
**Issue:** The loop `for g in 1...max(1, groupCount)` when `groupCount == 0` creates range `1...1` and iterates once, only to hit `guard g <= groupCount else { break }` immediately. It is a harmless no-op but unnecessarily allocates a loop iteration.

**Fix:** Add an early-exit guard before the loop:
```swift
guard groupCount > 0 else { return }  // or just:
if groupCount > 0 {
    for g in 1...groupCount { ... }
}
```

---

### IN-04: ToolRegistry Comment Misstates Detection-Chain Order

**File:** `Core/Services/ToolRegistry.swift:51`
**Issue:** The `detect` method comment reads "Ordered: JSON → JWT → Base64 → URL-encoded → URL → Timestamp → UUID" but the registered array now includes Phase-2 tools, with `ColorDefinition` (which has an active predicate) appended after `UUIDDefinition`. The comment does not reflect the full current order and will mislead future maintainers about which predicate fires first.

**Fix:** Update the comment to list all registered tools with predicates in insertion order, noting `ColorDefinition` as the first Phase-2 entry with an active predicate.

---

_Reviewed: 2026-06-26T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
