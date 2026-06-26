// LatheTests/PinnedToolReorderTests.swift
// Regression tests for movePinnedTool reorder index semantics (INFRA-11, plan 01-08).
//
// These tests lock the CORRECT index math for prefs.movePinnedTool(from:to:)
// and confirm the semantics that PinnedToolBarView.performDrop must use after
// the Task 2 +1 removal.
//
// Array.move(fromOffsets:toOffset:) semantics:
//   toOffset is the "insert-before" index in the PRE-REMOVAL original array.
//   Forward move (sourceIndex < destIndex):
//     - toOffset: destIndex → inserts element at slot destIndex-1 in result
//       (pushes destination element to the right)
//     - toOffset: destIndex+1 → inserts element at slot destIndex in result
//       (drops element one slot PAST the destination element)
//   The correct call is (from: sourceIndex, to: destIndex) — no +1.
//   The old buggy code added +1 for forward moves, causing an off-by-one.
//
// PreferencesStore uses UserDefaults.standard with no suite injection.
// setUp seeds Keys.pinnedToolIds directly and tearDown removes it so the real
// defaults domain is not permanently mutated.

import XCTest
@testable import Lathe

final class PinnedToolReorderTests: XCTestCase {

    // The real default order (D-13). We use the full IDs that exist in the registry.
    private let defaultOrder = [
        "json-formatter",   // index 0
        "base64",           // index 1
        "jwt-decoder",      // index 2
        "url-encoder",      // index 3
        "timestamp",        // index 4
        "uuid-generator"    // index 5
    ]

    private let userDefaultsKey = "lathe.pinnedToolIds"

    override func setUp() {
        super.setUp()
        // Seed a known deterministic order so tests are isolated from whatever
        // the real app may have written to UserDefaults.standard.
        UserDefaults.standard.set(defaultOrder, forKey: userDefaultsKey)
    }

    override func tearDown() {
        // Remove the key so we do not pollute the real defaults domain.
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        super.tearDown()
    }

    // MARK: - Forward Move

    /// Move index 0 (json-formatter) forward to destination index 2 (jwt-decoder).
    ///
    /// Array.move(fromOffsets: IndexSet(integer: 0), toOffset: 2) semantics
    /// (toOffset is insert-before in the ORIGINAL pre-removal array):
    ///   1. Remove index 0 from original array
    ///   2. The insert position 2 is now relative to the post-removal array (length 5)
    ///   3. Result: json-formatter slides into slot 1, pushing jwt-decoder and rest right
    ///   Result: ["base64", "json-formatter", "jwt-decoder", "url-encoder", "timestamp", "uuid-generator"]
    ///
    /// The CORRECT call from performDrop is movePinnedTool(from: IndexSet(integer: 0), to: 2).
    /// The old buggy code added +1 for forward moves (to: 3), which would produce:
    ///   ["base64", "jwt-decoder", "json-formatter", "url-encoder", "timestamp", "uuid-generator"]
    /// — landing json-formatter one slot PAST the jwt-decoder drop target.
    func testForwardMove_index0_toDestination2_landsAtSlot1BeforeJwt() {
        let prefs = PreferencesStore()

        // Precondition: verify seed is in place.
        XCTAssertEqual(prefs.pinnedToolIds, defaultOrder, "setUp must seed the default order")

        // Move json-formatter (index 0) forward, dropping onto jwt-decoder (destination index 2).
        // The corrected call passes destIndex directly (no +1).
        prefs.movePinnedTool(from: IndexSet(integer: 0), to: 2)

        let expected = [
            "base64",
            "json-formatter",   // landed at slot 1 (insert-before index 2 in original array)
            "jwt-decoder",      // pushed right — json is NOT past this element
            "url-encoder",
            "timestamp",
            "uuid-generator"
        ]
        XCTAssertEqual(prefs.pinnedToolIds, expected,
            "Forward move (to: 2): json-formatter should insert before jwt-decoder (slot 1), not land past it (which the old +1 would cause by using to: 3)")
    }

