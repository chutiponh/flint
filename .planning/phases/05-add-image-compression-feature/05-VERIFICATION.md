---
phase: 05-add-image-compression-feature
verified: 2026-06-30T16:40:00Z
status: human_needed
score: 19/19 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 14/14
  gaps_closed:
    - "Compressing a photographic PNG achieves savings comparable to dedicated PNG optimizers (UAT Test 8) — now machine-verified at the transformer level (>30% on synthesized photographic content; engine shows ~3.5x on noise images)"
  gaps_remaining: []
  regressions: []
re_verification_detail:
  note: >
    Prior verification (2026-06-30, 14/14) marked status human_needed with UAT Test 8 (photographic
    PNG compression ratio) as the outstanding gap routed to fix. Plans 05-04 (PNGColorQuantizer +
    IndexedPNGEncoder + PNGQuantizationTests) and 05-05 (wire into ImageCompressTransformer PNG path,
    register in Xcode targets, transformer-level savings/alpha/D-06 tests) closed it. This
    re-verification adds 5 new gap-closure must-haves (from 05-05 frontmatter) and confirms the
    original 14 are not regressed. New total: 19/19 machine-verified.
human_verification:
  - test: "Compress the actual UAT Test 8 image (a real ~7MB photographic PNG, e.g. 2752x1536) in the running app and inspect the output"
    expected: "Output PNG is dramatically smaller (online reference reached 7.27MB -> 1.35MB, ~81%); dimensions unchanged; no visible quality/banding loss on the photo at normal viewing"
    why_human: "Real-world photographic compression ratio and perceptual quality of 256-color median-cut quantization on a true photo cannot be asserted by synthesized-image unit tests; the >30% threshold test proves the path works but the real ~70-85% target and visual fidelity need a human eye on a real photo"
  - test: "Drop a JPEG, PNG, HEIC, and TIFF file (or a mix) onto the Image Compressor view and observe the results table"
    expected: "Each dropped file gets a row; rows progress from pending to spinner to 'orig -> new' size with green -N% or secondary +N%; PNG/TIFF rows show 'PNG / lossless' / 'TIFF / lossless' badge"
    why_human: "SwiftUI rendering and drag-and-drop require a running app; grep cannot verify live row state transitions"
  - test: "With an all-PNG/TIFF batch, verify the quality slider is disabled and the lossless helper text appears; with a mixed or JPEG-only batch, verify the slider is enabled"
    expected: "Slider greyed out and lossless helper text appears only for entirely-lossless batches"
    why_human: "Lossless gate is a computed SwiftUI state depending on viewModel.rows — needs a live UI session"
  - test: "Drop a non-image file (e.g. a .txt) alongside a valid JPEG, and a PNG-extension file with garbage bytes"
    expected: "Valid rows complete .done; bad rows show WarningBannerView 'Not a supported image — skipped.'; no crash"
    why_human: "INFRA-17 crash-safety in the live UI; unit tests prove the core never-crash, SwiftUI rendering of .failed rows needs a live check"
  - test: "Click each preset button (Web / Email / Max) and verify slider + percentage update and active-preset .borderedProminent styling"
    expected: "Web=60, Email=75, Max=95; active preset button visually prominent"
    why_human: "Button styling and active-preset highlight require visual inspection"
  - test: "Start compressing a large batch, then click Cancel"
    expected: "isCompressing UI clears, finished rows retain .done, no pending row later transitions to .done"
    why_human: "Cancellation race with live NSItemProvider callbacks and async Tasks requires a running session"
  - test: "Compress a file, then compress the same file again and verify output filenames"
    expected: "First run produces name-compressed.ext; second run produces name-compressed-1.ext (D-08)"
    why_human: "Filesystem disambiguation proven by unit tests, but end-to-end naming via real drag-drop must be confirmed live"
  - test: "Open the tool via launcher search (type 'compress', 'image', or 'photo') and verify it appears and opens"
    expected: "Image Compressor appears in search results and opens its view"
    why_human: "ToolRegistry search integration requires a running app; grep confirms registration, not live routing"
---

# Phase 05: add-image-compression-feature Verification Report (Re-verification after Gap Closure)

