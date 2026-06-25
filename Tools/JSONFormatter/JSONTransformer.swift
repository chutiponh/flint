// Tools/JSONFormatter/JSONTransformer.swift
// Pure JSON transformer — NO SwiftUI/AppKit imports (testable without UI).
// Source: RESEARCH.md § "Native API Recipes" → "JSON Tool (JSON-01..06)" [VERIFIED]
// INFRA-17: Returns Result, never force-unwraps, never crashes on bad input.

import Foundation

enum JSONTransformer {
    struct JSONError: Error, Equatable {
        let message: String
        let line: Int?
        let column: Int?

        var displayMessage: String {
            if let line, let column {
                return "Invalid JSON at line \(line), column \(column)"
            } else if let line {
                return "Invalid JSON at line \(line)"
            }
            return message
        }
    }

    // MARK: - Public API

    /// JSON-01: Pretty-print with configurable indent (2 spaces, 4 spaces, or tab).
    /// `indent`: 2 = two spaces, 4 = four spaces, 0 = tab character.
    static func prettyPrint(_ input: String, indent: Int = 2) -> Result<String, JSONError> {
        guard let data = input.data(using: .utf8) else {
            return .failure(JSONError(message: "Invalid UTF-8 encoding", line: nil, column: nil))
        }
        // INFRA-17: size guard — reject absurdly large inputs gracefully
        guard data.count <= 50_000_000 else {   // 50 MB limit
            return .failure(JSONError(message: "Input too large (>50 MB)", line: nil, column: nil))
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            let options: JSONSerialization.WritingOptions = [.prettyPrinted, .withoutEscapingSlashes]
            let prettyData = try JSONSerialization.data(withJSONObject: obj, options: options)
            guard var str = String(data: prettyData, encoding: .utf8) else {
                return .failure(JSONError(message: "Failed to encode output as UTF-8", line: nil, column: nil))
            }
            str = applyIndent(str, indent: indent)
            return .success(str)
        } catch {
            return .failure(jsonError(from: error, in: input))
        }
    }

    /// JSON-02: Minify JSON (remove all whitespace).
    static func minify(_ input: String) -> Result<String, JSONError> {
        guard let data = input.data(using: .utf8) else {
            return .failure(JSONError(message: "Invalid UTF-8 encoding", line: nil, column: nil))
        }
        guard data.count <= 50_000_000 else {
            return .failure(JSONError(message: "Input too large (>50 MB)", line: nil, column: nil))
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            let minData = try JSONSerialization.data(withJSONObject: obj, options: [.withoutEscapingSlashes])
            guard let str = String(data: minData, encoding: .utf8) else {
                return .failure(JSONError(message: "Failed to encode output as UTF-8", line: nil, column: nil))
            }
            return .success(str)
        } catch {
            return .failure(jsonError(from: error, in: input))
        }
    }

    /// JSON-04: Pretty-print with keys sorted alphabetically.
    static func prettyPrintSorted(_ input: String, indent: Int = 2) -> Result<String, JSONError> {
        guard let data = input.data(using: .utf8) else {
            return .failure(JSONError(message: "Invalid UTF-8 encoding", line: nil, column: nil))
        }
        guard data.count <= 50_000_000 else {
            return .failure(JSONError(message: "Input too large (>50 MB)", line: nil, column: nil))
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let prettyData = try JSONSerialization.data(withJSONObject: obj, options: options)
            guard var str = String(data: prettyData, encoding: .utf8) else {
                return .failure(JSONError(message: "Failed to encode output as UTF-8", line: nil, column: nil))
            }
            str = applyIndent(str, indent: indent)
            return .success(str)
        } catch {
            return .failure(jsonError(from: error, in: input))
        }
    }

    // MARK: - Private Helpers

    /// JSONSerialization always uses 2-space indent.
    /// This function converts 2-space to 4-space or tab as needed.
    private static func applyIndent(_ str: String, indent: Int) -> String {
        switch indent {
        case 4:
            // JSONSerialization uses 2-space — replace with 4-space
            return str.replacingOccurrences(of: "  ", with: "    ")
        case 0:
            // Tab indent
            return str.replacingOccurrences(of: "  ", with: "\t")
        default:
            // indent == 2 — keep JSONSerialization's default 2-space
            return str
        }
    }

    /// JSON-03: Extract line + column from NSError.
    /// JSONSerialization error userInfo contains:
    ///   - NSDebugDescription (key: "NSDebugDescription"): "Invalid value around line N, column N."
    ///   - NSJSONSerializationErrorIndex: character offset (Int)
    /// Source: Verified via testing — NSDebugDescription format on macOS 14.
    private static func jsonError(from error: Error, in source: String) -> JSONError {
        let ns = error as NSError

        // Primary: use NSJSONSerializationErrorIndex for exact character offset
        if let charIdx = ns.userInfo["NSJSONSerializationErrorIndex"] as? Int {
            let charOffset = min(charIdx, source.count)
            let prefixStr = String(source.prefix(charOffset))
            let lines = prefixStr.components(separatedBy: "\n")
            let line = lines.count
            let column = (lines.last?.count ?? 0) + 1
            let desc = (ns.userInfo["NSDebugDescription"] as? String) ?? error.localizedDescription
            return JSONError(message: desc, line: line, column: column)
        }

        // Fallback: parse "line N, column N" from NSDebugDescription string
        let desc = (ns.userInfo["NSDebugDescription"] as? String) ?? error.localizedDescription
        if let (line, col) = extractLineColumn(from: desc) {
            return JSONError(message: desc, line: line, column: col)
        }

        return JSONError(message: desc, line: nil, column: nil)
    }

    /// Parses "around line N, column N" from Foundation JSON error descriptions.
    private static func extractLineColumn(from description: String) -> (Int, Int)? {
        // Pattern: "line N, column N" or "around line N, column N"
        let pattern = #"line (\d+), column (\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsDesc = description as NSString
        let range = NSRange(location: 0, length: nsDesc.length)
        guard let match = regex.firstMatch(in: description, options: [], range: range) else {
            return nil
        }
        let lineRange = match.range(at: 1)
        let colRange = match.range(at: 2)
        guard lineRange.location != NSNotFound, colRange.location != NSNotFound else { return nil }
        let lineStr = nsDesc.substring(with: lineRange)
        let colStr = nsDesc.substring(with: colRange)
        guard let line = Int(lineStr), let col = Int(colStr) else { return nil }
        return (line, col)
    }
}