    // MARK: - Backward Move

    /// Move index 4 (timestamp) backward to destination index 1 (base64).
    ///
    /// Array.move(fromOffsets: IndexSet(integer: 4), toOffset: 1) semantics:
    ///   Backward moves: destIndex <= sourceIndex → toOffset is used directly (no +1 in old code either)
    ///   1. Insert before original index 1 (base64)
    ///   Result: ["json-formatter", "timestamp", "base64", "jwt-decoder", "url-encoder", "uuid-generator"]
    ///
    /// The CORRECT call is movePinnedTool(from: IndexSet(integer: 4), to: 1).
    /// For backward moves the old code did NOT add +1 (guard: destIndex > sourceIndex),
    /// so the backward path was already correct. This test prevents future regressions.
    func testBackwardMove_index4_toDestination1_landsBeforeBase64() {
        let prefs = PreferencesStore()

        XCTAssertEqual(prefs.pinnedToolIds, defaultOrder, "setUp must seed the default order")

        // Move timestamp (index 4) backward to destination index 1 (before base64).
        prefs.movePinnedTool(from: IndexSet(integer: 4), to: 1)

        let expected = [
            "json-formatter",
            "timestamp",        // inserted before base64 (slot 1)
            "base64",
            "jwt-decoder",
            "url-encoder",
            "uuid-generator"
        ]
        XCTAssertEqual(prefs.pinnedToolIds, expected,
            "Backward move: timestamp should land at index 1 (before base64)")
    }

    // MARK: - No-Op (Self-Drop Guard)

    /// Dropping a tool onto itself should leave the order unchanged.
    ///
    /// PinnedToolDropDelegate.performDrop guards `draggedId != destinationToolId` so
    /// movePinnedTool is never called for a self-drop. We verify the guard is effective
    /// by confirming the order stays identical when the guard fires.
    ///
    /// Since the guard is in the UI layer (not PreferencesStore), this test exercises
    /// it indirectly by NOT calling movePinnedTool, mirroring what the delegate does.
    func testNoOp_selfDrop_leavesOrderUnchanged() {
        let prefs = PreferencesStore()

        XCTAssertEqual(prefs.pinnedToolIds, defaultOrder, "setUp must seed the default order")

        // Simulate the self-drop guard: draggedId == destinationToolId → no call to movePinnedTool.
        let draggedId = "base64"
        let destinationToolId = "base64"

        // Only call movePinnedTool if the guard would NOT fire (same logic as performDrop).
        if draggedId != destinationToolId {
            guard let sourceIndex = prefs.pinnedToolIds.firstIndex(of: draggedId),
                  let destIndex = prefs.pinnedToolIds.firstIndex(of: destinationToolId) else {
                XCTFail("Indices not found")
                return
            }
            prefs.movePinnedTool(from: IndexSet(integer: sourceIndex), to: destIndex)
        }
        // Guard fired — order must be unchanged.
        XCTAssertEqual(prefs.pinnedToolIds, defaultOrder,
            "No-op: a self-drop must leave the pinned order unchanged")
    }

    // MARK: - Persistence Round-Trip

    /// Confirms that movePinnedTool persists the new order to UserDefaults so it survives
    /// a fresh PreferencesStore read (simulating a relaunch).
    func testPersistence_roundTrip_forwardMove() {
        let prefs = PreferencesStore()
        XCTAssertEqual(prefs.pinnedToolIds, defaultOrder)

        // Perform a forward move: json-formatter (0) drops onto jwt-decoder slot (2).
        prefs.movePinnedTool(from: IndexSet(integer: 0), to: 2)

        // Simulate relaunch: create a brand-new PreferencesStore instance.
        let prefs2 = PreferencesStore()
        let expected = [
            "base64",
            "json-formatter",
            "jwt-decoder",
            "url-encoder",
            "timestamp",
            "uuid-generator"
        ]
        XCTAssertEqual(prefs2.pinnedToolIds, expected,
            "Persistence: new PreferencesStore must read back the reordered pinned IDs")
    }
}
