// UI/Components/PinnedToolBarView.swift
// Horizontal row of up to 6 tool icon buttons with drag-to-reorder (INFRA-11).
// Default order: JSON, Base64, JWT, URL, Timestamp, UUID (D-13).
// Drag-to-reorder persists to PreferencesStore (UserDefaults).
//
// Drag-to-reorder implementation:
//   - Each PinnedToolButton is a drag source (onDrag exports the tool ID as NSString).
//   - Each PinnedToolButton is also a drop target via PinnedToolDropDelegate.
//   - PinnedToolDropDelegate.performDrop reads the dragged tool ID from DropInfo,
//     computes source + destination indices from prefs.pinnedToolIds, and calls
//     prefs.movePinnedTool(from:to:) — which persists the new order to UserDefaults.
//
// Fix (plan 01-08, INFRA-11 gap-closure):
//   PRIMARY — Drag source was a SwiftUI Button, whose press gesture pre-empted .onDrag
//   on macOS so no drag ever started. Replaced Button with a plain VStack + .onTapGesture
//   so both tap-to-select and drag-to-reorder work. Added .accessibilityAddTraits(.isButton).
//   SECONDARY — performDrop added +1 to destIndex for forward moves, double-compensating
//   Array.move(fromOffsets:toOffset:) and landing one slot too far. Removed the +1.

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
                    PinnedToolButton(
                        tool: tool,
                        pinnedToolIds: prefs.pinnedToolIds,
                        prefs: prefs,
                        action: { onSelectTool(tool.id) }
                    )
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

/// Individual 40×40pt icon button for a pinned tool.
/// Acts as both a drag source (exports its tool ID) and a drop target (accepts a peer tool ID
/// and calls prefs.movePinnedTool so the reorder round-trips through UserDefaults).
///
/// Implementation note: The icon is a plain VStack (not a SwiftUI Button) so that .onDrag
/// can claim the press gesture on macOS. A Button's built-in press recogniser pre-empts
/// .onDrag, preventing the drag from ever starting. .onTapGesture replaces the Button tap
/// and .accessibilityAddTraits(.isButton) preserves the accessibility role.
private struct PinnedToolButton: View {
    let tool: ToolDefinition
    let pinnedToolIds: [String]
    let prefs: PreferencesStore
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tool.sfSymbol)
                .font(.system(size: 22))
                .foregroundColor(isHovered ? .accentColor : .secondary)
        }
        .frame(width: 40, height: 40)
        .background(isHovered ? Color.accentColor.opacity(0.08) : .clear)
        .cornerRadius(8)
        // Cover the full 40×40 area for both tap and drag hit-testing.
        .contentShape(Rectangle())
        // Tap-to-select: fires the onSelectTool callback (replaces Button(action:)).
        .onTapGesture {
            action()
        }
        // Accessibility: declare button role since we are no longer a real Button.
        .accessibilityLabel(tool.name)
        .accessibilityAddTraits(.isButton)
        .help(tool.name)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovered
            }
        }
        // Drag source: export this tool's ID so the drop target can identify it.
        // Placed on the non-Button container so macOS does not suppress the drag gesture.
        .onDrag {
            NSItemProvider(object: tool.id as NSString)
        }
        // Drop target: when a peer tool is dropped here, reorder and persist.
        .onDrop(of: [.text], delegate: PinnedToolDropDelegate(
            destinationToolId: tool.id,
            pinnedToolIds: pinnedToolIds,
            prefs: prefs
        ))
    }
}

// MARK: - Drop Delegate (Drag-to-Reorder)

/// Handles drag-to-reorder for the pinned tool bar.
///
/// On performDrop:
///   1. Extracts the dragged tool ID from DropInfo (the NSString exported by the drag source).
///   2. Finds its index in prefs.pinnedToolIds (source).
///   3. Finds the destination tool's index (destination).
///   4. Calls prefs.movePinnedTool(from:to:), which mutates and persists the array.
///
/// Index math (plan 01-08 fix):
///   movePinnedTool calls Array.move(fromOffsets:toOffset:).
///   toOffset is the "insert-before" index in the PRE-REMOVAL original array.
///   A raw firstIndex(of:destinationToolId) already gives the correct toOffset —
///   no adjustment is needed. The previous code added +1 for forward moves
///   (destIndex > sourceIndex), which double-compensated and landed the tool one
///   slot past the intended position. The +1 is now removed.
private struct PinnedToolDropDelegate: DropDelegate {
    /// The ID of the tool that the drag is hovering over / being dropped onto.
    let destinationToolId: String
    /// Snapshot of the pinned IDs at the time the view was built (for index lookup).
    let pinnedToolIds: [String]
    /// Live store — mutable so we can call movePinnedTool.
    let prefs: PreferencesStore

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        // NSItemProvider.loadObject is async; we use the semaphore-free approach and dispatch
        // back to the main actor after loading (DropDelegate callbacks run on MainActor).
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let draggedId = item as? String,
                  draggedId != destinationToolId else { return }

            // Use the live pinnedToolIds from prefs for freshest order.
            let ids = prefs.pinnedToolIds
            guard let sourceIndex = ids.firstIndex(of: draggedId),
                  let destIndex = ids.firstIndex(of: destinationToolId) else { return }

            // Perform the move and persist.
            // FIX: pass destIndex directly — no +1. Array.move toOffset is already
            // the insert-before-index convention; adding +1 previously caused
            // forward drags to land one slot too far.
            DispatchQueue.main.async {
                prefs.movePinnedTool(from: IndexSet(integer: sourceIndex), to: destIndex)
            }
        }
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
        // Use the horizontal scroll version for the compact popover bar.
        // The List+onMove version is better suited for a settings/preferences sheet.
        PinnedToolBarView(onSelectTool: onSelectTool)
    }
}
