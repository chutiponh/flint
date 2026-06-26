// UI/MainWindowView.swift
// Detachable workspace window (INFRA-02) — NavigationSplitView with all seven tools.
// Min 800×600; remembers last-open tool per tool (last mode persisted in PreferencesStore).
// Opens via NotificationCenter + WindowCoordinator activation-policy dance (Pattern 1/7).
// Source: RESEARCH.md Pattern 1, Pattern 7, § "Phase Requirements" INFRA-02

import SwiftUI

struct MainWindowView: View {
    @Environment(ToolRegistry.self) private var toolRegistry
    @Environment(HistoryStore.self) private var historyStore
    @Environment(PreferencesStore.self) private var prefs
    @Environment(ClipboardDetector.self) private var clipboard

    // Persisted last-selected tool ID — restored on reopen (INFRA-02)
    @State private var selectedToolId: String? = nil

    var body: some View {
        NavigationSplitView {
            // Sidebar: list of all registered tools
            List(toolRegistry.tools, selection: $selectedToolId) { tool in
                Label(tool.name, systemImage: tool.sfSymbol)
                    .tag(tool.id)
                    .accessibilityLabel(tool.name)
                    .help(tool.name)
            }
            .navigationTitle("Flint")
            .listStyle(.sidebar)
            .accessibilityLabel("Tool list")
        } detail: {
            if let toolId = selectedToolId,
               let tool = toolRegistry.tools.first(where: { $0.id == toolId }) {
                tool.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Select a Tool",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Choose a tool from the sidebar to get started.")
                )
                .accessibilityLabel("No tool selected. Choose a tool from the sidebar.")
            }
        }
        // INFRA-02: cannot shrink below 800×600
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // Restore last-open tool from PreferencesStore (INFRA-02)
            let lastTool = prefs.lastWorkspaceToolId
            if let id = lastTool, toolRegistry.tools.contains(where: { $0.id == id }) {
                selectedToolId = id
            } else if selectedToolId == nil {
                // Default: JSON Formatter
                selectedToolId = "json-formatter"
            }
        }
        .onChange(of: selectedToolId) { _, newId in
            // Persist last-open tool for next reopen (INFRA-02)
            if let id = newId {
                prefs.lastWorkspaceToolId = id
            }
        }
        .onDisappear {
            // Restore .accessory policy when workspace closes (Pattern 7)
            WindowCoordinator.shared.windowWillClose()
        }
        // Handle .openWorkspace notification (Pattern 1 — NotificationCenter bridge)
        .onReceive(NotificationCenter.default.publisher(for: .openWorkspace)) { _ in
            // Window is already open when this fires (WindowCoordinator sends after activation)
            // No additional action needed — WindowCoordinator.openWorkspace() handles activation
        }
        // INFRA-16: ⌘, opens Preferences from workspace too
        .background(
            Button("Preferences") {
                WindowCoordinator.shared.openPreferences()
            }
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityHidden(true)
            .hidden()
        )
    }
}