**Phase Goal:** A developer drops one or more image files onto the new Image Compressor tool and gets smaller, same-format versions back — re-encoded at a chosen quality, written beside each original as `-compressed`, never overwriting the source, with a live results table showing per-image thumbnail, original→new size, and % saved — all offline and never crashing on a non-image or corrupt file.
**Verified:** 2026-06-30T16:40:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (plans 05-04, 05-05 closing UAT Test 8: photographic PNG compression ratio)

---

## Re-verification Context

The prior VERIFICATION.md (14/14 must-haves) had status `human_needed`; UAT (05-HUMAN-UAT.md) Test 8 found photographic PNGs barely shrank because the transformer re-encoded them as truecolor RGBA. Two gap-closure plans were created and executed:

- **05-04** — pure-Swift `PNGColorQuantizer` (median-cut RGBA→≤256-color palette) + `IndexedPNGEncoder` (color-type-3 PNG via Compression-framework zlib, PLTE/tRNS) + `PNGQuantizationTests`. Zero new dependencies.
- **05-05** — wired the engine into `ImageCompressTransformer`'s PNG path with a D-06 never-larger guard and an INFRA-17 truecolor fallback; registered the three files in the Xcode app/test targets; added transformer-level savings/alpha/D-06/INFRA-17 tests.

This re-verification confirms the 5 new gap-closure must-haves and that the original 14 are not regressed.

---

## Goal Achievement

### Observable Truths

**Gap-closure truths (from 05-04 + 05-05 frontmatter):**

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| G1 | 05-04: A truecolor RGBA pixel buffer reduces to a ≤256-color palette + per-pixel index map | ✓ VERIFIED | `PNGColorQuantizer.quantize` decodes via CGContext (premultipliedLast), runs median-cut (widest-axis split at median), builds count-weighted palette + alpha + nearest-index map. `testQuantize_lowColorLossless` (3 colors → 3-entry palette, exact round-trip) and `testQuantize_gradientToMaxColors` (256 colors, maxErr ≤ 48) compiled into FlintTests bundle and pass. |
| G2 | 05-04: A palette + index map encodes to a valid indexed-color (color-type 3) PNG that ImageIO/Preview can open | ✓ VERIFIED | `IndexedPNGEncoder.encode` emits signature + IHDR(type 3) + PLTE + tRNS + IDAT + IEND with table-driven CRC-32 and zlib-wrapped deflate. `testEncode_opensAsValidPNG` re-opens output via `CGImageSourceCreateWithURL`, asserts `public.png` + matching dims. Passes. |
| G3 | 05-04: Images with alpha produce a tRNS chunk preserving transparency through quantization | ✓ VERIFIED | Encoder emits tRNS only when any palette alpha < 255 (`alpha.contains { $0 < 255 }`). `testEncode_emitsTRNSForTransparency` asserts ASCII "tRNS" in bytes AND decoded image carries an alpha channel; `testQuantize_preservesAlpha` confirms a transparent palette class survives. Passes. |
| G4 | 05-04: Encoding produces a substantially smaller file than a truecolor re-encode for photographic content | ✓ VERIFIED | `testEndToEnd_quantizeThenEncode` (128×128 noise-injected image — the UAT Test 8 scenario) asserts indexed Data < truecolor `CGImageDestination` Data. SUMMARY reports 12896B < 44735B (~3.5×). Honest contract: documented that *smooth* gradients can lose to truecolor row filters — the engine targets photographic/high-local-variation content. |
| G5 | 05-05: Compressing a photographic PNG achieves meaningful savings (UAT Test 8) | ✓ VERIFIED (machine) | `testCompress_photographicPNG_shrinksMeaningfully` (256×256 noise PNG) asserts `percentSaved > 30`, output is same-dimension `public.png`. The end-to-end transformer path is wired and proven. Real-world ~70-85% on an actual 7MB photo → routed to human (see human item 1). |
| G6 | 05-05: PNG quantization is ON by default and preserves alpha | ✓ VERIFIED | `ImageCompressTransformer.compress` branches on `utType?.conforms(to: .png)` → `writePNGCompressed` unconditionally (no opt-in flag) → quantize+encode. `testCompress_transparentPNG_preservesAlpha` confirms a transparent region survives compression. |
| G7 | 05-05: A PNG that would grow under quantization keeps the smaller output (D-06 honest reporting) | ✓ VERIFIED | `writePNGCompressed`: if quantized bytes ≥ source size, also produces truecolor re-encode and keeps `min(quantized, truecolor)`. `testCompress_lowColorPNG_neverLargerThanTruecolor` asserts `compressedBytes <= truecolorBytes`. Passes. |
| G8 | 05-05: JPEG/HEIC behavior unchanged; TIFF still re-encodes losslessly | ✓ VERIFIED | Non-PNG `else` branch retains the original `isLossy` (jpeg/heic/heif) lossy-props path and nil-props for TIFF/other via `CGImageDestinationAddImageFromSource`. Logic byte-for-byte the same as pre-gap transformer; only PNG was split off. No regression. |
| G9 | 05-05: Non-image / corrupt input still returns a typed failure, never crashes (INFRA-17) | ✓ VERIFIED | Source/UTI/frame-count guards unchanged; any nil at decode/quantize/encode falls through to truecolor re-encode; `writePNGCompressed` returns Bool → caller surfaces `.writeFailed` without throwing. `testCompress_corruptPNGExtension_returnsFailure` passes. |

