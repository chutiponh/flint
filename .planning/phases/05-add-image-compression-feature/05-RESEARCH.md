# Phase 5: add-image-compression-feature - Research

**Researched:** 2026-06-30
**Domain:** macOS native image re-encoding (ImageIO / CoreGraphics), batch off-main file processing, first-ever filesystem-write tool
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Batch input — accept one OR many images dropped at once (reuse the file-drop pipeline pattern from Hash: `.onDrop(of: [.fileURL])`).
- **D-02:** Formats = whatever ImageIO encodes natively: **PNG, JPEG, HEIC, TIFF**. Same format in = same format out (compress-only, no conversion).
- **D-03:** **WebP dropped.** Avoids bundling libwebp (C dependency) — keeps the tool zero-new-dep.
- **D-04:** **Quality slider + presets.** A 0–100% quality slider, plus preset buttons (e.g. Web / Email / Max) that set the slider; slider stays adjustable after a preset.
- **D-05:** Quality maps to ImageIO `kCGImageDestinationLossyCompressionQuality` for JPEG/HEIC. PNG is lossless — quality slider doesn't apply; PNG just re-encodes (best-effort optimization). Make this distinction visible in the UI.
- **D-06:** **Quality only — no resize.** Original pixel dimensions preserved. Resizing/downscaling out of scope.
- **D-07:** Write each compressed file **beside the original** with a `-compressed` suffix (e.g. `photo.jpg` → `photo-compressed.jpg`). No save dialogs for the batch.
- **D-08:** **Never overwrite the original.** If a `-compressed` file already exists, disambiguate (numeric suffix) rather than clobbering. App is non-sandboxed — writing beside the source is permitted; no security-scoped bookmark needed for v1.
- **D-09:** **Results table with savings** — one row per image: thumbnail, original size → new size, % saved. Live per-row progress as each finishes.
- **D-10:** No side-by-side visual before/after comparison in this phase.

### Claude's Discretion

