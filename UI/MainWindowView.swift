// UI/MainWindowView.swift
// Detachable workspace window (INFRA-02) — NavigationSplitView shell.
// Full preferences/appearance polish added in plan 01-07.

import SwiftUI

struct MainWindowView: View {
    @Environment(ToolRegistry.self) private var toolRegistry
    @Environment(HistoryStore.self) private var historyStore
    @State private var selectedToolId: String? = nil

    var body: some View {
        NavigationSplitView {
            // Sidebar: tool list
            List(toolRegistry.tools, selection: $selectedToolId) { tool in
                Label(tool.name, systemImage: tool.sfSymbol)
                    .tag(tool.id)
            }
            .navigationTitle("Lathe")
            .listStyle(.sidebar)
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
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // Default selection: JSON Formatter
            if selectedToolId == nil {
                selectedToolId = "json-formatter"
            }
        }
        .onDisappear {
            WindowCoordinator.shared.windowWillClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWorkspace)) { _ in
            // Focus window when notification fires
        }
    }
}
