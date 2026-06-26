// UI/Components/BitFieldView.swift
// Interactive bit-toggle grid for the Number Base Converter.
// Pure SwiftUI — no NSViewRepresentable needed.
// NUM-03, D-14, INFRA-15 (VoiceOver labels), INFRA-17 (no crash on any input).
//
// Bit-index convention:
//   Bit 0 = LSB (least significant bit), bit (width-1) = MSB.
//   Buttons are laid out with higher-index bits on the LEFT and lower-index on the RIGHT,
//   matching standard binary notation (MSB-first, reading left-to-right).
//   Within a row, nibbles are separated by an 8pt gap; bytes by a 12pt gap.
//   Bit-index labels appear below each column.

import SwiftUI

struct BitFieldView: View {
    /// Canonical bit pattern (full 64-bit; only lower `width.rawValue` bits are active).
    @Binding var pattern: UInt64
    /// Active bit width — determines how many buttons to show.
    let width: BitWidth
    /// Called when the user taps a bit — pass back the XOR'd pattern.
    let onToggle: (UInt64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bit Field")
                .font(.caption)
                .foregroundStyle(.secondary)
            bitRows
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Layout

    @ViewBuilder
    private var bitRows: some View {
        // We render bits MSB→LSB (left→right), in groups of 8 bits per row.
        // A 64-bit value has 8 rows; a 8-bit value has 1 row.
        let totalBits = width.rawValue
        let bitsPerRow = 8       // one byte per row — keeps the 480pt popover readable at 64-bit
        let rowCount = totalBits / bitsPerRow

        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                // Row 0 = most-significant byte; last row = least-significant byte
                let highBit = totalBits - 1 - (rowIndex * bitsPerRow)   // MSB of this row
                let lowBit  = highBit - (bitsPerRow - 1)                 // LSB of this row

                BitRowView(
                    pattern: pattern,
                    highBit: highBit,
                    lowBit: lowBit,
                    onToggle: onToggle
                )
            }
        }
    }
}

// MARK: - BitRowView (one byte = 8 bits, grouped into 2 nibbles)

private struct BitRowView: View {
    let pattern: UInt64
    let highBit: Int    // index of leftmost (most-significant) bit in this row
    let lowBit: Int     // index of rightmost (least-significant) bit in this row
    let onToggle: (UInt64) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 8 bits split into two nibbles: [highBit..highBit-3] and [highBit-4..lowBit]
            nibbleView(startBit: highBit, count: 4)
            Spacer().frame(width: 8)   // 8pt inter-nibble gap
            nibbleView(startBit: highBit - 4, count: 4)
        }
    }

    @ViewBuilder
    private func nibbleView(startBit: Int, count: Int) -> some View {
        VStack(spacing: 2) {
            // Buttons row (MSB→LSB within nibble, left→right)
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { offset in
                    let bitIndex = startBit - offset
                    let bitValue = (pattern >> bitIndex) & 1
                    BitButtonView(
                        index: bitIndex,
                        isSet: bitValue == 1,
                        onTap: {
                            let newPattern = NumberBaseTransformer.toggleBit(pattern: pattern, index: bitIndex)
                            onToggle(newPattern)
                        }
                    )
                }
            }
            // Index labels row
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { offset in
                    let bitIndex = startBit - offset
                    Text("\(bitIndex)")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, alignment: .center)
                }
            }
        }
    }
}

// MARK: - BitButtonView (single bit toggle button)

private struct BitButtonView: View {
    let index: Int
    let isSet: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isSet ? "1" : "0")
                .font(.system(size: 10, design: .monospaced))
                .fontWeight(isSet ? .bold : .regular)
                .foregroundStyle(isSet ? Color.accentColor : Color.primary.opacity(0.6))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSet
                              ? Color.accentColor.opacity(0.15)
                              : Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        // INFRA-15: state-spoken VoiceOver label
        .accessibilityLabel("Bit \(index), value \(isSet ? 1 : 0)")
        .accessibilityHint("Double-tap to toggle bit \(index)")
        .accessibilityAddTraits(isSet ? [.isSelected] : [])
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("8-bit 0xFF").font(.caption)
        BitFieldView(
            pattern: .constant(0xFF),
            width: .w8,
            onToggle: { _ in }
        )
        Divider()
        Text("16-bit 0x1234").font(.caption)
        BitFieldView(
            pattern: .constant(0x1234),
            width: .w16,
            onToggle: { _ in }
        )
    }
    .padding()
    .frame(width: 480)
}
