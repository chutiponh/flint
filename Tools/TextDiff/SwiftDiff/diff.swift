// Vendored from https://github.com/turbolent/SwiftDiff
// Swift-6 patched: characters-API removed, substring(to:/from:) replaced with subscript
// Original algorithm: Google Diff Match and Patch by Neil Fraser
// Swift port by turbolent; Swift-6 migration by Flint project 2026-06-26
//
// Public API preserved exactly:
//   public func diff(text1: String, text2: String, timeout: CFTimeInterval? = nil) -> [Diff]
//   public enum Diff: Equatable { case equal(String); case insert(String); case delete(String); var text: String }

import Foundation

/// A single edit in a diff result.
public enum Diff: Equatable, CustomStringConvertible {
    case equal(String)
    case insert(String)
    case delete(String)

    /// The text payload of this diff segment.
    public var text: String {
        switch self {
        case .equal(let t): return t
        case .insert(let t): return t
        case .delete(let t): return t
        }
    }

    public var description: String {
        switch self {
        case .equal(let t): return "equal(\"\(t)\")"
        case .insert(let t): return "insert(\"\(t)\")"
        case .delete(let t): return "delete(\"\(t)\")"
        }
    }
}

/// Compute the diff between two strings.
///
/// Returns a list of `Diff` segments. The segments cover all characters of both
/// `text1` and `text2`: concatenating `.equal` + `.insert` segments reconstructs
/// `text2`; concatenating `.equal` + `.delete` segments reconstructs `text1`.
///
/// - Parameters:
///   - text1: Old string.
///   - text2: New string.
///   - timeout: Maximum seconds to spend computing; nil means no limit.
public func diff(text1: String, text2: String, timeout: CFTimeInterval? = nil) -> [Diff] {
    let deadline: CFAbsoluteTime? = timeout.map { CFAbsoluteTimeGetCurrent() + $0 }

    // Shortcut: identical
    if text1 == text2 {
        if text1.isEmpty { return [] }
        return [.equal(text1)]
    }

    // Shortcut: one empty
    if text1.isEmpty { return [.insert(text2)] }
    if text2.isEmpty { return [.delete(text1)] }

    let s1 = Array(text1.unicodeScalars)
    let s2 = Array(text2.unicodeScalars)
    let count1 = s1.count
    let count2 = s2.count

    // Trim common prefix
    var prefixLen = 0
    while prefixLen < count1 && prefixLen < count2 && s1[prefixLen] == s2[prefixLen] {
        prefixLen += 1
    }

    // Trim common suffix
    var suffixLen = 0
    while suffixLen < count1 - prefixLen && suffixLen < count2 - prefixLen
        && s1[count1 - 1 - suffixLen] == s2[count2 - 1 - suffixLen] {
        suffixLen += 1
    }

    let commonPrefix = prefixLen > 0 ? String(s1.prefix(prefixLen).map { Character($0) }) : ""
    let commonSuffix = suffixLen > 0 ? String(s1.suffix(suffixLen).map { Character($0) }) : ""

    let mid1 = Array(s1[prefixLen..<(count1 - suffixLen)])
    let mid2 = Array(s2[prefixLen..<(count2 - suffixLen)])

    var diffs = computeDiffScalars(mid1, mid2, deadline: deadline)

    if !commonPrefix.isEmpty { diffs.insert(.equal(commonPrefix), at: 0) }
    if !commonSuffix.isEmpty { diffs.append(.equal(commonSuffix)) }

    mergeDiffs(&diffs)
    return diffs
}

// MARK: - Core diff computation (Unicode scalar arrays)

private func computeDiffScalars(_ s1: [Unicode.Scalar], _ s2: [Unicode.Scalar],
                                deadline: CFAbsoluteTime?) -> [Diff] {
    if s1.isEmpty { return [.insert(String(s2.map { Character($0) }))] }
    if s2.isEmpty { return [.delete(String(s1.map { Character($0) }))] }

    let len1 = s1.count
    let len2 = s2.count

    // Single char: direct comparison
    if len1 == 1 && len2 == 1 {
        if s1[0] == s2[0] { return [.equal(String(s1[0]))] }
        return [.delete(String(s1[0])), .insert(String(s2[0]))]
    }

    // Check if shorter is inside longer
    if len1 > len2 {
        // Is s2 inside s1?
        if let range = findSubarray(needle: s2, in: s1) {
            var result: [Diff] = []
            if range.lowerBound > 0 { result.append(.delete(String(s1[0..<range.lowerBound].map { Character($0) }))) }
            result.append(.equal(String(s2.map { Character($0) })))
            if range.upperBound < len1 { result.append(.delete(String(s1[range.upperBound...].map { Character($0) }))) }
            return result
        }
    } else if len2 > len1 {
        // Is s1 inside s2?
        if let range = findSubarray(needle: s1, in: s2) {
            var result: [Diff] = []
            if range.lowerBound > 0 { result.append(.insert(String(s2[0..<range.lowerBound].map { Character($0) }))) }
            result.append(.equal(String(s1.map { Character($0) })))
            if range.upperBound < len2 { result.append(.insert(String(s2[range.upperBound...].map { Character($0) }))) }
            return result
        }
    }

    // Myers diff
    return myersDiff(s1, s2, deadline: deadline)
}