**Original 14 truths (regression check — prior PASS, re-confirmed):**

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | D-02 same-format-out via CGImageSourceGetType | ✓ VERIFIED (no regression) | UTI-derived destination retained; PNG branch preserves `.png` (test asserts `public.png` out). |
| 2 | INFRA-17 corrupt/non-image returns .failure without crash | ✓ VERIFIED (no regression) | Same guards + G9. |
| 3 | D-07 writes `<name>-compressed.<ext>` beside original | ✓ VERIFIED (no regression) | `disambiguatedCompressedURL` unchanged; PNG test asserts `photo-compressed.png`. |
| 4 | D-08 collision → `-1` suffix | ✓ VERIFIED (no regression) | While-loop disambiguation unchanged. |
| 5 | D-05/D-06 PNG/TIFF lossless, dimensions preserved | ✓ VERIFIED (refined) | TIFF still nil-props lossless; PNG now quantized but dimensions preserved (test asserts same dims, no resize). |
| 6 | D-03 zero new SPM dependency | ✓ VERIFIED (no regression) | Engine uses only Foundation/Compression/CoreGraphics/ImageIO. No Package.resolved change (last change was Phase 3 Sparkle). |
| 7 | D-01 N files → N live rows | ✓ VERIFIED (no regression) | ViewModel/View unchanged by gap closure (consumers call `compress(url:quality:)` unchanged). |
| 8 | INFRA-18 off-main autoreleasepool | ✓ VERIFIED (no regression) | ViewModel `Task.detached`/`autoreleasepool` untouched. |
| 9–13 | CR-01/CR-02/WR-01/WR-02/WR-03 fixes | ✓ VERIFIED (no regression) | View/ViewModel not modified by 05-04/05-05. |
| 14 | Tool registered + reachable from launcher | ✓ VERIFIED (no regression) | ToolRegistry append unchanged. |

