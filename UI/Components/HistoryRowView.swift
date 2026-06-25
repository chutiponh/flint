// UI/Components/HistoryRowView.swift
// Compact history list row — Tool SF Symbol | name | input preview ≤40 chars | relative time | pin | delete.
// Source: UI-SPEC.md § "History Panel", § "Component Inventory" (HistoryRowView)

import SwiftUI

struct HistoryRowView: View {
    let entry: HistoryEntry
    let onOpen: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.tool.replacingOccurrences(of: "-", with: " ").capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(String(entry.input.prefix(40)))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(entry.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            // VoiceOver: "JSON Formatter, {input preview}, pinned, 2 minutes ago"
            .accessibilityLabel("\(entry.tool.replacingOccurrences(of: "-", with: " ").capitalized), \(String(entry.input.prefix(40))), \(entry.pinned ? "pinned" : "not pinned")")

            Button(action: onPin) {
                Image(systemName: entry.pinned ? "pin.fill" : "pin")
                    .foregroundColor(entry.pinned ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.pinned ? "Unpin" : "Pin")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
        }
        .padding(.vertical, 4)
    }
}