- Exact preset names and their quality values (Web/Email/Max are suggestions).
- Thumbnail size, table layout/column order, progress-indicator style.
- Whether a single dropped file shows the same table (1 row) or a simpler view — table is the baseline.
- Off-main-thread encoding strategy (mirror Hash's `Task` + progress-callback pipeline).

### Deferred Ideas (OUT OF SCOPE)

- **Format conversion** (PNG→JPEG, anything→WebP) — separate future feature; WebP rides along with it.
- **Image resizing / downscaling** — out of "compress" scope; candidate for its own phase.
- **Target-file-size mode** (binary-search quality to hit e.g. 500 KB) — deferred for simpler slider+presets.
- **Side-by-side visual before/after preview** — deferred.
- **Choose-output-folder / Save-As / overwrite modes** — "beside original with suffix" chosen for v1.
</user_constraints>

## Summary

Phase 5 adds an **Image Compressor** tool that is structurally a near-clone of the existing **Hash** tool (drop file(s) → off-main `Task` → per-item progress → result), with one genuinely net-new capability: **writing files to disk**. Every existing tool outputs to clipboard/history only; this is the first that produces files. The CONTEXT.md decisions resolve all product-level ambiguity, so research focuses on the seven uncertain technical mechanics.

The core compression mechanism is a **CGImageSource → CGImageDestination round-trip via `CGImageDestinationAddImageFromSource`**. This single API call is the linchpin: it re-encodes the image while **automatically carrying forward EXIF, ICC profile, and orientation** from the source, and it lets you override compression via a properties dictionary containing `kCGImageDestinationLossyCompressionQuality` (a Float in 0.0–1.0). Critically, you obtain the output format by calling `CGImageSourceGetType()` on the source and passing that exact UTI to `CGImageDestinationCreateWithURL` — this guarantees "same format in = same format out" (D-02) with zero format-mapping logic. `AddImageFromSource` (not `AddImage`) is the correct choice precisely because it preserves metadata and orientation, avoiding the classic "re-encoded photo is rotated 90°" bug.

Robustness (the never-crash guarantee, INFRA-17) comes free from ImageIO's design: `CGImageSourceCreateWithURL` returns an **optional** (nil for non-images / unreadable files), `CGImageSourceGetType` returns nil for undecodable data, and `CGImageDestinationFinalize` returns a Bool. A `guard let` chain over these three call sites makes corrupt/truncated/non-image input a graceful warning, never a throw or crash. **Zero new dependencies** — ImageIO, CoreGraphics, and UniformTypeIdentifiers are all system frameworks, keeping the <20MB bundle target and offline guarantee intact (D-03).

**Primary recommendation:** Build `Tools/ImageCompress/` as the standard 4-file tool (Definition + Transformer + ViewModel + View). Put all ImageIO logic in a pure, testable `ImageCompressTransformer` that takes a source URL + quality and returns a result struct or a typed failure (never throws across the UI boundary). Re-encode via `CGImageDestinationAddImageFromSource` using `CGImageSourceGetType()` as the output UTI. Mirror `HashViewModel`'s `Task` + progress-callback + cancellation shape for the batch loop, wrapping each image in an `autoreleasepool` to bound memory on large batches. Add a `-compressed` filename disambiguation helper and write atomically.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Image decode + re-encode (ImageIO) | Transformer (pure logic) | — | Must be unit-testable on bad input; no UI/AppKit imports (mirrors HashTransformer) |
| Format detection (same-in-same-out) | Transformer | — | `CGImageSourceGetType()` read inside the encode function |
| Output path disambiguation (`-compressed`) | Transformer (pure FS-path math) | ViewModel (triggers write) | Path computation is pure and testable; the actual write is an I/O side effect |
| Atomic file write to disk | Transformer/encode fn | — | `CGImageDestinationFinalize` writes directly to the destination URL |
| Batch loop + per-item progress + cancellation | ViewModel (`@MainActor @Observable`) | Transformer (per-image work) | Mirrors `HashViewModel.startFileHash` off-main `Task` shape |
| Drop surface + results table + quality controls | View (SwiftUI) | — | Reuses `DropOverlayView`, `WarningBannerView` |
| Registration | `ImageCompressDefinition.make()` → `ToolRegistry` append | — | Same pattern as the 5 Phase-2 sanctioned appends |
| History recording | ViewModel via injected `onSaveHistory` closure | — | Same `@Environment(HistoryStore.self)` wrapper pattern as `HashDefinition` |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ImageIO | macOS 14 SDK (system) | `CGImageSource*` / `CGImageDestination*` decode + re-encode | The native, zero-dep image codec layer; supports PNG/JPEG/HEIC/TIFF encode out of the box `[CITED: developer.apple.com/documentation/imageio]` |
| CoreGraphics | macOS 14 SDK (system) | `CGImage`, `CGImagePropertyOrientation` types | Backing types for ImageIO; already linked transitively `[CITED: developer.apple.com/documentation/imageio/cgimagepropertyorientation]` |
| UniformTypeIdentifiers | macOS 14 SDK (system) | `UTType.fileURL` (drop), `.heic`/`.jpeg`/`.png`/`.tiff` identifiers, thumbnail typing | Already used by `HashView` for `.onDrop(of: [.fileURL])` `[VERIFIED: codebase grep HashView.swift line 7,45]` |
| AppKit (`NSImage`) | macOS 14 SDK (system) | Thumbnail rendering in the results table (D-09) | Native; `NSImage(contentsOf:)` or a small CGImageSource thumbnail is sufficient `[ASSUMED]` |
| Foundation (`FileManager`) | macOS 14 SDK (system) | Original/compressed file size, collision check for disambiguation | `attributesOfItem(atPath:)[.size]` already used in `HashTransformer.hashFile` `[VERIFIED: codebase grep HashTransformer.swift line 79]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ImageIO` thumbnail API (`kCGImageSourceCreateThumbnailFromImageAlways`) | system | Fast, memory-cheap thumbnails without decoding full image | If `NSImage(contentsOf:)` full-decode is too heavy for the table on large batches `[ASSUMED]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CGImageDestinationAddImageFromSource` | `CGImageDestinationAddImage(CGImage)` | `AddImage` **drops all metadata** unless you re-supply every property — causes orientation-loss bug (re-encoded photo rotates). `AddImageFromSource` carries metadata forward automatically. Use `AddImageFromSource`. `[CITED: developer.apple.com/forums/thread/769659]` |
| `CGImageDestinationAddImageFromSource` (re-encode) | `CGImageDestinationCopyImageSource` (lossless container copy) | `CopyImageSource` does NOT re-compress — it preserves original pixel data identically, so it cannot reduce file size by quality. Wrong tool for "compress". Use only if a future "strip-metadata-only" feature is added. `[VERIFIED: WebSearch Medium ImageIO article]` |
| ImageIO native formats | bundling libwebp / libavif for WebP/AVIF | Adds a C dependency, grows bundle past target, breaks zero-new-dep stance. Explicitly dropped in D-03. |
| `NSBitmapImageRep.representation(using:)` | — | Higher-level AppKit path; loses metadata/orientation fidelity and gives less control over the exact output UTI than the ImageIO destination API. ImageIO is the correct lower-level tool. `[ASSUMED]` |

**Installation:** None. All frameworks are part of the macOS 14 SDK. Add `import ImageIO`, `import CoreGraphics`, `import UniformTypeIdentifiers` (and `import AppKit` for thumbnails). No SPM changes, no `project.pbxproj` package edits.

## Package Legitimacy Audit

**Not applicable.** This phase installs **zero external packages**. All functionality is provided by system frameworks (ImageIO, CoreGraphics, UniformTypeIdentifiers, AppKit, Foundation) that ship with macOS and are already linked by the existing app target. No registry lookup, slopcheck, or postinstall audit is required.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                ┌─────────────────────────────────────────────┐
  drop N image  │  ImageCompressView (SwiftUI)                 │
  files  ──────▶│  .onDrop(of: [.fileURL])  ◀── DropOverlayView│
                │  quality slider + presets (D-04)             │
                │  results table (thumbnail, sizes, % saved)   │
                └───────────────┬─────────────────────────────┘
                                │ array of URLs + quality
                                ▼
                ┌─────────────────────────────────────────────┐
                │  ImageCompressViewModel (@MainActor)         │
                │  Task { for each url:  (off-main)            │
                │     autoreleasepool { compress → progress }  │
                │  }   cancellation via Task.isCancelled       │
                └───────────────┬─────────────────────────────┘
                                │ url, quality, progressHandler
                                ▼
                ┌─────────────────────────────────────────────┐
                │  ImageCompressTransformer (pure, testable)   │
                │                                              │
                │  1. CGImageSourceCreateWithURL(url) ─┐       │
                │       guard let else → .notAnImage    │ nil  │
                │  2. CGImageSourceGetType(src) ────────┤ on    │
                │       guard let uti else → .unsupported  bad  │
                │  3. destURL = disambiguate(            │ input │
                │       "<name>-compressed.<ext>")  ◀───┘       │
                │  4. CGImageDestinationCreateWithURL(           │
                │        destURL, uti, 1, nil)                  │
                │  5. props = uti is lossy?                     │
                │        [kCGImageDestination...Quality: q]     │
                │        : nil   (PNG/TIFF → nil, D-05)         │
                │  6. AddImageFromSource(dst, src, 0, props)    │
                │        ↑ carries EXIF/ICC/orientation         │
                │  7. CGImageDestinationFinalize(dst)           │
                │        guard true else → .writeFailed         │
                │  8. read origSize vs newSize → % saved        │
                └───────────────┬─────────────────────────────┘
                                │ Result<CompressedImage, CompressError>
                                ▼
                       writes <name>-compressed.<ext> beside original
                       returns row data (sizes, % saved, dest path)
```

File-to-component mapping is in the Component Responsibilities below, not the diagram.

### Recommended Project Structure

```
Tools/ImageCompress/
├── ImageCompressDefinition.swift    # ToolDefinition.make() — detectionPredicate: nil (no clipboard detect)
├── ImageCompressTransformer.swift   # PURE: CGImageSource→CGImageDestination, path disambiguation, sizes
├── ImageCompressViewModel.swift     # @MainActor @Observable: batch Task, per-row progress, cancellation
└── ImageCompressView.swift          # drop surface, quality slider+presets, results table
```

(Mirrors `Tools/Hash/` 4-file layout exactly — Definition + Transformer + ViewModel + View.)

### Pattern 1: Same-format round-trip re-encode (the core mechanism)

**What:** Decode the source, read its UTI, write the same UTI back with a quality override. Metadata/orientation carries automatically.
**When to use:** Every compress operation.
**Example:**
```swift
// Source: developer.apple.com/documentation/imageio + forums/thread/769659 [CITED]
import ImageIO
import UniformTypeIdentifiers

enum CompressError: Error { case notAnImage, unsupportedType, writeFailed }

struct CompressedImage {
    let destURL: URL
    let originalBytes: Int
    let compressedBytes: Int
    var percentSaved: Double {
        guard originalBytes > 0 else { return 0 }
        return (1.0 - Double(compressedBytes) / Double(originalBytes)) * 100
    }
}

/// Pure: no UI imports. Returns a typed Result — NEVER throws across the UI boundary (INFRA-17).
static func compress(url: URL, quality: Double) -> Result<CompressedImage, CompressError> {
    // 1. Decodable-image gate (corrupt/non-image → graceful failure, not crash)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        return .failure(.notAnImage)
    }
    // 2. Read the SOURCE format → guarantees same-format-out (D-02). nil = undecodable.
    guard let uti = CGImageSourceGetType(src) else {
        return .failure(.unsupportedType)
    }
    guard CGImageSourceGetCount(src) > 0 else { return .failure(.notAnImage) }

    // 3. Collision-safe destination path beside the original (D-07/D-08)
    let destURL = disambiguatedCompressedURL(for: url)

    // 4. Destination uses the SOURCE's UTI — no format mapping needed
    guard let dst = CGImageDestinationCreateWithURL(destURL as CFURL, uti, 1, nil) else {
        return .failure(.writeFailed)
    }

    // 5. Quality only applies to lossy formats (JPEG/HEIC). PNG/TIFF → nil props (D-05).
    let utType = UTType(uti as String)
    let isLossy = utType == .jpeg || utType == .heic || utType == UTType("public.heif")
    let props: CFDictionary? = isLossy
        ? [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary  // 0.0–1.0
        : nil

    // 6. AddImageFromSource (NOT AddImage) → carries EXIF, ICC profile, orientation forward.
    //    Prevents the "re-encoded photo rotated 90°" bug.
    CGImageDestinationAddImageFromSource(dst, src, 0, props)

    // 7. Finalize returns false on failure — gate it, never assume success (INFRA-17)
    guard CGImageDestinationFinalize(dst) else {
        try? FileManager.default.removeItem(at: destURL) // clean up partial write
        return .failure(.writeFailed)
    }

    // 8. Size delta for the hero "% saved" metric
    let origBytes  = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    let newBytes   = (try? destURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    return .success(CompressedImage(destURL: destURL,
                                    originalBytes: origBytes,
                                    compressedBytes: newBytes))
}
```
> The quality value passed must be a Swift `Double`/`Float` in **0.0–1.0**; map the 0–100 UI slider as `slider / 100.0`. `[CITED: developer.apple.com/documentation/imageio/kcgimagedestinationlossycompressionquality]`

### Pattern 2: `-compressed` filename disambiguation (D-08, net-new — no prior pattern)

**What:** Compute a destination that never overwrites anything: `photo.jpg → photo-compressed.jpg`, and if that exists, `photo-compressed-1.jpg`, `-2`, etc.
**When to use:** Every write. This is the only collision-safety guard.
**Example:**
```swift
// Pure path math — fully unit-testable without touching disk for the base case.
static func disambiguatedCompressedURL(for original: URL) -> URL {
    let dir  = original.deletingLastPathComponent()
    let ext  = original.pathExtension                    // preserve original extension (D-02)
    let stem = original.deletingPathExtension().lastPathComponent
    let fm   = FileManager.default

    func candidate(_ suffix: String) -> URL {
        dir.appendingPathComponent("\(stem)-compressed\(suffix)")
           .appendingPathExtension(ext)
    }
    var url = candidate("")
    var n = 1
    while fm.fileExists(atPath: url.path) {              // never clobber (D-08)
        url = candidate("-\(n)")
        n += 1
    }
    return url
}
```
> Note: a tiny TOCTOU window exists between `fileExists` and the write. For a single-user desktop tool writing into the user's own folder this is acceptable; `CGImageDestinationFinalize` will overwrite if the path was created in between, so the disambiguation is best-effort collision avoidance, not a hard lock. Flag in plan if stricter atomicity is desired (write to temp + `FileManager.moveItem` with a unique name). `[ASSUMED]`

### Pattern 3: Batch off-main loop with per-row progress + cancellation (mirror HashViewModel)

**What:** Same `Task` + progress-callback + `Task.isCancelled` shape as `HashViewModel.startFileHash`, but looping over N images and wrapping each in `autoreleasepool` to bound peak memory.
**When to use:** The ViewModel's compress entry point.
**Example:**
```swift
// Source: codebase Tools/Hash/HashViewModel.swift lines 105-136 [VERIFIED] — same shape
@MainActor @Observable
final class ImageCompressViewModel {
    var rows: [CompressRow] = []          // one per dropped image; drives the table (D-09)
    var isCompressing = false
    private var task: Task<Void, Never>?

    func compress(urls: [URL], quality: Double) {
        task?.cancel()
        rows = urls.map { CompressRow(sourceURL: $0, state: .pending) }
        isCompressing = true

        task = Task.detached(priority: .userInitiated) { [weak self, rows = self.rows] in
            for (i, row) in rows.enumerated() {
                if Task.isCancelled { break }
                // autoreleasepool bounds CGImage memory across a large batch (pitfall #5)
                let result = autoreleasepool {
                    ImageCompressTransformer.compress(url: row.sourceURL, quality: quality)
                }
                await MainActor.run { [weak self] in
                    self?.rows[i].apply(result)          // live per-row update (D-09)
                }
            }
            await MainActor.run { [weak self] in self?.isCompressing = false }
        }
    }

    func cancel() { task?.cancel(); task = nil; isCompressing = false }
}
```
> `CompressRow` carries `sourceURL`, a lazily-loaded thumbnail, `originalBytes`, `compressedBytes`, `percentSaved`, and a `state` (`.pending`/`.done`/`.failed(reason)`). Failed rows render a `WarningBannerView`-style inline message rather than throwing (INFRA-17).

### Anti-Patterns to Avoid

- **`CGImageDestinationAddImage(cgImage, props)` for compression:** drops EXIF/ICC/orientation → re-encoded photos appear rotated and lose color profile. Use `AddImageFromSource`. `[CITED: developer.apple.com/forums/thread/769659]`
- **Hardcoding the output UTI** (e.g. always `.jpeg`): breaks same-format-out (D-02). Always derive from `CGImageSourceGetType(src)`.
- **Applying the quality dictionary to PNG/TIFF:** harmless but misleading — PNG is lossless, the key is ignored. Pass `nil` props for non-lossy formats and reflect this in the UI (D-05). `[CITED: kCGImageDestinationLossyCompressionQuality docs]`
- **`Data(contentsOf:)` to read the whole image into memory for sizing:** unnecessary — use `url.resourceValues(forKeys: [.fileSizeKey])` for the byte count (no decode). Mirrors the lesson already encoded in `HashTransformer` (pitfall #9, never `Data(contentsOf:)` for large files).
- **Force-unwrapping any ImageIO call:** every `CGImageSourceCreateWithURL` / `CGImageSourceGetType` / `CGImageDestinationCreateWithURL` can return nil/false on bad input. Force-unwrap = crash on corrupt file = INFRA-17 violation.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Re-encoding at a quality | Custom JPEG/PNG encoder | `CGImageDestination` + `kCGImageDestinationLossyCompressionQuality` | System codecs are correct, fast, hardware-accelerated where available |
| Preserving EXIF/orientation/ICC | Manual metadata copy dictionary | `CGImageDestinationAddImageFromSource` | One call carries all source metadata forward; manual copy is error-prone and loses fields |
| Detecting "is this a real image" | Magic-byte sniffing / extension check | `CGImageSourceCreateWithURL` returning nil + `CGImageSourceGetType` nil | ImageIO already validates decodability; extension-checks lie (e.g. `.jpg` that's actually PNG) |
| Output format selection | Extension-to-format mapping table | `CGImageSourceGetType(src)` UTI fed to destination | Same-format guarantee with zero mapping; handles `.jpg`/`.jpeg`/`.JPEG` uniformly |
| Reading file sizes | `Data(contentsOf:).count` (full decode/read) | `url.resourceValues(forKeys: [.fileSizeKey])` | No bytes read into memory; instant |
| Thumbnails | Full `NSImage` decode + manual downscale | `NSImage(contentsOf:)` for small batches, or `kCGImageSourceCreateThumbnailFromImageAlways` for memory-cheap thumbnails | ImageIO thumbnail API decodes only what's needed |

**Key insight:** ImageIO is purpose-built for exactly this round-trip. The entire compress operation is ~10 lines of glue over system APIs. Any "custom" image handling here is a bug source, a performance regression, and a metadata-loss risk.

## Runtime State Inventory

> This is a greenfield feature (a new tool), not a rename/refactor/migration. No existing stored data, service config, OS-registered state, secrets, or build artifacts reference anything this phase renames — because it renames nothing.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — new tool writes to user-chosen folders only; no DB schema change. History uses the existing `HistoryEntry`/`HistoryStore` via injected closure (same as Hash). | none |
| Live service config | None — fully offline, no external service. | none |
| OS-registered state | None — no new entitlements, no login items, no Services menu entry, no Task Scheduler analog. Tool registers only in-process via `ToolRegistry`. | none |
| Secrets/env vars | None — no keys, no HMAC, no secrets path (unlike Hash/JWT). | none |
| Build artifacts | New `.swift` files must be added to the Xcode target (`project.pbxproj`). The 4 new files in `Tools/ImageCompress/` need target membership — confirm Xcode adds them, OR follow whatever the project's file-add convention is (Phase 2 tools were added without manual pbxproj surgery via `ToolRegistry` append, but new *files* still need target membership). | Verify target membership at plan time |

**Verified by:** grep of `Tools/`, `Core/` for ImageIO/CGImage usage (none found — greenfield); read of `HashDefinition`, `ToolRegistry` (registration is an append, not a schema change).

## Common Pitfalls

### Pitfall 1: Re-encoded photo appears rotated (orientation loss)
**What goes wrong:** A JPEG/HEIC with an EXIF orientation flag (every phone photo) re-encodes upside-down or sideways.
**Why it happens:** `CGImageDestinationAddImage(CGImage, ...)` writes only the raw pixel buffer and drops the EXIF orientation tag; viewers then render the un-rotated buffer.
**How to avoid:** Use `CGImageDestinationAddImageFromSource(dst, src, 0, props)` — it carries the orientation tag (and all EXIF/ICC) forward unchanged. `[CITED: developer.apple.com/forums/thread/769659]`
**Warning signs:** Test photo (taken in portrait on a phone) comes out landscape after compression.

### Pitfall 2: PNG "compression" appears to do nothing / confuses the user
**What goes wrong:** User drags the quality slider on a PNG and the file size barely changes or grows.
**Why it happens:** PNG is lossless — `kCGImageDestinationLossyCompressionQuality` is ignored for PNG. ImageIO re-encodes (best-effort optimization) but cannot trade quality for size. A re-encoded PNG can even be *larger* if the original used a more aggressive PNG optimizer.
**How to avoid:** Per D-05, detect lossless formats (PNG/TIFF) and (a) pass `nil` props, (b) **disable or grey the slider** with a label like "PNG is lossless — re-encoded, quality not applicable." Show the real before/after size honestly, including the "grew slightly" case.
**Warning signs:** Negative "% saved" on PNG/TIFF rows. Surface this neutrally, not as an error.

### Pitfall 3: Crash / hang on corrupt, truncated, or non-image dropped file
**What goes wrong:** A `.txt` renamed to `.jpg`, a 0-byte file, or a truncated download crashes a force-unwrap or hangs decode.
**Why it happens:** Force-unwrapping `CGImageSourceCreateWithURL`'s optional, or assuming `Finalize` succeeded.
**How to avoid:** `guard let` over `CGImageSourceCreateWithURL` (nil → `.notAnImage`), over `CGImageSourceGetType` (nil → `.unsupportedType`), and `guard CGImageDestinationFinalize(dst)` (false → `.writeFailed`). Surface each as a per-row warning (INFRA-17). `[CITED: developer.apple.com/documentation/imageio/cgimagesourcecreatewithurl]`
**Warning signs:** Any `!` near an ImageIO call in review.

### Pitfall 4: Peak memory blowup on a large batch
**What goes wrong:** Dropping 50 high-res images decodes them faster than they free, RAM spikes past the <100MB target (INFRA-18).
**Why it happens:** `CGImage` decode buffers accumulate in an autorelease pool that doesn't drain until the loop yields.
**How to avoid:** Wrap each per-image compress in `autoreleasepool { ... }` inside the batch loop so each image's buffers free before the next decodes. Process sequentially (or bounded concurrency), not all-at-once. `[ASSUMED]`
**Warning signs:** RAM grows monotonically with batch size during Instruments allocation trace.

### Pitfall 5: AddImageFromSource silently re-injects metadata you meant to strip
**What goes wrong:** (Future-proofing note.) If a later "strip EXIF/GPS" option is added, `AddImageFromSource` will faithfully carry the GPS/EXIF forward — defeating the strip.
**Why it happens:** `AddImageFromSource` is designed to preserve metadata; it is the *wrong* call for removal.
**How to avoid:** Not relevant to this phase (compress preserves metadata by design), but document: a future strip feature must use `AddImage(CGImage, explicitProps)` and rebuild only the wanted properties. `[VERIFIED: WebSearch Medium "iOS ImageIO Restores Metadata You Thought Was Deleted"]`
**Warning signs:** N/A this phase — listed so the planner doesn't accidentally request strip-on-compress.

### Pitfall 6: HEIC encode availability assumption
**What goes wrong:** Assuming HEIC encode works everywhere.
**Why it happens:** HEIC *encoding* (HEVC) historically had limits on very old macOS, and on hardware without HEVC encode support `CGImageDestinationFinalize` can return false.
**How to avoid:** macOS 14 (the minimum target) supports HEIC encode on all supported Macs `[CITED: developer.apple.com WWDC17 511 — HEIC is the supported HEIF encode form]`. The `guard CGImageDestinationFinalize` already handles the rare failure gracefully — surface a per-row warning, don't crash. Note: HEIC is **never** truly lossless even at quality 1.0. `[CITED: developer.apple.com/forums/thread/670094]`
**Warning signs:** HEIC rows fail `Finalize` on specific machines — already handled by the Bool gate.

## Code Examples

### Mapping the 0–100 UI slider to ImageIO quality
```swift
// D-04/D-05: slider is 0–100; kCGImageDestinationLossyCompressionQuality wants 0.0–1.0
let quality = Double(sliderValue) / 100.0   // e.g. 80 → 0.80
// Suggested presets (Claude's discretion per CONTEXT.md):
//   Web   = 60  (0.60)   smaller, fine for screens
//   Email = 75  (0.75)   balanced
//   Max   = 95  (0.95)   near-lossless lossy
```
> Source: kCGImageDestinationLossyCompressionQuality accepts 0.0–1.0. `[CITED: developer.apple.com/documentation/imageio/kcgimagedestinationlossycompressionquality]`

### Detecting lossy-vs-lossless to gate the slider (D-05)
```swift
import UniformTypeIdentifiers
func isLossy(uti: CFString) -> Bool {
    guard let t = UTType(uti as String) else { return false }
    return t.conforms(to: .jpeg) || t.conforms(to: .heic) || t.conforms(to: UTType("public.heif")!)
    // PNG (.png), TIFF (.tiff) → false → slider disabled, nil props
}
```
> `[ASSUMED]` — verify `UTType("public.heif")` non-nil at build; `.heic` is a standard system UTType. `[CITED: developer.apple.com/documentation/uniformtypeidentifiers/uttype/3566236-heic]`

### Drop handling for multiple files (D-01) — extend the Hash pattern
```swift
// HashView accepts the FIRST provider only (single-file). For batch, iterate ALL providers.
// Source: codebase HashView.swift lines 45-55 [VERIFIED] — adapted for multi-file
.onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
    var urls: [URL] = []
    let group = DispatchGroup()
    for provider in providers {
        group.enter()
        _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            defer { group.leave() }
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                urls.append(url)
            }
        }
    }
    group.notify(queue: .main) {
        Task { @MainActor in viewModel.compress(urls: urls, quality: currentQuality) }
    }
    return true
}
```
> Note: `HashView` only reads `providers.first` (single file). Batch (D-01) requires iterating all providers and joining their async loads — the snippet above shows the minimal change. `[VERIFIED: codebase HashView.swift]`

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `altool` for notarization | `notarytool` | Nov 2023 | Not this phase, but already handled project-wide |
| `NSBitmapImageRep` representation | `CGImageDestination` ImageIO API | long stable | Lower-level control, metadata fidelity, exact UTI |
| `kUTTypeJPEG`/`kUTTypeHEIC` CoreServices constants | `UTType.jpeg` / `UTType.heic` (UniformTypeIdentifiers, macOS 11+) | macOS 11+ | Use the modern `UTType` API, not the deprecated `kUTType*` constants |

**Deprecated/outdated:**
- `kUTType*` string constants (CoreServices): superseded by `UTType` (UniformTypeIdentifiers) since macOS 11. Use `UTType.heic.identifier` etc. The app already targets macOS 14, so the modern API is always available.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSImage(contentsOf:)` is adequate for thumbnails on typical batches; switch to `kCGImageSourceCreateThumbnailFromImageAlways` only if memory-pressured | Standard Stack / Don't Hand-Roll | Low — both work; thumbnail approach is an optimization, not correctness |
| A2 | `autoreleasepool` per-image in the batch loop sufficiently bounds memory for the <100MB target | Pattern 3 / Pitfall 4 | Medium — if very large images still spike, may need bounded concurrency / sequential-only; measure with Instruments |
| A3 | `fileExists`-based disambiguation (best-effort, tiny TOCTOU window) is acceptable for a single-user desktop tool | Pattern 2 | Low — single-user folder writes; if stricter atomicity wanted, use temp-file + unique move |
| A4 | `UTType("public.heif")` resolves non-nil on macOS 14 for the lossy-format check | Code Examples | Low — `.heic` alone covers Apple's encode path; `.heif` is a belt-and-suspenders conform check |
| A5 | New `.swift` files need explicit Xcode target membership (Phase-2 precedent added definitions via `ToolRegistry` append, but those were new files too) | Runtime State Inventory | Medium — if pbxproj target-add is missed, the tool won't compile in; confirm at plan time |
| A6 | Suggested preset values (Web 60 / Email 75 / Max 95) are reasonable defaults | Code Examples | None — explicitly Claude's discretion per CONTEXT.md; tune freely |