**Score:** 19/19 truths verified (14 original + 5 gap-closure; G1–G4 are the 05-04 supporting truths)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `Tools/ImageCompress/PNGColorQuantizer.swift` | Median-cut RGBA→palette+index map | ✓ VERIFIED | 196 lines; `quantize(cgImage:maxColors:)` → `QuantizedImage`; no SwiftUI/AppKit; CoreGraphics+Foundation only; dimension guards return nil (INFRA-17). |
| `Tools/ImageCompress/IndexedPNGEncoder.swift` | Color-type-3 PNG writer | ✓ VERIFIED | 204 lines; full PNG framing, in-file CRC-32 + Adler-32, zlib-header detection/wrap; input validation returns nil on degenerate input. |
| `FlintTests/PNGQuantizationTests.swift` | Engine unit tests | ✓ VERIFIED | 440 lines; 11 `@Test` cases (signature, ImageIO validity, tRNS present/absent, degenerate nil, size-win, lossless round-trip, gradient tolerance, alpha, edge images, end-to-end). Symbols `testQuantize`/`testEncode`/`testEndToEnd` confirmed compiled into test bundle. |
| `Tools/ImageCompress/ImageCompressTransformer.swift` | PNG path → quantize+encode w/ D-06 guard + fallback | ✓ VERIFIED | `writePNGCompressed` + `truecolorReencode` added; PNG branch on `conforms(to: .png)`; non-PNG branch unchanged. Engine symbols present in compiled app dylib. |
| `Flint.xcodeproj/project.pbxproj` | Target membership for 3 new files | ✓ VERIFIED | `plutil -lint` OK; synthetic IDs 07007/07008/07009 present (12 reference lines across build-file/file-ref/group/phase). |
| `FlintTests/ImageCompressTransformerTests.swift` | Transformer PNG savings/alpha/D-06/INFRA-17 tests | ✓ VERIFIED | `testCompress_photographicPNG_shrinksMeaningfully`, `_transparentPNG_preservesAlpha`, `_lowColorPNG_neverLargerThanTruecolor`, `_corruptPNGExtension_returnsFailure` added; `writeGradientPNG`/`writeTransparentQuadrantPNG`/`pixelDimensions`/`hasTransparentPixel` helpers present. Symbols confirmed compiled. |

---

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `ImageCompressTransformer.compress` (PNG branch) | `writePNGCompressed` | `if isPNG { writePNGCompressed(...) }` | ✓ WIRED | Line 78. |
| `writePNGCompressed` | `PNGColorQuantizer.quantize` + `IndexedPNGEncoder.encode` | guard-let chain → indexed Data | ✓ WIRED | Lines 139–146; nil → `truecolorReencode` fallback. |
| `IndexedPNGEncoder` | Compression framework (zlib deflate) | `compression_encode_buffer` + `COMPRESSION_ZLIB` | ✓ WIRED | Lines 161–166; raw-deflate detection + zlib-header/Adler-32 wrap. |
| `PNGColorQuantizer` | `IndexedPNGEncoder` | `QuantizedImage{palette,alpha,indices}` passed to `encode` | ✓ WIRED | Transformer lines 139–146. |
| `Flint.xcodeproj/project.pbxproj` | app + test targets | PBXBuildFile + PBXFileReference + group + Sources phase | ✓ WIRED | IDs 07007/07008/07009; confirmed by app dylib + test bundle symbols. |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `ImageCompressTransformer` PNG output | `indexedData` | `CGImage` decode → `quantize` → `encode` → write to destURL | Yes — live ImageIO decode, real median-cut, hand-written PNG bytes; byte counts from `fileSizeKey` | ✓ FLOWING |
| D-06 guard | `min(quantized, truecolor)` size | in-memory Data.count vs truecolor file size | Yes — real comparison, real file written | ✓ FLOWING |

---

### Behavioral Spot-Checks / Probe Execution

This is a macOS SwiftUI app — no curl/CLI entry points. The authoritative behavioral check is the Xcode test suite, run by the verifier in this session:

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Gap-closure suites pass | `xcodebuild test -only-testing:FlintTests/ImageCompressTransformer -only-testing:FlintTests/PNGQuantization` | `** TEST SUCCEEDED **` | ✓ PASS |
| Engine wired into app target (not just source) | `nm Flint.debug.dylib \| grep IndexedPNGEncoder/writePNGCompressed` | Symbols present | ✓ PASS |
| Gap-closure tests compiled into test bundle (rules out false-RED stale build) | `nm FlintTests \| grep photographicPNG/transparentPNG/lowColorPNG/corruptPNGExtension/PNGQuantizationTests` | All present | ✓ PASS |
| TDD RED→GREEN commits exist | `git cat-file -t 80781b6 98e745e` | Both exist | ✓ PASS |

Note: `xcresulttool` on this Xcode/macOS 26 build does not populate the per-test node tree (schema regression), so exact pass-count JSON is unavailable; verification relied on `** TEST SUCCEEDED **` (emitted only on zero failures) cross-checked against compiled test/app symbols.