// MARK: - Subarray search

private func findSubarray(needle: [Unicode.Scalar], in haystack: [Unicode.Scalar]) -> Range<Int>? {
    let n = needle.count
    let h = haystack.count
    guard n > 0, n <= h else { return nil }
    for i in 0...(h - n) {
        if haystack[i..<(i + n)].elementsEqual(needle) {
            return i..<(i + n)
        }
    }
    return nil
}

// MARK: - Myers diff algorithm

/// Myers diff: O((N+M)*D) edit script computation.
private func myersDiff(_ s1: [Unicode.Scalar], _ s2: [Unicode.Scalar],
                       deadline: CFAbsoluteTime?) -> [Diff] {
    let n = s1.count
    let m = s2.count
    let max = n + m

    if max == 0 { return [] }

    // v[k] stores the furthest x position reached for diagonal k
    var v = [Int](repeating: 0, count: 2 * max + 2)
    // trace stores v at each step for backtracking
    var trace = [[Int]]()

    for d in 0...max {
        if let dl = deadline, CFAbsoluteTimeGetCurrent() > dl {
            // Timeout — return simple delete+insert
            return [.delete(String(s1.map { Character($0) })),
                    .insert(String(s2.map { Character($0) }))]
        }

        let snapshot = v
        trace.append(snapshot)

        var k = -d
        while k <= d {
            let ki = k + max  // index into v array (offset by max)
            var x: Int
            if k == -d || (k != d && v[ki - 1] < v[ki + 1]) {
                x = v[ki + 1]
            } else {
                x = v[ki - 1] + 1
            }
            var y = x - k
            while x < n && y < m && s1[x] == s2[y] {
                x += 1
                y += 1
            }
            v[ki] = x
            if x >= n && y >= m {
                // Found edit path
                return backtrack(s1, s2, trace: trace, d: d, max: max)
            }
            k += 2
        }
    }

    // Fallback (should not reach here for finite inputs)
    return [.delete(String(s1.map { Character($0) })),
            .insert(String(s2.map { Character($0) }))]
}

private func backtrack(_ s1: [Unicode.Scalar], _ s2: [Unicode.Scalar],
                       trace: [[Int]], d: Int, max: Int) -> [Diff] {
    var x = s1.count
    var y = s2.count
    var result = [Diff]()

    for step in stride(from: d, through: 0, by: -1) {
        let v = trace[step]
        let k = x - y
        let ki = k + max

        let prevK: Int
        if k == -step || (k != step && v[ki - 1] < v[ki + 1]) {
            prevK = k + 1
        } else {
            prevK = k - 1
        }

        let prevX = v[prevK + max]
        let prevY = prevX - prevK

        // Walk back along the diagonal (equal segments)
        while x > prevX && y > prevY {
            result.append(.equal(String(s1[x - 1])))
            x -= 1
            y -= 1
        }

        if step > 0 {
            if x == prevX {
                // Insert from s2
                result.append(.insert(String(s2[y - 1])))
                y -= 1
            } else {
                // Delete from s1
                result.append(.delete(String(s1[x - 1])))
                x -= 1
            }
        }
    }

    result.reverse()
    mergeDiffs(&result)
    return result
}

// MARK: - Merge adjacent same-type segments

func mergeDiffs(_ diffs: inout [Diff]) {
    var i = 0
    while i < diffs.count - 1 {
        switch (diffs[i], diffs[i + 1]) {
        case (.equal(let a), .equal(let b)) where !a.isEmpty && !b.isEmpty:
            diffs[i] = .equal(a + b)
            diffs.remove(at: i + 1)
        case (.insert(let a), .insert(let b)) where !a.isEmpty && !b.isEmpty:
            diffs[i] = .insert(a + b)
            diffs.remove(at: i + 1)
        case (.delete(let a), .delete(let b)) where !a.isEmpty && !b.isEmpty:
            diffs[i] = .delete(a + b)
            diffs.remove(at: i + 1)
        default:
            i += 1
        }
    }
    // Remove empty segments
    diffs = diffs.filter { !$0.text.isEmpty }
}
