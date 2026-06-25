// UI/Components/DetectionBannerView.swift
// Non-destructive detection banner (D-04).
// Animates in when a detection result is available, hides when nil.
// Source: UI-SPEC.md § "Detection Banner"

import SwiftUI

struct DetectionBannerView: View {
    let result: DetectionResult
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Detected: \(result.toolName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Open \(result.toolName)?")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Open \(result.toolName)") {
                onAccept()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel("Open \(result.toolName)")

            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .controlSize(.small)
            .accessibilityLabel("Dismiss detection")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Detected \(result.toolName). Open \(result.toolName)?")
    }
}

#Preview {
    DetectionBannerView(
        result: DetectionResult(toolId: "json-formatter", toolName: "JSON Formatter", sample: "{\"a\":1}"),
        onAccept: {},
        onDismiss: {}
    )
    .padding()
}
