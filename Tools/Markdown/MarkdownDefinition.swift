// Tools/Markdown/MarkdownDefinition.swift
// STUB — placeholder so project compiles during TDD RED phase.
import SwiftUI

enum MarkdownDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "markdown",
            name: "Markdown Previewer",
            category: .formatting,
            keywords: ["markdown", "md", "gfm", "preview", "html"],
            sfSymbol: "doc.richtext",
            detectionPredicate: nil,
            makeView: { @MainActor in AnyView(Text("stub")) }
        )
    }
}
