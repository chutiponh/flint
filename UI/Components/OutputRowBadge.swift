// UI/Components/OutputRowBadge.swift
// Numbered badge displayed on each copyable output row for ⌘N keyboard copy (D-08).
// Stateless display-only component — ⌘1–⌘9 actions are wired at the MenuBarPopoverView level.
// Source: UI-SPEC.md § "⌘1–⌘9 Row Copy — D-08" + PATTERNS.md § "OutputRowBadge"

import SwiftUI

struct OutputRowBadge: View {
    let index: Int

    var body: some View {
        Text("\(index)")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary.opacity(0.6))
            )
            .accessibilityLabel("⌘\(index) to copy")
            .help("Press ⌘\(index) to copy")
    }
}

#Preview {
    HStack(spacing: 8) {
        ForEach(1...6, id: \.self) { i in
            OutputRowBadge(index: i)
        }
    }
    .padding()
}
