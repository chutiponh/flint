// UI/Components/CodeDisplayView.swift
// Read-only code display using HighlightSwift for syntax highlighting.
// Used for JSON output, not for the editable input (that's SyntaxEditorView).
// Source: RESEARCH.md § "Architecture Responsibility Map" (display-only = HighlightSwift)

import SwiftUI
import HighlightSwift

struct CodeDisplayView: View {
    let code: String
    let language: String

    var body: some View {
        ScrollView {
            if code.isEmpty {
                Text("Output will appear here")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            } else {
                HighlightedCodeBlock(
                    code: code,
                    language: language
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .accessibilityLabel("Formatted output")
        .accessibilityValue(code)
    }
}

/// Wrapper for HighlightSwift 1.1.0 that renders attributed string output.
private struct HighlightedCodeBlock: View {
    let code: String
    let language: String

    @State private var attributedCode: AttributedString = AttributedString()
    private let highlight = Highlight()

    var body: some View {
        Text(attributedCode.characters.isEmpty
             ? AttributedString(code)
             : attributedCode)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: code) {
                do {
                    // HighlightSwift 1.1.0 API: attributedText(_:language:)
                    let result = try await highlight.attributedText(code, language: language)
                    attributedCode = result
                } catch {
                    // Fallback to plain text if highlighting fails
                    attributedCode = AttributedString(code)
                }
            }
    }
}

#Preview {
    CodeDisplayView(code: #"{"name": "Alice", "age": 30}"#, language: "json")
        .frame(width: 400, height: 200)
}
