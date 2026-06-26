// Tools/Color/ColorDefinition.swift
// ToolDefinition for the Color Converter — includes narrow hex detection predicate.
// Category: .conversion (RESEARCH §0 — ToolCategory is frozen, no new cases).
// NOT registered in ToolRegistry here — registration is the Wave-7 integration plan.
//
// DETECTION PREDICATE DECISION (CF-04, UI-SPEC §"Detection predicate"):
// Decision: narrow hex pattern matching #RGB (3 digits), #RRGGBB (6 digits), #RRGGBBAA (8 digits).
// Rationale: Hex color strings are highly specific (#RRGGBB prefix with only hex digits). Safe to
// place early in the detection chain — will not false-positive over JSON/Base64/URL/JWT.
// Source: UI-SPEC.md "Tool 2: Color Converter" — Detection predicate note.

import SwiftUI

enum ColorDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "color",
            name: "Color Converter",
            category: .conversion,
            keywords: ["color", "colour", "hex", "rgb", "hsl", "hsv", "oklch", "contrast", "wcag", "picker", "swatch", "palette"],
            sfSymbol: "paintpalette",
            detectionPredicate: { input in
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
                // Fast pre-check: must start with #
                guard trimmed.hasPrefix("#") else { return nil }
                let hex = String(trimmed.dropFirst())
                let len = hex.count
                // Accept only #RGB (3), #RRGGBB (6), or #RRGGBBAA (8)
                guard len == 3 || len == 6 || len == 8 else { return nil }
                // All chars must be hex digits (0-9, A-F, a-f)
                guard hex.allSatisfy({ $0.isHexDigit }) else { return nil }
                return DetectionResult(
                    toolId: "color",
                    toolName: "Color Converter",
                    sample: String(trimmed.prefix(9))
                )
            },
            makeView: { @MainActor in AnyView(ColorView()) }
        )
    }
}