## Open Questions

1. **Should a re-encoded file that came out *larger* be written at all, or skipped/flagged?**
   - What we know: PNG/TIFF (and occasionally HEIC at high quality) can produce a larger file than the original.
   - What's unclear: Product behavior — write anyway and show negative "% saved", or skip the write and tell the user "already optimal"?
   - Recommendation: Default to writing and showing honest negative savings (simplest, never-lose-data aligned). Optionally add a "skip if larger" behavior — flag as a small planner decision, not a blocker.

2. **TIFF in the lossy/lossless bucket.**
   - What we know: TIFF can hold compressed (LZW/JPEG-in-TIFF) or uncompressed data; ImageIO's `kCGImageDestinationLossyCompressionQuality` interaction with TIFF is not as clear-cut as JPEG/HEIC.
   - What's unclear: Whether the quality key meaningfully shrinks TIFF.
   - Recommendation: Treat TIFF as lossless (slider disabled), re-encode best-effort like PNG. If a TIFF test shows the quality key works, can revisit. Low stakes — TIFF is the least-common input.

3. **Single dropped file: table vs. simplified view (D-09 / discretion).**
   - What we know: Table is the baseline; UI may simplify for N=1.
   - Recommendation: Use the same 1-row table for consistency and less code; let the UI plan decide.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ImageIO framework | core re-encode | ✓ (macOS 14 SDK) | system | — |
