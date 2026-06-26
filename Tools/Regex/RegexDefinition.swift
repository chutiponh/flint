// Tools/Regex/RegexDefinition.swift
// ToolDefinition for the Regex Tester tool.
// Category: .analysis (RESEARCH §0 — ToolCategory is frozen, no new cases).
// NOT registered in ToolRegistry here — registration is the Wave-7 integration plan.
//
// DETECTION PREDICATE DECISION (CF-04, RESEARCH §0):
// Decision: nil (search-only) — NO slash-literal predicate.
// Rationale: A conservative /…/flags predicate would only fire on input literally formatted as
// regex literals (e.g. "/pattern/gi"). In practice, developers paste raw patterns (without slashes)
// into the tool. An aggressive predicate risks shadowing the existing JSON→JWT→Base64→URL→Timestamp→UUID
// detection chain (RESEARCH §0 warning: "aggressive regex predicate hijacks the whole chain").
// The nil approach means Regex Tester is reachable only via search — this is the safest v1 default.
// A future plan may add a conservative predicate once the detection chain behavior is fully characterized.

import SwiftUI

enum RegexDefinition {
    static func make() -> ToolDefinition {
        ToolDefinition(
            id: "regex",
            name: "Regex Tester",
            category: .analysis,
            keywords: ["regex", "regexp", "pattern", "match", "replace", "grep", "search", "capture"],
            sfSymbol: "text.magnifyingglass",
            // detectionPredicate: nil — see module-level comment above for the rationale.
            detectionPredicate: nil,
            makeView: { @MainActor in AnyView(RegexView()) }
        )
    }
}
