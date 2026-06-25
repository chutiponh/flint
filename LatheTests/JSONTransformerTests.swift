// LatheTests/JSONTransformerTests.swift
// Unit tests for JSONTransformer — covers JSON-01..06 + INFRA-17 no-crash guarantee.
// TDD: Tests written against the behavior spec before implementation.

import XCTest
@testable import Lathe

final class JSONTransformerTests: XCTestCase {

    // MARK: - JSON-01: Pretty-Print

    func testPrettyPrint_twoSpaceIndent() throws {
        let input = #"{"b":1,"a":2}"#
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        // Should contain 2-space indented keys
        XCTAssertTrue(output.contains("  \"b\"") || output.contains("  \"a\""),
                      "Expected 2-space indent, got:\n\(output)")
        // Should be valid JSON
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: output.data(using: .utf8)!))
    }

    func testPrettyPrint_fourSpaceIndent() throws {
        let input = #"{"key":"value"}"#
        let result = JSONTransformer.prettyPrint(input, indent: 4)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertTrue(output.contains("    \"key\""),
                      "Expected 4-space indent, got:\n\(output)")
    }

    func testPrettyPrint_tabIndent() throws {
        let input = #"{"key":"value"}"#
        let result = JSONTransformer.prettyPrint(input, indent: 0)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertTrue(output.contains("\t\"key\""),
                      "Expected tab indent, got:\n\(output)")
    }

    func testPrettyPrint_array() throws {
        let input = "[1,2,3]"
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertTrue(output.contains("[") && output.contains("1"))
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: output.data(using: .utf8)!))
    }

    // MARK: - JSON-02: Minify

    func testMinify_removesWhitespace() throws {
        let input = #"{ "a": 1 }"#
        let result = JSONTransformer.minify(input)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertEqual(output, #"{"a":1}"#)
    }

    func testMinify_complexObject() throws {
        let input = """
        {
            "name": "Alice",
            "age": 30,
            "active": true
        }
        """
        let result = JSONTransformer.minify(input)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        // Output should have no newlines or extra spaces
        XCTAssertFalse(output.contains("\n"), "Minified output should not contain newlines")
        XCTAssertFalse(output.contains("  "), "Minified output should not contain double spaces")
    }

    // MARK: - JSON-03: Error with line:column

    func testPrettyPrint_malformedJSON_returnsFailure() {
        let input = #"{"a":}"#
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        guard case .failure(let error) = result else {
            XCTFail("Expected failure for malformed JSON, got success")
            return
        }
        // JSON-03: should have non-nil line
        XCTAssertNotNil(error.line, "Expected non-nil line for malformed JSON")
        // Should also have non-nil column (or at minimum a useful message)
        XCTAssertFalse(error.message.isEmpty, "Error message should not be empty")
    }

    func testPrettyPrint_malformedJSON_lineIsOne() {
        let input = #"{"a":}"#  // Error on line 1
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        guard case .failure(let error) = result else {
            XCTFail("Expected failure")
            return
        }
        XCTAssertEqual(error.line, 1, "Single-line malformed JSON error should be on line 1")
    }

    func testPrettyPrint_malformedJSON_displayMessage() {
        let input = #"{"a":}"#
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        guard case .failure(let error) = result else {
            XCTFail("Expected failure")
            return
        }
        let message = error.displayMessage
        XCTAssertTrue(message.contains("line") || message.contains("Invalid"),
                      "Error display message should be informative: \(message)")
    }

    func testMinify_malformedJSON_returnsFailure() {
        let input = "{incomplete"
        let result = JSONTransformer.minify(input)
        if case .success = result {
            XCTFail("Expected failure for incomplete JSON")
        }
    }

    // MARK: - JSON-04: Sort Keys

    func testPrettyPrintSorted_sortsByKey() throws {
        let input = #"{"z":3,"a":1,"m":2}"#
        let result = JSONTransformer.prettyPrintSorted(input, indent: 2)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        // Keys should appear in alphabetical order
        let aIdx = output.range(of: "\"a\"")
        let mIdx = output.range(of: "\"m\"")
        let zIdx = output.range(of: "\"z\"")
        guard let a = aIdx, let m = mIdx, let z = zIdx else {
            XCTFail("Expected all keys in output: \(output)")
            return
        }
        XCTAssertTrue(a.lowerBound < m.lowerBound, "\"a\" should appear before \"m\"")
        XCTAssertTrue(m.lowerBound < z.lowerBound, "\"m\" should appear before \"z\"")
    }

    func testPrettyPrintSorted_validJSON() throws {
        let input = #"{"b":2,"a":1}"#
        let result = JSONTransformer.prettyPrintSorted(input, indent: 2)
        guard case .success(let output) = result else {
            XCTFail("Expected success")
            return
        }
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: output.data(using: .utf8)!))
    }

    // MARK: - INFRA-17: No crash on bad input

    func testPrettyPrint_invalidUTF8_returnsFailure() {
        // Create invalid UTF-8 bytes — this can't be represented as a Swift String,
        // so we test with a corrupted input scenario via empty/garbage content.
        // Swift strings are always valid Unicode, so we test with garbage non-JSON content.
        let input = "not json at all \u{FFFD}"
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        // Should return failure, not crash
        if case .success = result {
            XCTFail("Expected failure for non-JSON input")
        }
    }

    func testPrettyPrint_oversizedGarbageInput_doesNotCrash() {
        // Feed 1MB+ of non-JSON bytes — INFRA-17: must not crash
        let garbage = String(repeating: "X", count: 1_000_000)
        let result = JSONTransformer.prettyPrint(garbage, indent: 2)
        // Should return failure, not crash
        if case .success = result {
            XCTFail("Expected failure for 1MB garbage input")
        }
        // Reaching here without crashing means INFRA-17 is satisfied
    }

    func testPrettyPrint_emptyInput_returnsFailure() {
        let result = JSONTransformer.prettyPrint("", indent: 2)
        if case .success = result {
            XCTFail("Expected failure for empty input")
        }
    }

    func testMinify_emptyInput_returnsFailure() {
        let result = JSONTransformer.minify("")
        if case .success = result {
            XCTFail("Expected failure for empty input")
        }
    }

    func testPrettyPrint_veryLargeValidJSON_succeeds() throws {
        // Build a moderately large valid JSON object (not exceeding the 50MB limit)
        var dict: [String: Int] = [:]
        for i in 0..<1000 {
            dict["key\(i)"] = i
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        let input = String(data: data, encoding: .utf8)!
        let result = JSONTransformer.prettyPrint(input, indent: 2)
        guard case .success = result else {
            XCTFail("Expected success for large valid JSON")
            return
        }
    }

    func testMinify_preservesValues() throws {
        let input = #"{"name":"Alice","score":42,"active":true,"data":null}"#
        let result = JSONTransformer.minify(input)
        guard case .success(let output) = result else {
            XCTFail("Expected success")
            return
        }
        let parsed = try JSONSerialization.jsonObject(with: output.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(parsed["name"] as? String, "Alice")
        XCTAssertEqual(parsed["score"] as? Int, 42)
        XCTAssertEqual(parsed["active"] as? Bool, true)
    }

    // MARK: - Round-trip

    func testRoundTrip_prettyThenMinify() throws {
        let original = #"{"b":1,"a":2}"#
        let pretty = JSONTransformer.prettyPrint(original, indent: 2)
        guard case .success(let prettyStr) = pretty else {
            XCTFail("Pretty failed")
            return
        }
        let minified = JSONTransformer.minify(prettyStr)
        guard case .success(let minStr) = minified else {
            XCTFail("Minify failed")
            return
        }
        // Both should be semantically equivalent JSON
        let orig = try JSONSerialization.jsonObject(with: original.data(using: .utf8)!) as! [String: Any]
        let final_ = try JSONSerialization.jsonObject(with: minStr.data(using: .utf8)!) as! [String: Any]
        XCTAssertEqual(orig["b"] as? Int, final_["b"] as? Int)
        XCTAssertEqual(orig["a"] as? Int, final_["a"] as? Int)
    }

    // MARK: - CR-03: applyIndent must not corrupt string values with consecutive spaces

    func testPrettyPrint_fourSpaceIndent_preservesConsecutiveSpacesInValues() throws {
        // CR-03: a value containing two consecutive spaces must survive 4-space indent unchanged.
        let input = #"{"key":"some  value"}"#
        let result = JSONTransformer.prettyPrint(input, indent: 4)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        // The value must be preserved exactly — "some  value" (two spaces), not "some    value"
        XCTAssertTrue(output.contains("\"some  value\""),
                      "4-space indent must not expand consecutive spaces inside string values. Output:\n\(output)")
        // Verify indentation of structural lines is correct (4 spaces per level)
        XCTAssertTrue(output.contains("    \"key\""),
                      "Expected 4-space indent for keys. Output:\n\(output)")
        // Output must still be valid JSON
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: output.data(using: .utf8)!),
                        "4-space-indented output must be valid JSON")
    }

    func testPrettyPrint_tabIndent_preservesConsecutiveSpacesInValues() throws {
        // CR-03: same invariant with tab indent.
        let input = #"{"key":"some  value"}"#
        let result = JSONTransformer.prettyPrint(input, indent: 0)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertTrue(output.contains("\"some  value\""),
                      "Tab indent must not expand consecutive spaces inside string values. Output:\n\(output)")
        XCTAssertTrue(output.contains("\t\"key\""),
                      "Expected tab indent for keys. Output:\n\(output)")
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: output.data(using: .utf8)!),
                        "Tab-indented output must be valid JSON")
    }

    func testPrettyPrint_fourSpaceIndent_multipleConsecutiveSpaces() throws {
        // CR-03: multiple pairs of spaces in different values must all survive.
        let input = #"{"a":"some  double  spaces","b":"normal"}"#
        let result = JSONTransformer.prettyPrint(input, indent: 4)
        guard case .success(let output) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertTrue(output.contains("\"some  double  spaces\""),
                      "All consecutive spaces in values must be preserved. Output:\n\(output)")
        XCTAssertTrue(output.contains("\"normal\""),
                      "Normal values must be preserved. Output:\n\(output)")
    }

    // MARK: - JSON-03 display message format

    func testErrorDisplayMessage_includesLineAndColumn() {
        let malformed = #"{"a":}"#
        let result = JSONTransformer.prettyPrint(malformed, indent: 2)
        guard case .failure(let error) = result else { return }
        if let line = error.line, let col = error.column {
            let msg = error.displayMessage
            XCTAssertTrue(msg.contains("line \(line)"), "Display message should include line number")
            XCTAssertTrue(msg.contains("column \(col)"), "Display message should include column number")
        }
    }
}
