// Tools/NumberBase/NumberBaseDefinition.swift
// Number Base Converter tool definition — no detection predicate (search-only).
// Category: .conversion — number literals too common for clipboard auto-detect (D-13).
// ToolRegistry NOT edited here — registration is the Wave-7 plan.
// Analog: Tools/Hash/HashDefinition.swift (no predicate + wrapper pattern).

import SwiftUI

enum NumberBaseDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "number-base",
            name: "Number Base Converter",
            category: .conversion,
            keywords: [
                "number", "base", "binary", "octal", "decimal", "hex", "hexadecimal",
                "bit", "radix", "two's complement", "signed", "unsigned", "bitwise"
            ],
            sfSymbol: "number",
            detectionPredicate: nil,   // search-only — number literals are too common (D-13)
            makeView: { @MainActor in
                AnyView(NumberBaseViewWrapper())
            }
        )
    }
}

// MARK: - Wrapper for environment-injected history store

private struct NumberBaseViewWrapper: View {
    @Environment(HistoryStore.self) private var historyStore

    var body: some View {
        NumberBaseView { entry in
            historyStore.save(entry)
        }
    }
}
