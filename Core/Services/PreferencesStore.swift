// Core/Services/PreferencesStore.swift
// @Observable UserDefaults wrapper for app preferences.
// SECURITY: Never store secrets here (UserDefaults may be iCloud-backed).
// Launch-at-login via SMAppService added in plan 01-07.

import Foundation
import Observation

@Observable
final class PreferencesStore {
    // Pinned tool IDs — D-13 default order: JSON, Base64, JWT, URL, Timestamp, UUID
    // INFRA-11: ordered, persisted in UserDefaults, max 6 tools.
    var pinnedToolIds: [String] {
        get { defaults.stringArray(forKey: Keys.pinnedToolIds) ?? Self.defaultPinnedToolIds }
        set { defaults.set(newValue, forKey: Keys.pinnedToolIds) }
    }

    /// Alias with canonical casing (matching PLAN.md interface spec).
    var pinnedToolIDs: [String] {
        get { pinnedToolIds }
        set { pinnedToolIds = newValue }
    }

    /// Move a pinned tool from one position to another and persist. (INFRA-11 drag-to-reorder)
    func movePinnedTool(from source: IndexSet, to destination: Int) {
        var ids = pinnedToolIds
        ids.move(fromOffsets: source, toOffset: destination)
        pinnedToolIds = ids
    }

    /// Add a tool to pinned list (max 6). No-op if already pinned or at cap.
    func pinTool(_ id: String) {
        guard !pinnedToolIds.contains(id), pinnedToolIds.count < 6 else { return }
        pinnedToolIds.append(id)
    }

    /// Remove a tool from pinned list.
    func unpinTool(_ id: String) {
        pinnedToolIds.removeAll { $0 == id }
    }

    // Global hotkey (stored as KeyboardShortcuts name — HotkeyManager owns registration)
    // Stored separately by KeyboardShortcuts library in UserDefaults

    // Whether clipboard auto-detection is enabled
    var clipboardDetectionEnabled: Bool {
        get { defaults.object(forKey: Keys.clipboardDetectionEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.clipboardDetectionEnabled) }
    }

    // History item limit (default 100, max 100)
    var historyLimit: Int {
        get { defaults.object(forKey: Keys.historyLimit) as? Int ?? 100 }
        set { defaults.set(min(newValue, 100), forKey: Keys.historyLimit) }
    }

    // Appearance — follows system by default (managed by SwiftUI environment)
    // Preferences view for theme selection added in 01-07.

    private let defaults = UserDefaults.standard

    // D-13: default pinned order
    static let defaultPinnedToolIds = [
        "json-formatter",
        "base64",
        "jwt-decoder",
        "url-encoder",
        "timestamp",
        "uuid-generator"
    ]

    private enum Keys {
        static let pinnedToolIds = "lathe.pinnedToolIds"
        static let clipboardDetectionEnabled = "lathe.clipboardDetectionEnabled"
        static let historyLimit = "lathe.historyLimit"
    }
}
