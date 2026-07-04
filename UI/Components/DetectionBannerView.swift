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
                    .font(.monoLabel)
                    .foregroundColor(.chalk)
                Text("Open \(result.toolName)?")
                    .font(.caption)
                    .foregroundColor(.ash)
            }

            Spacer()

            Button("Open \(result.toolName)") {
                onAccept()
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Radius.chip)
                    .fill(Color.spark)
            )
            .foregroundColor(.graphite950)
            .font(.system(size: 12, weight: .semibold))
            .accessibilityLabel("Open \(result.toolName)")

            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.ash)
            .controlSize(.small)
            .accessibilityLabel("Dismiss detection")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.control)
                .fill(Color.sparkGlow)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control)
                        .stroke(Color.spark, lineWidth: 1)
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