| CoreGraphics | CGImage types | ✓ | system | — |
| UniformTypeIdentifiers | UTI / format detection | ✓ (already imported in HashView) | system | — |
| AppKit (NSImage) | thumbnails | ✓ | system | ImageIO thumbnail API |
| HEVC encode (HEIC) | HEIC output | ✓ on all macOS-14-supported Macs | system | `Finalize` returns false → per-row warning (graceful) |
| Swift toolchain | build | ✓ | Swift 6.3.3 (Xcode 16+) | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** HEIC encode failure on exotic hardware is handled by the `CGImageDestinationFinalize` Bool gate (graceful per-row warning, no crash).

## Project Constraints (from CLAUDE.md)

- **SwiftUI + MVVM, Swift 5.9+ (Swift 6 toolchain), macOS 14.0+.** New tool follows the 4-file Definition/Transformer/ViewModel/View layout. `[VERIFIED: CLAUDE.md + codebase Tools/Hash structure]`
- **Zero new dependency unless native APIs can't do it.** ImageIO/CoreGraphics suffice → NO new SPM package (libwebp explicitly avoided, D-03). `[VERIFIED: CLAUDE.md "What NOT to Use"]`
- **Offline, zero network.** ImageIO is fully on-device. `[VERIFIED]`
- **Never crash on malformed input (INFRA-17).** All ImageIO calls nil/Bool-gated; corrupt input → per-row warning, never throw across UI. `[VERIFIED: CLAUDE.md constraint + INFRA-17]`
- **Bundle <20MB.** No new framework binary added (system frameworks are dynamically linked, no footprint cost). `[VERIFIED]`
- **Performance: clipboard detect <100ms (N/A — `detectionPredicate: nil`), <100MB RAM under normal use (INFRA-18).** Batch loop must use `autoreleasepool` + off-main `Task` to respect the RAM budget. `[VERIFIED: CLAUDE.md + INFRA-18]`
- **GSD workflow enforcement:** file changes go through a GSD command. `[VERIFIED: CLAUDE.md]`
- **`@Observable` + `@AppStorage` pitfall (MEMORY.md):** if quality slider / preset persists across launches, bind UI controls to `@AppStorage` with the same key — do NOT bind to a computed `PreferencesStore` property (writes drop). `[VERIFIED: user MEMORY.md flint-observable-computed-userdefaults-pitfall]`
- **ToolRegistry is FROZEN** but accepts a sanctioned append (5 Phase-2 tools were appended). Register `ImageCompressDefinition.make()` the same way; confirm current freeze status at plan time. `[VERIFIED: codebase ToolRegistry.swift comment lines 23-36]`

