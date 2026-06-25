// UI/Components/InlineErrorView.swift
// Orange caption error label. Shows/hides based on nil message.
// Source: UI-SPEC.md § "Error State — Inline, Never Blank" (D-11)

import SwiftUI

struct InlineErrorView: View {
    let message: String?

    var body: some View {
        Group {
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.1), value: message)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        InlineErrorView(message: "Invalid JSON at line 1, column 5")
        InlineErrorView(message: nil)
    }
    .padding()
}
