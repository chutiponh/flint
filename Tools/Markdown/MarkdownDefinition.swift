// Tools/Markdown/MarkdownDefinition.swift
// Markdown Previewer tool definition — category .formatting, no detection predicate (search-only).
// Follows HashDefinition pattern (no predicate + history-wrapper).
// ToolRegistry NOT edited here — registration is a Wave-7 task.

import SwiftUI

enum MarkdownDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "markdown",
            name: "Markdown Previewer",
            category: .formatting,
            keywords: ["markdown", "md", "gfm", "preview", "html", "render"],
            sfSymbol: "doc.richtext",
            detectionPredicate: nil,   // search-only — no clipboard auto-detection
            makeView: { @MainActor in
                AnyView(MarkdownViewWrapper())
            }
        )
    }
}

// MARK: - Wrapper for environment-injected history store

private struct MarkdownViewWrapper: View {
    @Environment(HistoryStore.self) private var historyStore

    var body: some View {
        MarkdownView { entry in
            historyStore.save(entry)
        }
    }
}
