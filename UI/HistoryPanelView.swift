// UI/HistoryPanelView.swift
// First-class history view with search/filter, pin, delete, and clear semantics.
// D-07: Full history list (last 100 + pinned) reachable via search "history".
// D-08: Clicking a row restores input into matched tool and re-runs transform live.
// D-09: Pinned items sort to top, survive "Clear"; "Clear" removes unpinned only.
// INFRA-08: Search/filter over tool + input fields.

import SwiftUI

struct HistoryPanelView: View {
    @Environment(HistoryStore.self) private var historyStore
    @Environment(ToolRegistry.self) private var toolRegistry

    /// Called when the user wants to restore a history entry into a tool (D-08).
    /// Passes the tool ID so the navigation state opens the correct tool.
    let onRestoreEntry: (HistoryEntry) -> Void

    @State private var filterText: String = ""
    @State private var showClearConfirmation: Bool = false

    private var filteredEntries: [HistoryEntry] {
        if filterText.isEmpty {
            return historyStore.entries
        }
        return historyStore.search(filterText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter search bar for this panel
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                TextField("Filter history…", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .accessibilityLabel("Filter history")
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear filter")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                historyListView
            }

            Divider()
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            if filterText.isEmpty {
                Text("No history yet")
                    .font(.headline)
                Text("Your transformations will appear here after you use any tool.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("No history matching \"\(filterText)\"")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyListView: some View {
        List(filteredEntries, id: \.id) { entry in
            HistoryRowView(
                entry: entry,
                onOpen: {
                    // D-08: restore input into matched tool; output always recomputed (not trusted from disk)
                    onRestoreEntry(entry)
                },
                onPin: {
                    historyStore.togglePin(entry: entry)
                },
                onDelete: {
                    // Individual delete — no confirmation required (D-09)
                    historyStore.delete(entry: entry)
                }
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        }
        .listStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Bar (Clear)

    private var bottomBar: some View {
        HStack {
            let unpinnedCount = historyStore.unpinnedCount
            Button(role: .destructive) {
                if unpinnedCount > 0 {
                    showClearConfirmation = true
                }
            } label: {
                Text(unpinnedCount > 0 ? "Clear \(unpinnedCount) items…" : "Clear")
                    .font(.system(size: 12))
                    .foregroundColor(unpinnedCount > 0 ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(unpinnedCount == 0)
            .accessibilityLabel(unpinnedCount > 0 ? "Clear \(unpinnedCount) unpinned history items" : "No items to clear")
            .confirmationDialog(
                "Clear \(unpinnedCount) items? Pinned items will be kept.",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    historyStore.clearUnpinned()
                }
                Button("Cancel", role: .cancel) { }
            }

            Spacer()

            Text("\(historyStore.entries.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
