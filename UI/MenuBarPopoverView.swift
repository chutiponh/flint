// UI/MenuBarPopoverView.swift
// The main 480×600 popover — search-first launcher (D-01).
// Search bar autofocused, detection banner (D-04), 6 pinned tools (D-13), recent history.
// Source: RESEARCH.md Pattern 1 + UI-SPEC.md § "Popover Layout"

import SwiftUI

/// Navigation state for the popover.
enum PopoverNavigationState: Equatable {
    case root                        // launcher: search + pinned + recent history
    case tool(toolId: String)        // inside a tool view
    case searchResults(query: String) // showing search results
}

struct MenuBarPopoverView: View {
    @Environment(HistoryStore.self) private var historyStore
    @Environment(ToolRegistry.self) private var toolRegistry
    @Environment(ClipboardDetector.self) private var clipboard
    @Environment(PreferencesStore.self) private var prefs

    @State private var searchText: String = ""
    @State private var navigationState: PopoverNavigationState = .root
    @State private var dismissedDetection: Bool = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Zone 1: Search bar (D-01) — always visible at top
            searchBar

            // Zone 2: Detection banner (D-04) — slides in when there's a detection
            if let result = clipboard.detectionResult, !dismissedDetection, searchText.isEmpty {
                DetectionBannerView(
                    result: result,
                    onAccept: {
                        dismissedDetection = true
                        navigationState = .tool(toolId: result.toolId)
                    },
                    onDismiss: {
                        dismissedDetection = true
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeOut(duration: 0.15), value: clipboard.detectionResult != nil)
            }

            Divider()

            // Zone 3: Pinned tools row (D-13) — visible at root
            if navigationState == .root && searchText.isEmpty {
                pinnedToolsRow
                Divider()
            }

            // Zone 4: Body — recent history, search results, or active tool
            bodyContent
        }
        .frame(width: 480, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: clipboard.detectionResult) { _, _ in
            // D-05: re-show banner on any new detection (reset dismissal)
            dismissedDetection = false
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                if case .searchResults = navigationState {
                    navigationState = .root
                }
            } else {
                navigationState = .searchResults(query: newValue)
            }
        }
        .onKeyPress(.escape) {
            handleEscape()
            return .handled
        }
        .onAppear {
            searchFocused = true
            // Start clipboard detection with the registry (called here so toolRegistry is ready)
            clipboard.start(registry: toolRegistry)
        }
        // Handle hotkey notification (show popover)
        .onReceive(NotificationCenter.default.publisher(for: .showPopover)) { _ in
            clipboard.isPopoverPresented = true
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            TextField("Search tools or history…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .accessibilityLabel("Search tools or history")
                .onSubmit {
                    // Enter selects first search result
                    if case .searchResults(let q) = navigationState {
                        let results = toolRegistry.search(q)
                        if let first = results.first {
                            navigationState = .tool(toolId: first.id)
                            searchText = ""
                        }
                    }
                }

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Pinned Tools Row

    private var pinnedToolsRow: some View {
        let pinnedTools = prefs.pinnedToolIds.compactMap { id in
            toolRegistry.tools.first { $0.id == id }
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(pinnedTools) { tool in
                    Button(action: {
                        navigationState = .tool(toolId: tool.id)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tool.sfSymbol)
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                                .frame(width: 40, height: 40)
                        }
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tool.name)
                    .help(tool.name)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Body Content

    @ViewBuilder
    private var bodyContent: some View {
        switch navigationState {
        case .root:
            // Recent history (last 5 entries)
            recentHistoryView

        case .searchResults(let query):
            searchResultsView(query: query)

        case .tool(let toolId):
            if let tool = toolRegistry.tools.first(where: { $0.id == toolId }) {
                tool.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Tool Not Found", systemImage: "questionmark")
            }
        }
    }

    // MARK: - Recent History

    private var recentHistoryView: some View {
        let recent = Array(historyStore.entries.prefix(5))
        return Group {
            if recent.isEmpty {
                // Empty state (D-01)
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Welcome to Lathe")
                        .font(.headline)
                    Text("Paste content or press ⌘⇧Space from any app to get started.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(recent, id: \.id) { entry in
                    HistoryRowView(
                        entry: entry,
                        onOpen: {
                            navigationState = .tool(toolId: entry.tool)
                        },
                        onPin: { historyStore.togglePin(entry: entry) },
                        onDelete: { historyStore.delete(entry: entry) }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
                .listStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Search Results

    private func searchResultsView(query: String) -> some View {
        let toolResults = toolRegistry.search(query)
        let historyResults = historyStore.entries.filter {
            $0.tool.localizedCaseInsensitiveContains(query) ||
            $0.input.localizedCaseInsensitiveContains(query) ||
            $0.output.localizedCaseInsensitiveContains(query)
        }

        return Group {
            if toolResults.isEmpty && historyResults.isEmpty {
                ContentUnavailableView(
                    "No results for \"\(query)\"",
                    systemImage: "magnifyingglass",
                    description: Text("No tools or history match your search.")
                )
            } else {
                List {
                    if !toolResults.isEmpty {
                        Section("Tools") {
                            ForEach(toolResults) { tool in
                                Button(action: {
                                    navigationState = .tool(toolId: tool.id)
                                    searchText = ""
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: tool.sfSymbol)
                                            .foregroundColor(.accentColor)
                                            .frame(width: 24)
                                        VStack(alignment: .leading) {
                                            Text(tool.name)
                                                .font(.system(size: 13, weight: .semibold))
                                            Text(tool.category.displayName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tool.name)
                            }
                        }
                    }

                    if !historyResults.isEmpty {
                        Section("History") {
                            ForEach(historyResults.prefix(10), id: \.id) { entry in
                                HistoryRowView(
                                    entry: entry,
                                    onOpen: {
                                        navigationState = .tool(toolId: entry.tool)
                                        searchText = ""
                                    },
                                    onPin: { historyStore.togglePin(entry: entry) },
                                    onDelete: { historyStore.delete(entry: entry) }
                                )
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Esc Handler (Two-Stage, D-03)

    private func handleEscape() {
        if case .root = navigationState, searchText.isEmpty {
            // Stage 2: close popover
            clipboard.isPopoverPresented = false
        } else {
            // Stage 1: return to launcher
            navigationState = .root
            searchText = ""
        }
    }
}

// MARK: - History Row View

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
            .accessibilityLabel("\(entry.tool), \(String(entry.input.prefix(40))), \(entry.pinned ? "pinned" : "not pinned")")

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
