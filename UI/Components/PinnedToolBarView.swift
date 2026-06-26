// UI/Components/PinnedToolBarView.swift
// Horizontal row of up to 6 tool icon buttons — tap to open (D-13).
// Default order: JSON, Base64, JWT, URL, Timestamp, UUID.
//
// Drag-to-reorder was removed (UAT): a 6-icon launcher bar doesn't need in-place
// reordering, and the gesture conflicted with tap-to-open on macOS. The pinned order
// still lives in PreferencesStore.pinnedToolIds and can be edited elsewhere if needed.

import SwiftUI

struct PinnedToolBarView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(ToolRegistry.self) private var toolRegistry

    let onSelectTool: (String) -> Void  // passes toolId

    /// Resolved tool definitions in pinned order, compactMapped against registry.
    private var pinnedTools: [ToolDefinition] {
        prefs.pinnedToolIds.compactMap { id in
            toolRegistry.tools.first { $0.id == id }
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(pinnedTools) { tool in
                    PinnedToolButton(tool: tool, action: { onSelectTool(tool.id) })
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 56)
        .accessibilityLabel("Pinned tools")
    }
}

// MARK: - Pinned Tool Button

/// Individual 40×40pt icon button for a pinned tool. Tap opens the tool.
private struct PinnedToolButton: View {
    let tool: ToolDefinition
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.sfSymbol)
                .font(.system(size: 22))
                .foregroundColor(isHovered ? .accentColor : .secondary)
                .frame(width: 40, height: 40)
                .background(isHovered ? Color.accentColor.opacity(0.08) : .clear)
                .cornerRadius(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.name)
        .help(tool.name)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovered
            }
        }
    }
}
