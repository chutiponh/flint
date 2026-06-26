// UI/Components/SyntaxEditorView.swift
// NSViewRepresentable wrapping NSTextView for editable code input.
// CRITICAL: guard textView.string != text prevents infinite re-render loop (Pitfall #5).
// Source: RESEARCH.md Pattern 8 [VERIFIED]
// MD-02: opt-in markdownHighlight flag applies MarkdownEditorHighlight attribute pass
//        via textStorage beginEditing/endEditing — NEVER assigns textView.string.

import SwiftUI
import AppKit

// MARK: - MarkdownEditorHighlight (pure, nonisolated, unit-testable — MD-02)

/// A lightweight scan-based Markdown syntax highlighter for the raw editor.
/// Returns an array of (range, color) spans over the given string.
/// The function is pure and nonisolated: no NSTextView or SwiftUI required.
/// Never crashes on empty, huge, or malformed input — returns whatever complete
/// spans it found before hitting an error or size limit.
enum MarkdownEditorHighlight {

    struct Span {
        let range: NSRange
        let color: NSColor
    }

    // MARK: - Size guard (mirrors INFRA-17 pattern)
    // Avoid quadratic scan time on truly enormous inputs by capping at 2 MB.
    private static let maxScanBytes = 2_000_000

    /// Scan `text` and return attribute spans for Markdown syntax constructs.
    /// Covers: ATX headings (# to ######), bold (**…** / __…__),
    ///         italic (*…* / _…_), inline code (`…`), link syntax ([text](url)).
    /// Uses NSColor system colors so spans adapt to Light/Dark/accent appearance.
    static func spans(in text: String) -> [Span] {
        guard !text.isEmpty else { return [] }
        // Size guard: scan up to maxScanBytes characters
        let scanText: String
        if text.utf8.count > maxScanBytes {
            // Truncate safely at a UTF-8 boundary
            let endIdx = text.utf8.index(text.utf8.startIndex, offsetBy: maxScanBytes, limitedBy: text.utf8.endIndex) ?? text.utf8.endIndex
            scanText = String(text.utf8[text.utf8.startIndex..<endIdx]) ?? text
        } else {
            scanText = text
        }

        var result: [Span] = []
        result.reserveCapacity(64)

        let nsText = scanText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        // --- 1. ATX Headings: ^#{1,6} (at start of line) ---
        if let headingRegex = try? NSRegularExpression(
            pattern: #"^#{1,6}(?= |\t|$)"#,
            options: .anchorsMatchLines
        ) {
            headingRegex.enumerateMatches(in: scanText, options: [], range: fullRange) { match, _, _ in
                guard let r = match?.range, r.length > 0 else { return }
                result.append(Span(range: r, color: .systemOrange))
            }
        }

        // --- 2. Bold: **…** or __…__ ---
        if let boldRegex = try? NSRegularExpression(
            pattern: #"(\*\*(?!\s)(?:[^*]|\*(?!\*))+(?<!\s)\*\*|__(?!\s)(?:[^_]|_(?!_))+(?<!\s)__)"#,
            options: []
        ) {
            boldRegex.enumerateMatches(in: scanText, options: [], range: fullRange) { match, _, _ in
                guard let r = match?.range, r.length > 0 else { return }
                result.append(Span(range: r, color: .systemBlue))
            }
        }

        // --- 3. Italic: *…* or _…_ (single, not double) ---
        // Use negative lookahead/lookbehind to avoid matching bold markers.
        if let italicRegex = try? NSRegularExpression(
            pattern: #"(?<!\*)\*(?!\*)(?!\s)(?:[^*]+)(?<!\s)\*(?!\*)|(?<!_)_(?!_)(?!\s)(?:[^_]+)(?<!\s)_(?!_)"#,
            options: []
        ) {
            italicRegex.enumerateMatches(in: scanText, options: [], range: fullRange) { match, _, _ in
                guard let r = match?.range, r.length > 0 else { return }
                result.append(Span(range: r, color: .systemPurple))
            }
        }

        // --- 4. Inline code: `…` (single backtick, no newline inside) ---
        if let codeRegex = try? NSRegularExpression(
            pattern: #"`[^`\n]+`"#,
            options: []
        ) {
            codeRegex.enumerateMatches(in: scanText, options: [], range: fullRange) { match, _, _ in
                guard let r = match?.range, r.length > 0 else { return }
                result.append(Span(range: r, color: .systemTeal))
            }
        }

        // --- 5. Link syntax: [text](url) — color entire [text] and (url) ---
        if let linkRegex = try? NSRegularExpression(
            pattern: #"\[[^\[\]\n]+\]\([^()\n]*\)"#,
            options: []
        ) {
            linkRegex.enumerateMatches(in: scanText, options: [], range: fullRange) { match, _, _ in
                guard let r = match?.range, r.length > 0 else { return }
                result.append(Span(range: r, color: .secondaryLabelColor))
            }
        }

        return result
    }
}

