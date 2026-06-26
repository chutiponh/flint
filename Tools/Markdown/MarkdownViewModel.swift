// Tools/Markdown/MarkdownViewModel.swift
// STUB — placeholder so project compiles during TDD RED phase.
import Foundation
import Observation

@Observable
@MainActor
final class MarkdownViewModel: ToolShortcutActions {
    var source: String = ""
    var html: String = ""
    var outputDimmed: Bool = false
    var errorMessage: String? = nil
    var wordCountText: String = "words: 0"
    var readingTimeText: String = "~1 min read"

    private let onSaveHistory: (HistoryEntry) -> Void

    init(onSaveHistory: @escaping (HistoryEntry) -> Void) {
        self.onSaveHistory = onSaveHistory
    }

    func primaryOutput() -> String? { html.isEmpty ? nil : html }
    func clearInput() { source = "" }
}
