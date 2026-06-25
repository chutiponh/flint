// Core/Extensions/Data+Base64URL.swift
// Base64URL decoder for JWT segments — handles "-" and "_" characters (RFC 4648 §5).
// PITFALL #4 FIX: Data(base64Encoded:) returns nil for URL-safe "-" and "_" chars.
// This extension applies character substitution before decode.
// Source: RESEARCH.md § "Native API Recipes" → "JWT Tool" (Data+Base64URL) [VERIFIED]
// Reused by: JWTTransformer for each JWT segment decode.
// INFRA-17: Never crashes — returns nil on invalid input rather than throwing.

import Foundation

extension Data {
    /// Decodes a Base64URL-encoded string (RFC 4648 §5) to Data.
    /// Handles "-" → "+" and "_" → "/" character substitution plus re-padding.
    /// Returns nil on invalid Base64 data rather than crashing (INFRA-17).
    static func fromBase64URL(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-add padding stripped by URL-safe encoding
        let paddingCount = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingCount)
        return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }
}