// MARK: - SyntaxEditorView

struct SyntaxEditorView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var isEditable: Bool = true
    var accessibilityLabel: String = "Code editor"
    /// When true, applies MarkdownEditorHighlight attribute pass after each text update.
    /// Default false — Regex/Diff editors remain plain. (MD-02)
    var markdownHighlight: Bool = false

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isRichText = false
        textView.font = font
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        // Accessibility (INFRA-15)
        textView.setAccessibilityLabel(accessibilityLabel)
        textView.setAccessibilityRole(.textArea)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // CRITICAL: guard prevents infinite re-render loop (Pitfall #5).
        // The highlight attribute pass runs AFTER this guard — it only changes
        // attributes, never assigns textView.string, so it cannot trip the guard.
        guard textView.string != text else { return }
        let selectedRanges = textView.selectedRanges
        textView.string = text
        // Restore cursor position after programmatic text update
        if selectedRanges.allSatisfy({ $0.rangeValue.location <= textView.string.count }) {
            textView.selectedRanges = selectedRanges
        }
        // Apply Markdown syntax highlighting AFTER string assignment, attribute-only.
        // CRITICAL: uses beginEditing/endEditing; does NOT touch textView.string.
        if markdownHighlight {
            applyMarkdownHighlight(to: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, markdownHighlight: markdownHighlight)
    }

    // MARK: - Markdown highlight attribute pass (MD-02)

    /// Apply MarkdownEditorHighlight spans to the textView's textStorage.
    /// CRITICAL: uses beginEditing/endEditing, never assigns textView.string.
    /// Preserves cursor/selection (caller restores selectedRanges around string set).
    private func applyMarkdownHighlight(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let str = textView.string
        guard !str.isEmpty else { return }
        let fullRange = NSRange(location: 0, length: (str as NSString).length)

        storage.beginEditing()
        // Reset entire range to default foreground color + monospaced font.
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        storage.addAttribute(.font, value: font, range: fullRange)
        // Apply colored spans over the reset baseline.
        let spans = MarkdownEditorHighlight.spans(in: str)
        for span in spans {
            // Guard against out-of-bounds ranges (defensive)
            let end = span.range.location + span.range.length
            guard span.range.location >= 0, end <= fullRange.length else { continue }
            storage.addAttribute(.foregroundColor, value: span.color, range: span.range)
        }
        storage.endEditing()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        let markdownHighlight: Bool

        init(text: Binding<String>, markdownHighlight: Bool) {
            self.text = text
            self.markdownHighlight = markdownHighlight
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Async dispatch breaks the synchronous update cycle that causes infinite loops.
            // After the binding update causes updateNSView to be called, the Pitfall #5
            // guard will fire (textView.string == text) and skip the string assignment,
            // so the highlight pass will NOT run again — no loop.
            let currentString = textView.string
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.text.wrappedValue = currentString
            }
            // Apply highlight immediately after user edit.
            // Runs on main (@MainActor Coordinator), textView already has the new string.
            if markdownHighlight {
                applyHighlightDirect(to: textView)
            }
        }

        /// Direct highlight application from textDidChange (always on main — @MainActor).
        private func applyHighlightDirect(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let str = textView.string
            guard !str.isEmpty else { return }
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let fullRange = NSRange(location: 0, length: (str as NSString).length)
            let selectedRanges = textView.selectedRanges

            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            storage.addAttribute(.font, value: font, range: fullRange)
            let spans = MarkdownEditorHighlight.spans(in: str)
            for span in spans {
                let end = span.range.location + span.range.length
                guard span.range.location >= 0, end <= fullRange.length else { continue }
                storage.addAttribute(.foregroundColor, value: span.color, range: span.range)
            }
            storage.endEditing()

            // Restore selection — attribute-only changes can shift cursor in some AppKit builds
            if selectedRanges.allSatisfy({ $0.rangeValue.location <= (str as NSString).length }) {
                textView.selectedRanges = selectedRanges
            }
        }

        // Esc handling lives in MenuBarPopoverView via a local NSEvent keyDown monitor
        // (catches Esc from any first responder — text view, history List, or none).
    }
}