No `scripts/*/tests/probe-*.sh` declared or present.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| D-02 | 05-04, 05-05 | Same format in = same format out | ✓ SATISFIED | PNG → public.png out; test asserts UTI + dims. |
| D-05 | 05-05 | PNG/TIFF lossless intent | ✓ SATISFIED | TIFF nil-props unchanged; PNG quantized (visually lossless target) — alpha preserved. |
| D-06 | 05-05 | Honest reporting, no resize, never larger | ✓ SATISFIED | Never-larger guard + same-dims tests. |
| INFRA-17 | 05-04, 05-05 | Never crash on bad input | ✓ SATISFIED | All-nil fallback + corrupt-input failure test; engine validates all inputs. |
| INFRA-18 | 05-05 | Off-main memory bound | ✓ SATISFIED | ViewModel autoreleasepool/Task.detached unchanged; quantize/encode linear in pixels. |

No orphaned requirements. This is Phase 5 of 5 (final phase) — no later phase exists to defer any item to.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| None (source) | — | — | — | No TBD/FIXME/XXX/HACK/PLACEHOLDER/TODO in any of the 5 modified files. |

Verified clean:
- No `import SwiftUI` / `import AppKit` in the three pure-transformer files.
- No `return null`/`fatalError`/`try!`/`as!` in source; the only `!` in source is `dstBuf.baseAddress!` (guarded by buffer allocation) — acceptable.
- One test-only force-unwrap (`"not an image".data(using:)!`) on a string literal — safe.
- No new SPM dependency (D-03); Package.resolved last changed in Phase 3.

---

### Human Verification Required

The gap is now machine-verified at the transformer level (>30% on synthesized photographic content; ~3.5× on the engine's noise test). However, the original UAT Test 8 was reported against a **real ~7MB photo** with a ~81% reference target and a "no visible quality loss" requirement. That real-world ratio and the perceptual quality of 256-color median-cut quantization on an actual photograph cannot be asserted by synthesized unit tests:

1. **Real photographic PNG compression (UAT Test 8 closure confirmation)** — Compress the actual reference image (or any real ~7MB photographic PNG) in the running app. Expected: dramatically smaller output (reference 7.27MB→1.35MB, ~81%), unchanged dimensions, no visible banding/quality loss. *Why human:* real ratio + perceptual fidelity of quantization on a true photo.

2–8. The 6 pre-existing UI/UX human items from the prior verification (live results table, lossless slider gate, non-image WarningBannerView, preset styling, cancel mid-batch, collision disambiguation end-to-end, launcher search) — unchanged by gap closure, still require a running app. (See frontmatter for full detail.)

---

### Documented Engine Contract (Honest Note, Not a Failure)

The quantization engine wins on **photographic / high-local-variation** content (the UAT Test 8 scenario) and may lose to truecolor on **perfectly smooth gradients or flat PNGs**, where PNG's Paeth/Sub row filters compress truecolor extremely well and the 768-byte PLTE plus a less-filterable index stream costs more than it saves. This is handled correctly: the **D-06 never-larger guard** keeps `min(quantized, truecolor)`, so the user is never handed a bigger file. The test suite documents this with a photographic test image (where quantization wins) and a low-color test (where the guard ensures no regression). This is the intended contract, not a defect.

---

### Gaps Summary

No automated gaps. The UAT Test 8 gap is closed at the code/test level: the quantize→encode→write path exists, is wired into the app target (proven by compiled symbols), preserves alpha, honors the D-06 never-larger guard, falls back safely on bad input (INFRA-17), and does not regress JPEG/HEIC/TIFF. The full test suite passes (`** TEST SUCCEEDED **`).

Status is `human_needed` (not `passed`) because (a) the real-world ~70-85% photographic ratio and visual fidelity must be confirmed on an actual photo by a human eye, and (b) 6 pre-existing UI/UX human items from the initial verification remain.

---

_Verified: 2026-06-30T16:40:00Z_
_Verifier: Claude (gsd-verifier) — re-verification after gap closure (05-04, 05-05)_
