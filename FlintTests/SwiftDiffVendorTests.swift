// FlintTests/SwiftDiffVendorTests.swift
// Supply-chain guard: proves vendored SwiftDiff matches documented behavior.
// TDD: Tests written against the behavior spec (RESEARCH §2, PLAN Task 4).

import XCTest
@testable import Flint

final class SwiftDiffVendorTests: XCTestCase {

    // MARK: - Test 1: Reconstruct both sides from diff("Hello World", "Goodbye World")
    //
    // Behavior: diff(text1: "Hello World", text2: "Goodbye World") returns a [Diff]
    // whose concatenated `.text` values reconstruct "Goodbye World" when keeping
    // `.equal` + `.insert`, and reconstruct "Hello World" when keeping
    // `.equal` + `.delete`.

    func testDiff_HelloWorld_to_GoodbyeWorld_reconstructsText2() {
        let text1 = "Hello World"
        let text2 = "Goodbye World"
        let diffs = diff(text1: text1, text2: text2)

        XCTAssertFalse(diffs.isEmpty, "diff should produce non-empty result")

        // Reconstruct text2: keep equal + insert segments
        let reconstructed2 = diffs.compactMap { d -> String? in
            switch d {
            case .equal(let s), .insert(let s): return s
            case .delete: return nil
            }
        }.joined()

        XCTAssertEqual(reconstructed2, text2,
                       "Joining equal+insert should reconstruct text2 '\(text2)', got '\(reconstructed2)'")
    }

    func testDiff_HelloWorld_to_GoodbyeWorld_reconstructsText1() {
        let text1 = "Hello World"
        let text2 = "Goodbye World"
        let diffs = diff(text1: text1, text2: text2)

        // Reconstruct text1: keep equal + delete segments
        let reconstructed1 = diffs.compactMap { d -> String? in
            switch d {
            case .equal(let s), .delete(let s): return s
            case .insert: return nil
            }
        }.joined()

        XCTAssertEqual(reconstructed1, text1,
                       "Joining equal+delete should reconstruct text1 '\(text1)', got '\(reconstructed1)'")
    }

    // MARK: - Test 2: Identical strings produce only .equal segments

    func testDiff_identicalStrings_returnsOnlyEqual() {
        let text = "Hello World"
        let diffs = diff(text1: text, text2: text)

        let hasInsert = diffs.contains { if case .insert = $0 { return true }; return false }
        let hasDelete = diffs.contains { if case .delete = $0 { return true }; return false }

        XCTAssertFalse(hasInsert, "Identical strings should produce no .insert segments")
        XCTAssertFalse(hasDelete, "Identical strings should produce no .delete segments")

        // All segments should be .equal
        for d in diffs {
            if case .equal = d { /* OK */ } else {
                XCTFail("Expected only .equal for identical strings, got \(d)")
            }
        }

        // Joined text should equal the original
        let joined = diffs.map { $0.text }.joined()
        XCTAssertEqual(joined, text)
    }

    func testDiff_emptyIdenticalStrings_returnsEmpty() {
        let diffs = diff(text1: "", text2: "")
        XCTAssertTrue(diffs.isEmpty, "Two empty strings should produce an empty diff")
    }

    // MARK: - Test 3: Empty text1 vs "abc" produces only insert segments

    func testDiff_emptyToAbc_returnsOnlyInsert() {
        let diffs = diff(text1: "", text2: "abc")

        let hasDelete = diffs.contains { if case .delete = $0 { return true }; return false }
        let hasEqual = diffs.contains { if case .equal = $0 { return true }; return false }

        XCTAssertFalse(hasDelete, "Empty text1 should produce no .delete segments")
        XCTAssertFalse(hasEqual, "Empty text1 should produce no .equal segments")

        // All text2 must be accounted for in insert segments
        let insertedText = diffs.compactMap { d -> String? in
            if case .insert(let s) = d { return s }; return nil
        }.joined()
        XCTAssertEqual(insertedText, "abc", "All inserted text should reconstruct text2")
    }

    func testDiff_emptyToAbc_reconstructsText2() {
        let diffs = diff(text1: "", text2: "abc")

        let reconstructed = diffs.compactMap { d -> String? in
            switch d {
            case .equal(let s), .insert(let s): return s
            case .delete: return nil
            }
        }.joined()

        XCTAssertEqual(reconstructed, "abc")
    }

    // MARK: - Additional correctness tests (INFRA-17: never crash on bad input)

    func testDiff_longStrings_doesNotCrash() {
        let text1 = String(repeating: "a", count: 1000)
        let text2 = String(repeating: "b", count: 1000)
        let diffs = diff(text1: text1, text2: text2)
        XCTAssertFalse(diffs.isEmpty)
        // Reconstructions must be valid
        let r2 = diffs.compactMap { d -> String? in
            if case .equal(let s) = d { return s }
            if case .insert(let s) = d { return s }
            return nil
        }.joined()
        XCTAssertEqual(r2, text2)
    }

    func testDiff_textWithNewlines_worksCorrectly() {
        let text1 = "line1\nline2\nline3"
        let text2 = "line1\nchanged\nline3"
        let diffs = diff(text1: text1, text2: text2)

        let r1 = diffs.compactMap { d -> String? in
            if case .equal(let s) = d { return s }
            if case .delete(let s) = d { return s }
            return nil
        }.joined()
        let r2 = diffs.compactMap { d -> String? in
            if case .equal(let s) = d { return s }
            if case .insert(let s) = d { return s }
            return nil
        }.joined()

        XCTAssertEqual(r1, text1, "Reconstructed text1 mismatch")
        XCTAssertEqual(r2, text2, "Reconstructed text2 mismatch")
    }
}
