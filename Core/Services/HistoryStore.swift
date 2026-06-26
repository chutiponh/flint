// Core/Services/HistoryStore.swift
// GRDB-backed SQLite history store for the last N transformations (N = PreferencesStore.historyLimit).
// Opened off the main thread to protect the <500ms cold-start budget (Pitfall #6).
// Source: RESEARCH.md Pattern 4 [VERIFIED]

import GRDB
import Foundation
import Observation

@Observable
@MainActor
final class HistoryStore {
    private(set) var dbQueue: DatabaseQueue?
    private(set) var entries: [HistoryEntry] = []
    private var observation: AnyDatabaseCancellable?

    /// WR-04: configurable cap sourced from PreferencesStore.historyLimit.
    /// HistoryStore does not retain a reference to PreferencesStore; callers update
    /// this value whenever the preference changes (or FlintApp can wire it via onChange).
    var historyLimit: Int = 100 {
        didSet {
            let clamped = max(10, min(100, historyLimit))
            if clamped != historyLimit { historyLimit = clamped }
        }
    }

    init() {
        // Kick off async database initialization — does NOT block main thread (Pitfall #6)
        Task { @MainActor in
            await self.initializeDatabase()
        }
    }

    private func initializeDatabase() async {
        do {
            // openDatabase() is nonisolated — Task.detached runs it off the main thread
            let queue = try await Task.detached(priority: .utility) {
                try HistoryStore.openDatabase()
            }.value
            dbQueue = queue
            startObservation(queue: queue)
        } catch {
            print("[HistoryStore] Failed to open database: \(error)")
        }
    }

