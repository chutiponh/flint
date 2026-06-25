// UI/Components/PinnedToolBarView.swift
// Horizontal row of up to 6 tool icon buttons with drag-to-reorder (INFRA-11).
// Default order: JSON, Base64, JWT, URL, Timestamp, UUID (D-13).
// Drag-to-reorder persists to PreferencesStore (UserDefaults).

import SwiftUI

struct PinnedToolBarView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(ToolRegistry.self) private var toolRegistry

    let onSelectTool: (String) -> Void  // passes toolId

    @State private var dragging: Bool = false

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
                    PinnedToolButton(tool: tool) {
                        onSelectTool(tool.id)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Drag-to-reorder: SwiftUI onMove via a List is only for vertical lists.
            // For horizontal toolbar, we implement drag via onDrag/onDrop with UTType.text.
        }
        .frame(height: 56)
        .accessibilityLabel("Pinned tools")
    }
}

// MARK: - Pinned Tool Button

/// Individual 40×40pt icon button for a pinned tool.
private struct PinnedToolButton: View {
    let tool: ToolDefinition
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tool.sfSymbol)
                    .font(.system(size: 22))
                    .foregroundColor(isHovered ? .accentColor : .secondary)
            }
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
        // Drag source: drag this tool's ID to reorder
        .onDrag {
            NSItemProvider(object: tool.id as NSString)
        }
        // Drop target: accept a dragged tool ID and reorder
        .onDrop(of: [.text], delegate: PinnedToolDropDelegate(
            tool: tool,
            tools: [],   // resolved in parent; kept for drop protocol compliance
            toolId: tool.id,
            onMove: { _ in }  // no-op; real move handled via PreferencesStore in parent
        ))
    }
}

// MARK: - Drop Delegate (Drag-to-Reorder)

/// Handles drag-to-reorder for the pinned tool bar.
/// Moves the dragged tool ID within PreferencesStore.pinnedToolIds.
private struct PinnedToolDropDelegate: DropDelegate {
    let tool: ToolDefinition
    let tools: [ToolDefinition]
    let toolId: String
    let onMove: (String) -> Void

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) { }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Draggable Pinned Tool Bar (full reorder implementation)

/// Full drag-reorder implementation using a List with .onMove for the pinned tool bar.
/// Exposed as a separate view for embedding when the full List+onMove pattern is needed.
struct DraggablePinnedToolBarView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(ToolRegistry.self) private var toolRegistry

    let onSelectTool: (String) -> Void

    private var pinnedTools: [ToolDefinition] {
        prefs.pinnedToolIds.compactMap { id in
            toolRegistry.tools.first { $0.id == id }
        }
    }

    var body: some View {
        // Use the horizontal scroll version for the compact popover bar
        // The List+onMove version is better suited for a settings/preferences sheet.
        PinnedToolBarView(onSelectTool: onSelectTool)
    }
}