## Sources

### Primary (HIGH confidence)
- Codebase: `Tools/Hash/{HashView,HashViewModel,HashDefinition,HashTransformer}.swift` — off-main Task + progress + cancellation template, drop pipeline, history-wrapper pattern, `resourceValues`/`attributesOfItem` size reads
- Codebase: `Core/Models/ToolDefinition.swift`, `Core/Services/ToolRegistry.swift` — FROZEN tool abstraction + sanctioned-append registration pattern
- Codebase: `Tools/Base64/Base64ViewModel.swift` (lines 269-301), `Tools/Markdown/MarkdownView.swift` — prior art for `data.write(to:options:.atomic)` and NSSavePanel (note: Phase 5 writes beside-original, no panel)
- Codebase: `UI/Components/DropOverlayView.swift`, `UI/Components/WarningBannerView.swift` — reusable drop + warning UI
- developer.apple.com/documentation/imageio/kcgimagedestinationlossycompressionquality — quality key, 0.0–1.0 range
- developer.apple.com/documentation/imageio/cgimagepropertyorientation — orientation metadata
- developer.apple.com/documentation/uniformtypeidentifiers/uttype/3566236-heic — `.heic` UTType
- developer.apple.com WWDC17 Session 511 (Working with HEIF and HEVC) — HEIC is the supported HEIF encode form