    /// Opens the GRDB DatabaseQueue and runs migrations. Nonisolated for Task.detached.
    private nonisolated static func openDatabase() throws -> DatabaseQueue {
        let appSupport = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask,
                 appropriateFor: nil, create: true)
        let flintDir = appSupport.appendingPathComponent("Flint", isDirectory: true)
        try FileManager.default.createDirectory(at: flintDir,
                                                withIntermediateDirectories: true)
        let dbURL = flintDir.appendingPathComponent("history.db")
        let queue = try DatabaseQueue(path: dbURL.path)

        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "historyEntry", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("tool", .text).notNull()
                t.column("input", .text).notNull()
                t.column("output", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: false)
            }
            try db.create(index: "historyEntry_on_timestamp",
                          on: "historyEntry",
                          columns: ["timestamp"],
                          ifNotExists: true)
        }
        try migrator.migrate(queue)
        return queue
    }

    private func startObservation(queue: DatabaseQueue) {
        // ValueObservation is @MainActor-friendly in GRDB 7
        // D-09: pinned items exempt from the eviction cap
        observation = ValueObservation
            .tracking { db in
                try HistoryEntry
                    .order(Column("pinned").desc, Column("timestamp").desc)
                    .limit(200)   // fetch slightly over max historyLimit for in-memory pass
                    .fetchAll(db)
            }
            .start(in: queue,
                   scheduling: .async(onQueue: .main)) { error in
                print("[HistoryStore] Observation error: \(error)")
            } onChange: { [weak self] allEntries in
                guard let self else { return }
                // WR-04: honour the configured limit instead of hardcoding 100
                let limit = self.historyLimit
                // D-09: pinned items exempt from the cap
                let pinned = allEntries.filter { $0.pinned }
                let unpinned = Array(allEntries.filter { !$0.pinned }.prefix(limit))
                let sorted = (pinned + unpinned).sorted {
                    if $0.pinned != $1.pinned { return $0.pinned }
                    return $0.timestamp > $1.timestamp
                }
                Task { @MainActor [weak self] in
                    self?.entries = sorted
                }
            }
    }

    /// Save a history entry. Write is off-main, in GRDB's background queue.
    /// WR-03: after inserting, evict unpinned rows beyond the configured cap so
    ///        the SQLite database does not grow unbounded.
    /// WR-04: eviction limit is read from self.historyLimit (default 100, wired to PreferencesStore).
    func save(_ entry: HistoryEntry) {
        guard let queue = dbQueue else { return }
        let limit = historyLimit  // capture on MainActor before Task.detached
        Task.detached(priority: .utility) {
            do {
                try await queue.write { db in
                    try entry.insert(db)
                    // WR-03/WR-04: delete unpinned rows beyond the configured limit in one write
                    try db.execute(sql: """
                        DELETE FROM historyEntry
                        WHERE pinned = 0
                        AND id NOT IN (
                            SELECT id FROM historyEntry
                            WHERE pinned = 0
                            ORDER BY timestamp DESC
                            LIMIT \(limit)
                        )
                    """)
                }
            } catch {
                print("[HistoryStore] Save failed: \(error)")
            }
        }
    }

    /// Remove all unpinned items. Pinned items survive (D-09).
    func clearUnpinned() {
        guard let queue = dbQueue else { return }
        Task.detached(priority: .utility) {
            do {
                _ = try await queue.write { db in
                    try HistoryEntry.filter(Column("pinned") == false).deleteAll(db)
                }
            } catch {
                print("[HistoryStore] clearUnpinned failed: \(error)")
            }
        }
    }

    /// Pin or unpin an entry.
    func togglePin(entry: HistoryEntry) {
        guard let queue = dbQueue, let entryId = entry.id else { return }
        let newPinned = !entry.pinned
        Task.detached(priority: .utility) {
            do {
                _ = try await queue.write { db in
                    try db.execute(sql: "UPDATE historyEntry SET pinned = ? WHERE id = ?",
                                   arguments: [newPinned, entryId])
                }
            } catch {
                print("[HistoryStore] togglePin failed: \(error)")
            }
        }
    }

    /// Delete a single entry.
    func delete(entry: HistoryEntry) {
        guard let queue = dbQueue, let entryId = entry.id else { return }
        Task.detached(priority: .utility) {
            do {
                _ = try await queue.write { db in
                    try db.execute(sql: "DELETE FROM historyEntry WHERE id = ?",
                                   arguments: [entryId])
                }
            } catch {
                print("[HistoryStore] delete failed: \(error)")
            }
        }
    }

    /// Search history entries by tool name or input using GRDB LIKE.
    /// T-06-T: GRDB parameterized query — never string-interpolated into SQL (INFRA-08).
    func search(_ query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        let q = query.lowercased()
        return entries.filter {
            $0.tool.localizedCaseInsensitiveContains(q) ||
            $0.input.localizedCaseInsensitiveContains(q)
        }
    }

    /// Async search using GRDB SQL LIKE for full text search (INFRA-08, T-06-T).
    /// Uses parameterized binding — never interpolates user input into SQL.
    func searchAsync(_ query: String) async -> [HistoryEntry] {
        guard let queue = dbQueue, !query.isEmpty else { return search(query) }
        // WR-05: escape LIKE metacharacters so '_' matches a literal underscore (not any character)
        // and '%' matches a literal percent sign. The escape character '\' is itself escaped first.
        // The ESCAPE clause below tells SQLite which character to use as the escape prefix.
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let pattern = "%\(escaped)%"
        do {
            return try await queue.read { db in
                // T-06-T: GRDB parameterized query interface — user input is bound, not interpolated
                // WR-05: pass escape: "\\" so GRDB appends ESCAPE '\\' to the LIKE clause
                try HistoryEntry
                    .filter(
                        Column("tool").like(pattern, escape: "\\") ||
                        Column("input").like(pattern, escape: "\\")
                    )
                    .order(Column("pinned").desc, Column("timestamp").desc)
                    .limit(50)
                    .fetchAll(db)
            }
        } catch {
            print("[HistoryStore] searchAsync failed: \(error)")
            return search(query)
        }
    }

    /// Unpinned item count — used for "Clear N items?" confirmation copy.
    var unpinnedCount: Int {
        entries.filter { !$0.pinned }.count
    }
}
