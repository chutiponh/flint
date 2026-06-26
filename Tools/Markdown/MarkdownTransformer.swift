// Tools/Markdown/MarkdownTransformer.swift
// STUB — RED phase placeholder. Will be replaced with full implementation in GREEN phase.
import Foundation

enum MarkdownTransformer {
    struct TransformError: Error {
        let message: String
        var displayMessage: String { message }
    }
    static func renderHTML(_ source: String) -> Result<String, TransformError> {
        .failure(TransformError(message: "Not implemented"))
    }
    static func fullStyledHTML(_ source: String) -> Result<String, TransformError> {
        .failure(TransformError(message: "Not implemented"))
    }
    static func wordCount(_ s: String) -> Int { 0 }
    static func readingTimeMinutes(words: Int) -> Int { 0 }
}