### Secondary (MEDIUM confidence)
- developer.apple.com/forums/thread/769659 — `AddImageFromSource` vs `AddImage` metadata behavior
- developer.apple.com/forums/thread/670094 — HEIC is never truly lossless
- developer.apple.com/documentation/imageio/cgimagesourcecreatewithurl — nil return on corrupt/non-image (guard pattern)

### Tertiary (LOW confidence — flagged for validation)
- Medium: "iOS ImageIO Restores Metadata You Thought Was Deleted" — AddImageFromSource re-injects metadata (relevant only to a future strip feature; cross-checked with Apple forum thread 769659)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all system frameworks, verified against codebase usage + Apple docs
- Architecture (4-file layout, batch loop): HIGH — direct mirror of existing Hash tool, verified by reading source
- Core re-encode mechanic (AddImageFromSource + GetType round-trip): HIGH — corroborated by Apple docs + two forum threads + a published article
- File-write disambiguation (net-new): MEDIUM — sound pure-path approach but no in-codebase precedent for beside-original writes; TOCTOU caveat noted
- Memory bounding (autoreleasepool batch): MEDIUM — standard practice, but the <100MB target under large batches is unmeasured (A2) — recommend an Instruments pass during verify
- HEIC/TIFF edge behavior: MEDIUM — HEIC encode confirmed for macOS 14; TIFF lossy interaction is an open question (treat as lossless)

**Research date:** 2026-06-30
**Valid until:** 2026-07-30 (stable system APIs; 30 days)
