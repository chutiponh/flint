// Tools/JSONFormatter/JSONFormatterDefinition.swift
// ToolDefinition for the JSON Formatter — includes real detection predicate.
// Source: RESEARCH.md § "Detection Predicate Chain" — JSON is priority 1.

import SwiftUI

enum JSONFormatterDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "json-formatter",
            name: "JSON Formatter",
            category: .formatting,
            keywords: ["json", "format", "pretty", "minify", "validate", "sort", "javascript", "object"],
            sfSymbol: "curlybraces",
            detectionPredicate: { input in
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                // Fast pre-check: must start with { or [ (saves expensive parse cost)
                guard trimmed.first == "{" || trimmed.first == "[" else { return nil }
                // Full validation
                guard let data = trimmed.data(using: .utf8),
                      (try? JSONSerialization.jsonObject(with: data, options: [])) != nil else {
                    return nil
                }
                return DetectionResult(
                    toolId: "json-formatter",
                    toolName: "JSON Formatter",
                    sample: String(trimmed.prefix(40))
                )
            },
            makeView: {
                AnyView(JSONFormatterView())
            }
        )
    }
}
