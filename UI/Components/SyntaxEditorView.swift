// UI/Components/SyntaxEditorView.swift
// NSViewRepresentable wrapping NSTextView for editable code input.
// CRITICAL: guard textView.string != text prevents infinite re-render loop (Pitfall #5).
// Source: RESEARCH.md Pattern 8 [VERIFIED]

import SwiftUI
import AppKit

struct SyntaxEditorView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var isEditable: Bool = true
    var accessibilityLabel: String = "Code editor"

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
        // CRITICAL: guard prevents infinite re-render loop (Pitfall #5)
        guard textView.string != text else { return }
        let selectedRanges = textView.selectedRanges
        textView.string = text
        // Restore cursor position after programmatic text update
        if selectedRanges.allSatisfy({ $0.rangeValue.location <= textView.string.count }) {
            textView.selectedRanges = selectedRanges
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Async dispatch breaks the synchronous update cycle that causes infinite loops
            DispatchQueue.main.async { [weak self] in
                self?.text.wrappedValue = textView.string
            }
        }
    }
}
