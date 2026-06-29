// UI/ToolHeaderView.swift
// Back-to-picker header (D-02) — sits at the top of every tool view, wrapping tool.makeView().
// Stateless: caller (MenuBarPopoverView) owns onBack callback which sets navigationState = .root.
//
// Layout: HStack (back button | centered tool name | invisible spacer) + Divider()
// Back button: chevron.left + "All Tools" in .accentColor at 13pt regular
// Tool name: 15pt semibold .primary, .accessibilityAddTraits(.isHeader) for VoiceOver orientation
// Minimum height: 44pt (standard hit-target rule)
//
// Design: 04-UI-SPEC.md § "Back-to-Picker Affordance — D-02"
// Pattern: UI/Components/DetectionBannerView.swift (stateless HStack + 12pt/8pt padding)
// Colors: semantic only (INFRA-14) — no hardcoded hex

import SwiftUI

struct ToolHeaderView: View {
    let toolName: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Leading: back button — chevron.left + "All Tools" in accent color
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13))
                        Text("All Tools")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to tool picker")

                // Center: tool name (heading landmark for VoiceOver)
                Text(toolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                // Trailing: invisible spacer mirroring the back-button width to balance the title
                // Uses a hidden clone of the back button content to match width automatically.
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13))
                    Text("All Tools")
                        .font(.system(size: 13))
                }
                .hidden()
                .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 12)

            Divider()
        }
    }
}
