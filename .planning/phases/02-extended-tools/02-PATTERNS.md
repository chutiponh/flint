# Phase 2: Extended Tools - Pattern Map

**Mapped:** 2026-06-26
**Files analyzed:** 25 new + 1 modified (ToolRegistry append)
**Analogs found:** 25 / 25 (every new file maps to a verified Phase-1 analog)

> Phase 2 builds five tools (Regex, Color, Markdown, NumberBase, TextDiff) as the exact Phase-1 quad: pure `*Transformer` + `@Observable *ViewModel` + `*View` + `*Definition`, plus per-tool `*TransformerTests`, plus three new shared `UI/Components` views (`WebPreviewView`, `BitFieldView`) and a vendored `SwiftDiff/`. The quad is copied 1:1 from existing tools. This map assigns each new file its closest existing analog with line-level excerpts.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Tools/Regex/RegexTransformer.swift` | transformer | transform | `Tools/JSONFormatter/JSONTransformer.swift` | role+flow exact |
| `Tools/Regex/RegexViewModel.swift` | viewModel | event-driven (off-main + timeout) | `Tools/Hash/HashViewModel.swift` (Task/cancel) + `JSONFormatterViewModel` (debounce/last-good) | role exact, flow blend |
| `Tools/Regex/RegexView.swift` | view | request-response | `Tools/JSONFormatter/JSONFormatterView.swift` | role exact |
| `Tools/Regex/RegexDefinition.swift` | definition | config | `Tools/Base64/Base64Definition.swift` (has predicate) | exact |
| `FlintTests/RegexTransformerTests.swift` | test | transform | `FlintTests/JSONTransformerTests.swift` | exact |
| `Tools/Color/ColorTransformer.swift` | transformer | transform | `Tools/JSONFormatter/JSONTransformer.swift` | role+flow exact |
| `Tools/Color/ColorViewModel.swift` | viewModel | request-response (synchronous, no debounce) | `Tools/JSONFormatter/JSONFormatterViewModel.swift` | role exact |
| `Tools/Color/ColorView.swift` | view | request-response | `Tools/Hash/HashView.swift` (multi-row + copy + NSColorSampler/picker) | role exact |
| `Tools/Color/ColorDefinition.swift` | definition | config | `Tools/JSONFormatter/JSONFormatterDefinition.swift` (predicate) | exact |
| `FlintTests/ColorTransformerTests.swift` | test | transform | `FlintTests/HashTransformerTests.swift` (reference vectors) | exact |
| `Tools/Markdown/MarkdownTransformer.swift` | transformer | transform | `Tools/JSONFormatter/JSONTransformer.swift` | role+flow exact |
| `Tools/Markdown/MarkdownViewModel.swift` | viewModel | event-driven (debounced render) | `Tools/JSONFormatter/JSONFormatterViewModel.swift` | role+flow exact |
| `Tools/Markdown/MarkdownView.swift` | view | request-response (split/toggle) | `Tools/JSONFormatter/JSONFormatterView.swift` (HSplitView) | role exact |
| `Tools/Markdown/MarkdownDefinition.swift` | definition | config | `Tools/Hash/HashDefinition.swift` (no predicate) | exact |
| `FlintTests/MarkdownTransformerTests.swift` | test | transform | `FlintTests/JSONTransformerTests.swift` | exact |
| `UI/Components/WebPreviewView.swift` | component | render | `UI/Components/SyntaxEditorView.swift` (NSViewRepresentable + re-render guard) | role+flow exact |
| `Tools/NumberBase/NumberBaseTransformer.swift` | transformer | transform | `Tools/JSONFormatter/JSONTransformer.swift` | role+flow exact |
| `Tools/NumberBase/NumberBaseViewModel.swift` | viewModel | request-response (synchronous) | `Tools/JSONFormatter/JSONFormatterViewModel.swift` | role exact |
| `Tools/NumberBase/NumberBaseView.swift` | view | request-response (multi-field) | `Tools/Hash/HashView.swift` (multi-row + copy) | role exact |
| `Tools/NumberBase/NumberBaseDefinition.swift` | definition | config | `Tools/Hash/HashDefinition.swift` (no predicate) | exact |
| `FlintTests/NumberBaseTransformerTests.swift` | test | transform | `FlintTests/HashTransformerTests.swift` (matrix) | exact |
| `UI/Components/BitFieldView.swift` | component | request-response | `UI/Components/CopyButtonView.swift` / `WarningBannerView.swift` (small reusable view) | role match |
| `Tools/TextDiff/TextDiffTransformer.swift` | transformer | transform | `Tools/JSONFormatter/JSONTransformer.swift` | role+flow exact |
| `Tools/TextDiff/TextDiffViewModel.swift` | viewModel | event-driven (debounced) | `Tools/JSONFormatter/JSONFormatterViewModel.swift` | role exact |
| `Tools/TextDiff/TextDiffView.swift` | view | request-response (stacked/side-by-side) | `Tools/JSONFormatter/JSONFormatterView.swift` (HSplitView) | role exact |
| `Tools/TextDiff/TextDiffDefinition.swift` | definition | config | `Tools/Hash/HashDefinition.swift` (no predicate) | exact |
| `FlintTests/TextDiffTransformerTests.swift` | test | transform | `FlintTests/JSONTransformerTests.swift` | exact |
| `Tools/TextDiff/SwiftDiff/*.swift` (vendored) | utility | transform | N/A — vendored external source (see "No Analog") | — |
| `Core/Services/ToolRegistry.swift` (MODIFY — append 5 `make()` calls only) | service | config | self (existing `tools` array, lines 15-23) | exact |

---

## Pattern Assignments

### All five `*Transformer.swift` (transformer, pure transform)

**Analog:** `Tools/JSONFormatter/JSONTransformer.swift` (also `Base64Transformer`, `HashTransformer` — all 9 follow this shape)

**Shape:** `enum *Transformer { static func … }` — `import Foundation` ONLY (no SwiftUI/AppKit). Nested error struct/enum. Returns `Result<T, Error>` or a plain value. Never force-unwraps; explicit size/garbage guards (INFRA-17).

**Imports + enum + nested error** (JSONTransformer.swift lines 6-22):
```swift
import Foundation

enum JSONTransformer {
    struct JSONError: Error, Equatable {
        let message: String
        let line: Int?
        let column: Int?

        var displayMessage: String { … }
    }
```

**Result-returning static func with input guards** (JSONTransformer.swift lines 28-48):
```swift
static func prettyPrint(_ input: String, indent: Int = 2) -> Result<String, JSONError> {
    guard let data = input.data(using: .utf8) else {
        return .failure(JSONError(message: "Invalid UTF-8 encoding", line: nil, column: nil))
    }
    // INFRA-17: size guard — reject absurdly large inputs gracefully
    guard data.count <= 50_000_000 else {
        return .failure(JSONError(message: "Input too large (>50 MB)", line: nil, column: nil))
    }
    do {
        … // do the work
        return .success(str)
    } catch {
        return .failure(jsonError(from: error, in: input))
    }
}
```

**Per-tool transformer notes (from RESEARCH §3-7):**
- `RegexTransformer`: `matches(pattern:flags:in:) -> Result<[RegexMatch], TransformError>` + `substitute(pattern:flags:in:template:)`. Pure & synchronous — **timeout/threading live in the ViewModel, NOT here** (keeps it unit-testable). `RegexMatch` carries full-match range, numbered ranges (`match.range(at:)`), named ranges (`match.range(withName:)`), index/position.
- `ColorTransformer`: pure RGB↔HSL↔HSV + HEX math; OKLCH forward via ChromaKit, reverse hand-computed; WCAG ratio pure function; out-of-gamut range check returns a flag. Canonical internal repr = sRGB RGBA 0...1.
- `MarkdownTransformer`: `Markdown.Document(parsing:)` → custom `MarkupVisitor<String>` emitting HTML-escaped controlled HTML; word-count + reading-time pure functions.
- `NumberBaseTransformer`: canonical `UInt64` + width + signed; `String(value, radix:)` / `UInt64(_, radix:)`; two's-complement render; mask + overflow flag.
- `TextDiffTransformer`: `diff(original:changed:ignoreWhitespace:ignoreCase:) -> DiffResult` using `CollectionDifference` (line) + vendored `SwiftDiff.diff` (word); unified-patch string emitter.

---

### All five `*ViewModel.swift` (viewModel)

**Primary analog:** `Tools/JSONFormatter/JSONFormatterViewModel.swift` (debounce + last-good-output + history)
**Secondary analog for Regex async/cancel:** `Tools/Hash/HashViewModel.swift` (Task lifecycle, cancel, `@MainActor.run`)

**Class declaration + observable state + injected history** (JSONFormatterViewModel.swift lines 28-64):
```swift
@Observable
@MainActor
final class JSONFormatterViewModel: ToolShortcutActions {
    var input: String = "" {
        didSet { scheduleTransform() }
    }
    var output: String = ""
    var outputDimmed: Bool = false        // CF-02: dim, never blank
    var errorMessage: String? = nil

    /// Injected history write closure. ViewModel NEVER imports GRDB directly (INFRA-09).
    private let onSaveHistory: (HistoryEntry) -> Void
    private let debounce = Debounce()

    init(onSaveHistory: @escaping (HistoryEntry) -> Void) {
        self.onSaveHistory = onSaveHistory
    }
```

**Debounce: reuse the existing actor — do NOT redefine** (declared once in JSONFormatterViewModel.swift lines 13-24):
```swift
actor Debounce: Sendable {
    private var task: Task<Void, Never>?
    func schedule(delay: Duration, action: @Sendable @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }
}
```

**scheduleTransform + empty guard** (JSONFormatterViewModel.swift lines 68-80):
```swift
private func scheduleTransform() {
    guard !input.isEmpty else {
        output = ""; outputDimmed = false; errorMessage = nil
        return
    }
    Task {
        await debounce.schedule(delay: .milliseconds(150)) { [weak self] in
            await self?.runTransform()
        }
    }
}
```

**runTransform: success keeps output + writes history; failure dims + sets error (CF-02)** (JSONFormatterViewModel.swift lines 94-122):
```swift
switch result {
case .success(let formatted):
    output = formatted
    outputDimmed = false
    errorMessage = nil
    onSaveHistory(HistoryEntry(
        tool: "json-formatter", input: input, output: formatted,
        timestamp: Date(), pinned: false
    ))
case .failure(let error):
    // D-11/CF-02: keep last valid output visible but dimmed — do NOT clear output
    outputDimmed = true
    errorMessage = error.displayMessage
}
```

**ToolShortcutActions conformance — every VM implements these two** (JSONFormatterViewModel.swift lines 85-92):
```swift
func primaryOutput() -> String? { output.isEmpty ? nil : output }
func clearInput() { input = "" }
```

**Regex-only: off-main eval + cancel-in-flight (D-02).** Copy the Task-lifecycle/cancel/`@MainActor.run` shape from `HashViewModel.swift` lines 105-142 (`startFileHash`/`cancelFileHash`), then add the 2s timeout via `withThrowingTaskGroup` racing eval vs `Task.sleep(.seconds(2))`. On timeout → `WarningBannerView(.warning, "Pattern too slow…")` + keep `outputDimmed` highlight. The transformer stays pure; only the VM owns threading.

```swift
// HashViewModel.swift lines 105-142 — Task store + cancel + main-actor publish pattern to copy:
func startFileHash(url: URL) {
    fileHashTask?.cancel()
    …
    fileHashTask = Task {
        let result = await HashTransformer.hashFile(url: url) { … }
        await MainActor.run { [weak self] in … }
    }
}
func cancelFileHash() {
    fileHashTask?.cancel()
    fileHashTask = nil
    isHashing = false
}
```

**Color/NumberBase note:** synchronous & cheap — call the transformer directly in `didSet` (no `Debounce`). Use a single canonical source-of-truth property; derive all display rows from it (avoid N independent `@State` strings that drift). VM still conforms to `ToolShortcutActions`.

---

### All five `*View.swift` (view)

**Two valid view-creation conventions exist in Phase 1 — pick one per tool:**

**Convention A — lazy `.onAppear` (view takes no args; Definition calls `AnyView(*View())`):** `JSONFormatterView.swift` lines 8-31 / `Base64View.swift` lines 9-32.
```swift
struct JSONFormatterView: View {
    @Environment(HistoryStore.self) private var historyStore
    @State private var viewModel: JSONFormatterViewModel?
    var body: some View {
        Group {
            if let vm = viewModel { JSONFormatterContentView(viewModel: vm) }
            else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = JSONFormatterViewModel(
                    onSaveHistory: { [historyStore] entry in historyStore.save(entry) }
                )
            }
        }
    }
}
```

**Convention B — wrapper injects history (view takes `onSaveHistory:`; Definition wraps it):** `HashView.swift` lines 8-18 + `HashDefinition.swift` lines 17-34 (`HashViewWrapper`).
```swift
struct HashView: View {
    @State private var viewModel: HashViewModel
    @State private var hmacKey: String = ""  // sensitive View-local state, never on VM
    init(onSaveHistory: @escaping (HistoryEntry) -> Void) {
        _viewModel = State(initialValue: HashViewModel(onSaveHistory: onSaveHistory))
    }
    …
}
```

**Content view: `@Bindable` + reusable components + `.toolShortcuts(viewModel)`** (JSONFormatterView.swift lines 33-123):
```swift
private struct JSONFormatterContentView: View {
    @Bindable var viewModel: JSONFormatterViewModel
    var body: some View {
        VStack(spacing: 0) {
            // controls bar … Picker / Toggle(.checkbox) / Spacer …
            if !viewModel.output.isEmpty {
                CopyButtonView(getText: { viewModel.output })   // CF-03
            }
            Divider()
            HSplitView {                                        // CF-05 roomy layout
                SyntaxEditorView(text: $viewModel.input, accessibilityLabel: "JSON input")
                InlineErrorView(message: viewModel.errorMessage)        // CF-02
                CodeDisplayView(code: viewModel.output, language: "json")
                    .opacity(viewModel.outputDimmed ? 0.4 : 1.0)        // CF-02 dim
            }
        }
        .navigationTitle("JSON Formatter")
        .toolShortcuts(viewModel)                               // INFRA-16 ⌘⇧C / ⌘⌫
    }
}
```

**Multi-row output view (Color rows, NumberBase fields):** copy `HashView.swift` lines 109-128 — labeled row + monospaced value + trailing `CopyButtonView`:
```swift
HStack(alignment: .top) {
    VStack(alignment: .leading, spacing: 2) {
        Text("HMAC").font(.caption).foregroundStyle(.secondary)
        Text(displayHMAC).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
    }
    Spacer()
    CopyButtonView(text: displayHMAC)
}
.padding(8).background(.quaternary.opacity(0.5)).cornerRadius(6)
```

**Color-specific (D-06):** `NSColorSampler().show { (nsColor: NSColor?) in … }` for the eyedropper (zero permissions), SwiftUI `ColorPicker("", selection: $color)` for the system panel. File/save panels: copy the `NSOpenPanel`/`NSSavePanel` pattern from `HashView.swift` lines 202-213 (`selectAndHashFile`).

**Markdown/TextDiff popover-vs-window duality (CF-05, D-09/D-15):** use `HSplitView` (as in JSONFormatterView lines 80-119) for the roomy window layout; gate a segmented `Picker`/toggle for the compact ~480pt popover. `MainWindowView.swift` calls `tool.makeView()` in the detail pane (lines 31-34) — the same view instance must render compact and roomy.

---

### All five `*Definition.swift` (definition, config)

**Analog with detection predicate (Regex, Color):** `Tools/JSONFormatter/JSONFormatterDefinition.swift` lines 7-35 / `Base64Definition.swift` lines 9-33.
```swift
enum JSONFormatterDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "json-formatter",
            name: "JSON Formatter",
            category: .formatting,
            keywords: ["json", "format", "pretty", …],
            sfSymbol: "curlybraces",
            detectionPredicate: { input in
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.first == "{" || trimmed.first == "[" else { return nil }  // fast pre-check
                guard … else { return nil }
                return DetectionResult(toolId: "json-formatter", toolName: "JSON Formatter",
                                       sample: String(trimmed.prefix(40)))
            },
            makeView: { AnyView(JSONFormatterView()) }
        )
    }
}
```

**Analog without predicate (Markdown, NumberBase, TextDiff — `detectionPredicate: nil`):** `Tools/Hash/HashDefinition.swift` lines 8-34. Note the `@MainActor in` annotation on `makeView` and the optional `HashViewWrapper` for history injection:
```swift
enum HashDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "hash-generator", name: "Hash Generator", category: .analysis,
            keywords: ["hash", "md5", "sha", …], sfSymbol: "number.square",
            detectionPredicate: nil,                       // search-only
            makeView: { @MainActor in AnyView(HashViewWrapper()) }
        )
    }
}
private struct HashViewWrapper: View {
    @Environment(HistoryStore.self) private var historyStore
    var body: some View { HashView { entry in historyStore.save(entry) } }
}
```

**Category assignments (RESEARCH §0 — DO NOT add an enum case):** Regex `.analysis`, Color `.conversion`, Markdown `.formatting`, NumberBase `.conversion`, TextDiff `.analysis`. `ToolCategory` is fixed at encoding/formatting/conversion/generation/analysis (`ToolCategory.swift` lines 4-10).

**Detection predicate rule (CF-04, RESEARCH §0):** only Color (hex `#RRGGBB`, narrow) and Regex (`/…/` literal, conservative) get a predicate; the other three pass `nil`. Place hex-color early in the chain (very specific), keep Regex conservative or search-only — do NOT shadow the existing JSON→JWT→Base64→URL→Timestamp→UUID order.

---

### All five `FlintTests/*TransformerTests.swift` (test)

**XCTest analog (Regex, Markdown, TextDiff):** `FlintTests/JSONTransformerTests.swift` lines 1-57.
```swift
import XCTest
@testable import Flint

final class JSONTransformerTests: XCTestCase {
    func testPrettyPrint_twoSpaceIndent() throws {
        let input = #"{"b":1,"a":2}"#
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)"); return
        }
        XCTAssertTrue(output.contains("  \"b\"") || output.contains("  \"a\""))
    }
}
```

**swift-testing analog with reference vectors (Color, NumberBase):** `FlintTests/HashTransformerTests.swift` lines 1-18 (`@Suite`/`@Test` + documented reference vectors block).
```swift
import Testing
import Foundation
@testable import Flint

@Suite("HashTransformer")
struct HashTransformerTests {
    // Reference vectors documented inline above each test
}
```

Either style is acceptable per RESEARCH §1. **MANDATORY per tool:** one test per requirement-ID behavior + a round-trip + a garbage/empty/no-crash test (INFRA-17). Only the pure transformer is unit-tested; ViewModel debounce/last-good/timeout is UI-state and is NOT unit-tested (the Regex 2s-timeout is a manual/UAT check — RESEARCH §10).

---

### `UI/Components/WebPreviewView.swift` (NEW component — Markdown only)

**Analog:** `UI/Components/SyntaxEditorView.swift` lines 9-50 (`NSViewRepresentable` + the re-render guard).

The WKWebView wrapper is "Pitfall #5 in different clothing" — guard identical HTML before reloading, exactly as `SyntaxEditorView.updateNSView` guards identical text (lines 40-50):
```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    // CRITICAL: guard prevents infinite re-render loop (Pitfall #5)
    guard textView.string != text else { return }
    …
}
```
For `WebPreviewView`: `guard html != lastLoadedHTML else { return }` before `loadHTMLString(html, baseURL: nil)`. Configure `defaultWebpagePreferences.allowsContentJavaScript = false`, block navigation via `WKNavigationDelegate.decidePolicyFor → .cancel`, defer instantiation to first appearance (cold-start budget). PDF via `WKWebView.createPDF(configuration:)` only AFTER navigation-finished.

---

### `UI/Components/BitFieldView.swift` (NEW component — NumberBase only)

**Analog:** `UI/Components/CopyButtonView.swift` lines 8-39 / `WarningBannerView.swift` lines 13-50 — small self-contained SwiftUI reusable view with accessibility labels. No NSViewRepresentable needed (pure SwiftUI grid of toggle buttons). Each bit toggle flips a bit and the VM XORs the canonical pattern. Apply `.accessibilityLabel` per bit (INFRA-15 convention, as every component does).

---

### `Core/Services/ToolRegistry.swift` (MODIFY — the ONE frozen-file edit)

**Analog:** the file's own existing `tools` array (lines 15-23). The ONLY allowed mutation is appending five `make()` calls; do NOT reshape the struct (RESEARCH §0, assumption A5). Order the edit AFTER all five quads exist so the build never references a missing `make()`.
```swift
tools = [
    JSONFormatterDefinition.make(),
    Base64Definition.make(),
    URLEncoderDefinition.make(),
    JWTDefinition.make(),
    TimestampDefinition.make(),
    HashDefinition.make(),
    UUIDDefinition.make(),
    // Phase 2 — append only:
    RegexDefinition.make(),
    ColorDefinition.make(),
    MarkdownDefinition.make(),
    NumberBaseDefinition.make(),
    TextDiffDefinition.make(),
]
```
The first-match-wins `detect(from:)` loop (lines 38-43) is unchanged — predicate order follows array order, so place Color/Regex entries deliberately (CF-04).

---

## Shared Patterns

### Per-field copy (CF-03)
**Source:** `UI/Components/CopyButtonView.swift` lines 8-39 + `Core/Extensions/View+CopyButton.swift` lines 11-16.
**Apply to:** every output row in all five tools.
```swift
CopyButtonView(text: "value")            // static
CopyButtonView(getText: { viewModel.output })  // dynamic
someView.copyButton(text: { viewModel.output }) // overlay modifier
```

### Graceful errors / never-blank (CF-02)
**Source:** `UI/Components/InlineErrorView.swift` lines 7-22 (orange caption, nil-hides) and `UI/Components/WarningBannerView.swift` lines 8-50 (`.warning`/`.error` severity banner).
**Apply to:** all five tools. `InlineErrorView` for mid-typing parse errors; `WarningBannerView(.warning, …)` for Regex timeout (D-02), OKLCH out-of-gamut (D-08), NumberBase overflow (NUM-03). Dim retained output via `.opacity(outputDimmed ? 0.4 : 1.0)`.
```swift
enum BannerSeverity { case warning; case error }
WarningBannerView(message: "Out of sRGB gamut — clipped", severity: .warning)
```

### Keyboard shortcuts (INFRA-16)
**Source:** `UI/Components/ToolShortcutActions.swift` lines 23-75.
**Apply to:** every new ViewModel conforms to `ToolShortcutActions` (`primaryOutput()`, `clearInput()`); every content view calls `.toolShortcuts(viewModel)`.
```swift
@MainActor protocol ToolShortcutActions: AnyObject {
    func primaryOutput() -> String?
    func clearInput()
}
// view: .toolShortcuts(viewModel)   // ⌘⇧C copy-output, ⌘⌫ clear-input
```

### Editable text input + re-render guard (Pitfall #5)
**Source:** `UI/Components/SyntaxEditorView.swift` lines 9-73 — reuse AS-IS for Regex test string, Markdown editor, Diff inputs. Any highlight pass must be attribute-only and must NOT reset `.string` (lines 40-50 guard).
```swift
SyntaxEditorView(text: $viewModel.input, accessibilityLabel: "…")
```

### Read-only highlighted display
**Source:** `UI/Components/CodeDisplayView.swift` lines 9-62 (HighlightSwift). Reuse for Markdown fenced-code display and any read-only output.

### History write via injected closure (INFRA-09 / Pitfall #3)
**Source:** `JSONFormatterViewModel.swift` lines 57-62 + 110-116; `HashViewModel.swift` lines 46-51.
**Apply to:** all five VMs — `private let onSaveHistory: (HistoryEntry) -> Void`, never import GRDB. Sensitive transient state (if any) stays View-local `@State`, never on the VM (Hash's `hmacKey` precedent, `HashView.swift` lines 11-13).

### File / save panels (Markdown export, Color eyedropper-adjacent)
**Source:** `HashView.swift` lines 202-213 (`NSOpenPanel`). Mirror with `NSSavePanel` for Markdown `.html`/`.pdf` export.

---

## No Analog Found

| File | Role | Reason |
|------|------|--------|
| `Tools/TextDiff/SwiftDiff/*.swift` (diff.swift, cleanup.swift, common.swift, String.swift, UnicodeScalar.swift, NSRegularExpression.swift) | vendored utility | External diff-match-patch port being vendored + Swift-6-patched (RESEARCH §2/§7). No in-repo analog — copy from `turbolent/SwiftDiff` source and apply the ~72 mechanical `.characters`→`` edits. Preserve public surface `func diff(text1:text2:timeout:) -> [Diff]` and `enum Diff`. Add `SwiftDiffVendorTests`. |
| Markdown CSS resource (GitHub-like stylesheet bundled in app) | config/resource | No existing bundled CSS asset in Phase 1; new project-file/resource addition (RESEARCH §5, D-11). |

The two new SPM packages (ChromaKit, swift-markdown) are project-file additions with no source-file analog — added via Xcode "Add Package" in the wave-1 setup task (RESEARCH §2).

## Metadata

**Analog search scope:** `Tools/**`, `UI/Components/**`, `UI/MainWindowView.swift`, `Core/Models/**`, `Core/Services/ToolRegistry.swift`, `Core/Extensions/View+CopyButton.swift`, `FlintTests/**`
**Files scanned:** 19 Swift files read (full); 57 Swift files enumerated
**Pattern extraction date:** 2026-06-26
