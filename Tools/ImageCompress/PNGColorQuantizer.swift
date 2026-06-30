// Tools/ImageCompress/PNGColorQuantizer.swift
// Pure-Swift median-cut color quantizer: truecolor RGBA CGImage -> <=256-color palette + per-pixel index map.
// Root-cause fix for UAT Test 8: photographic PNGs barely shrink because the transformer re-encodes them
// as truecolor RGBA. Reducing to an 8-bit colormap (this quantizer) + an indexed PNG (IndexedPNGEncoder)
// reproduces pngquant-class savings with ZERO external dependencies (libimagequant/pngquant are GPL/LGPL,
// blocking App Store v2 sandbox — locked decision).
//
// NO SwiftUI/AppKit imports — pure transformer. CoreGraphics (CGImage input) + Foundation only.
// INFRA-17: zero/huge dimensions and failed context creation return nil; no force-unwraps on pixel reads.

import Foundation
import CoreGraphics

/// Reduces a truecolor image to a <=256-entry palette using classic median-cut.
enum PNGColorQuantizer {

    /// Result of quantization: a palette + alpha aligned to it + a per-pixel index map.
    struct QuantizedImage {
        let width: Int
        let height: Int
        let palette: [(UInt8, UInt8, UInt8)]
        let alpha: [UInt8]          // aligned to `palette`
        let indices: [UInt8]        // length width*height, each < palette.count
    }

    /// Quantizes `cgImage` into at most `maxColors` (capped at 256) palette entries.
    ///
    /// - Returns: A `QuantizedImage`, or nil on degenerate input / decode failure (INFRA-17).
    static func quantize(cgImage: CGImage, maxColors: Int = 256) -> QuantizedImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let cap = max(1, min(maxColors, 256))

        // --- 1. Decode into a tightly-packed RGBA8 buffer (premultipliedLast, matching test helpers). ---
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ok: Bool = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(
                    data: base,
                    width: width, height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { return nil }

        let pixelCount = width * height

        // --- 2. Collect pixels as packed RGBA UInt32 keys; tally counts for representative averaging. ---
        // Each pixel: (r,g,b,a). Pack as r<<24 | g<<16 | b<<8 | a.
        var pixelKeys = [UInt32](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let o = i * 4
            let r = UInt32(pixels[o])
            let g = UInt32(pixels[o + 1])
            let b = UInt32(pixels[o + 2])
            let a = UInt32(pixels[o + 3])
            pixelKeys[i] = (r << 24) | (g << 16) | (b << 8) | a
        }

        // Unique colors with occurrence counts (median-cut splits on unique colors, weighted by count).
        var counts: [UInt32: Int] = [:]
        counts.reserveCapacity(min(pixelCount, 4096))
        for key in pixelKeys { counts[key, default: 0] += 1 }

        // --- 3. Median-cut on RGB; carry alpha along for per-box averaging. ---
        struct ColorEntry { let r, g, b, a: UInt8; let count: Int }
        var allColors: [ColorEntry] = []
        allColors.reserveCapacity(counts.count)
        for (key, c) in counts {
            allColors.append(ColorEntry(
                r: UInt8((key >> 24) & 0xFF),
                g: UInt8((key >> 16) & 0xFF),
                b: UInt8((key >> 8) & 0xFF),
                a: UInt8(key & 0xFF),
                count: c
            ))
        }

        // Box = a slice of the color list. Split the box with the widest color axis at its median.
        struct Box { var colors: [ColorEntry] }

        // widest axis range for a box
        func axisRanges(_ colors: [ColorEntry]) -> (rRange: Int, gRange: Int, bRange: Int) {
            var rMin = 255, rMax = 0, gMin = 255, gMax = 0, bMin = 255, bMax = 0
            for c in colors {
                rMin = min(rMin, Int(c.r)); rMax = max(rMax, Int(c.r))
                gMin = min(gMin, Int(c.g)); gMax = max(gMax, Int(c.g))
                bMin = min(bMin, Int(c.b)); bMax = max(bMax, Int(c.b))
            }
            return (rMax - rMin, gMax - gMin, bMax - bMin)
        }

        var boxes: [Box] = [Box(colors: allColors)]

        // Split until we reach `cap` boxes or no box can be split further.
        while boxes.count < cap {
            // Pick the splittable box with the largest single-axis range.
            var targetIndex = -1
            var bestRange = 0
            for (i, box) in boxes.enumerated() where box.colors.count > 1 {
                let (rr, gr, br) = axisRanges(box.colors)
                let m = max(rr, max(gr, br))
                if m > bestRange { bestRange = m; targetIndex = i }
            }
            if targetIndex == -1 { break } // nothing left to split

            var box = boxes[targetIndex]
            let (rr, gr, br) = axisRanges(box.colors)
            // Sort along the widest axis, then split at the median position.
            if rr >= gr && rr >= br {
                box.colors.sort { $0.r < $1.r }
            } else if gr >= br {
                box.colors.sort { $0.g < $1.g }
            } else {
                box.colors.sort { $0.b < $1.b }
            }
            let mid = box.colors.count / 2
            let lower = Box(colors: Array(box.colors[0..<mid]))
            let upper = Box(colors: Array(box.colors[mid...]))
            boxes[targetIndex] = lower
            boxes.append(upper)
        }

        // --- 4. Build palette + alpha from per-box (count-weighted) averages. ---
        var palette: [(UInt8, UInt8, UInt8)] = []
        var paletteAlpha: [UInt8] = []
        palette.reserveCapacity(boxes.count)
        paletteAlpha.reserveCapacity(boxes.count)
        for box in boxes where !box.colors.isEmpty {
            var sumR = 0, sumG = 0, sumB = 0, sumA = 0, total = 0
            for c in box.colors {
                let w = c.count
                sumR += Int(c.r) * w
                sumG += Int(c.g) * w
                sumB += Int(c.b) * w
                sumA += Int(c.a) * w
                total += w
            }
            guard total > 0 else { continue }
            palette.append((
                UInt8(clamping: (sumR + total / 2) / total),
                UInt8(clamping: (sumG + total / 2) / total),
                UInt8(clamping: (sumB + total / 2) / total)
            ))
            paletteAlpha.append(UInt8(clamping: (sumA + total / 2) / total))
        }
        guard !palette.isEmpty else { return nil }

        // --- 5. Map each pixel to the nearest palette entry (RGB squared distance), cached by RGBA key. ---
        var lookupCache: [UInt32: UInt8] = [:]
        lookupCache.reserveCapacity(min(counts.count, 4096))

        func nearestIndex(r: Int, g: Int, b: Int) -> UInt8 {
            var best = 0
            var bestDist = Int.max
            for (i, p) in palette.enumerated() {
                let dr = r - Int(p.0)
                let dg = g - Int(p.1)
                let db = b - Int(p.2)
                let dist = dr * dr + dg * dg + db * db
                if dist < bestDist { bestDist = dist; best = i; if dist == 0 { break } }
            }
            return UInt8(best)
        }

        var indices = [UInt8](repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let key = pixelKeys[i]
            if let cached = lookupCache[key] {
                indices[i] = cached
            } else {
                let o = i * 4
                let idx = nearestIndex(r: Int(pixels[o]), g: Int(pixels[o + 1]), b: Int(pixels[o + 2]))
                lookupCache[key] = idx
                indices[i] = idx
            }
        }

        return QuantizedImage(
            width: width,
            height: height,
            palette: palette,
            alpha: paletteAlpha,
            indices: indices
        )
    }
}
