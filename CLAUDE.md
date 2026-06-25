<!-- GSD:project-start source:PROJECT.md -->
## Project

**Lathe — macOS Developer Toolkit (Menubar)**

Lathe is a native SwiftUI menubar application for macOS that gives developers instant, offline access to common encoding, formatting, and transformation utilities (JSON, Base64, JWT, hashing, UUIDs, regex, color, markdown, diffing, and more). It lives in the menubar, opens in under a second via global hotkey, and works entirely on-device with no network, no account, and no subscription.

**Core Value:** A developer can paste content and get the right transformation in under a second — fully offline, from anywhere on the system. If everything else fails, the core tools must be instant, correct, and never crash on bad input.

### Constraints

- **Tech stack**: SwiftUI + MVVM, Swift 5.9+ — native macOS requirement, no cross-platform/web stack.
- **Platform**: macOS 14.0+ — uses MenuBarExtra and modern SwiftUI APIs that require Sonoma.
- **Offline**: Zero network dependency for any core tool — privacy and instant-availability guarantee.
- **Performance**: Cold start < 500ms, hotkey-to-popover < 200ms, clipboard detect < 100ms — "zero friction" is the core value.
- **Robustness**: No tool may crash on malformed input — all inputs validated gracefully.
- **Sandboxing**: v1 NOT sandboxed (needs clipboard + arbitrary file access); App Store v2 will sandbox.
- **Accessibility**: VoiceOver labels on all interactive elements, Dynamic Type scaling — system convention compliance.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version / Target | Purpose | Why Recommended |
|------------|-----------------|---------|-----------------|
| Swift | 5.9+ (Swift 6 toolchain, Xcode 16.3+) | Language | Required by GRDB 7; Swift 6 strict concurrency safe for async DB access |
| SwiftUI | macOS 14.0+ | Primary UI framework | Native MVVM, MenuBarExtra, live previews — no bridge code needed |
| AppKit | macOS 14.0+ | NSTextView, NSColorSampler, NSColorPanel | Unavoidable for syntax-highlighted editor and eyedropper; bridged via NSViewRepresentable |
| Foundation | macOS 14.0+ | URL/Base64/UUID/Timestamp encoding, JSONSerialization | Covers Base64, URL encoding, UUID v4, JSON, regex via NSRegularExpression natively |
| CryptoKit | macOS 10.15+ | SHA-1/256/384/512, HMAC | Native, zero-dependency; covers all SHA family + HMAC-SHA2 for JWT verification |
| CommonCrypto | macOS 10.0+ | MD5, CRC32 | CryptoKit explicitly excludes CRC32 and surfaces MD5 only via `Insecure.MD5`; use CommonCrypto directly for CRC32 via `CC_CRC32` (bridging header or `import CommonCrypto`) |
| WKWebView / WebKit | macOS 14.0+ | Markdown HTML preview, PDF export | Sandboxed, zero-dep renderer; `WKWebView.createPDF(configuration:completionHandler:)` produces PDF directly |
| ServiceManagement | macOS 13.0+ | Launch at login (SMAppService) | Apple-approved replacement for all legacy login-item APIs since Ventura; works non-sandboxed and sandboxed |
| NSColorSampler | macOS 10.15+ | Screen color eyedropper | Zero entitlements needed — does NOT require Screen Recording permission; used by Xcode/Keynote |
| NSColorPanel | macOS 10.0+ | System color picker | Integrates with SwiftUI via `ColorPicker` view (wraps NSColorPanel under the hood) |
| CollectionDifference (Foundation) | Swift 5.1+ | Line-level diff computation | Native, production-ready Myers diff; adequate for line-level diffing |
### Swift Packages
| Package | Current Version | Purpose | Decision: Package vs Native | Why |
|---------|----------------|---------|----------------------------|-----|
| **KeyboardShortcuts** (sindresorhus/KeyboardShortcuts) | 3.0.1 | Global hotkey registration with user-customizable UI | **Use package** | CGEventTap requires Accessibility permission prompt — a friction blocker for v1 UX. KeyboardShortcuts uses Carbon `RegisterEventHotKey` under the hood: no accessibility prompt, fully sandbox-compatible, App Store safe. Built-in `KeyboardShortcuts.Recorder` SwiftUI component for Preferences panel. |
| **GRDB.swift** (groue/GRDB.swift) | 7.11.1 | SQLite history store (100 items, searchable) | **Use package** | SwiftData on macOS 14 has documented critical bugs (broken inverse-relationship observation, random element reordering, broken `didSave`). Core Data is mature but overpowered for a 100-row store. UserDefaults has no SQL query capability. GRDB gives typed FetchRequest, ValueObservation for reactive updates, and migrations — all with zero runtime surprises. |
| **HighlightSwift** (appstefan/HighlightSwift) | 1.1.0 | Syntax highlighting for display-only code views (Markdown preview code blocks, JSON read-only output) | **Use package (limited scope)** | Replaces previously-considered Highlightr. Highlightr v2.3.0 was last released June 2020; as of 2026 the maintainer has explicitly deprecated it, recommending HighlightSwift instead. HighlightSwift outputs `AttributedString` suitable for SwiftUI `Text`/`NSAttributedString`. For the full editable NSTextView (JSON editor, Regex test input), use a custom `NSViewRepresentable` wrapping `NSTextView` with `CodeAttributedString` from Highlightr OR write a minimal custom highlighter — see note below. |
| **SwiftDiff** (turbolent/SwiftDiff) | no semver (Oct 2024 commit) | Word/character-level inline diff within changed lines | **Use package** | `CollectionDifference` handles line-level diff natively. Word-level highlight inside a changed line requires the Google Diff Match and Patch algorithm. SwiftDiff is a Swift port of that library. It is lightly maintained (14 commits) but functionally complete — only the diff algorithm is needed, not match/patch. Acceptable for this scope. |
| **swift-markdown** (swiftlang/swift-markdown) | 0.8.0 | Markdown parsing + AST for HTML generation | **Use package over Ink** | swift-markdown is the Apple-backed package powered by cmark-gfm: full GFM support (tables, task lists, strikethrough, fenced code blocks). Ink v0.6.0 (Apr 2024) is community-maintained, lacks full GFM, and is designed for static-site HTML generation — not AST manipulation. For Lathe, the parsed AST renders to HTML via a custom visitor; `WKWebView` displays it. |
| **Sparkle** (sparkle-project/Sparkle) | 2.9.3 | Auto-update for .dmg distribution | **Use package** | The only mature, production-tested update framework for non-MAS macOS apps. EdDSA-signed appcast, delta updates, XPC-sandboxed installer. Add in Phase 3 only — no-op until there is a v1.0 to update from. |
| **ChromaKit** (HarshilShah/ChromaKit) | 0.1.1 | OKLCH ↔ NSColor conversion | **Use package (Phase 2 only)** | macOS has no native OKLCH API. ChromaKit adds `NSColor.oklch(L, C, H)` and conversion back, following CSS Color Level 4 math. Minimal (single file), no transitive deps. Accepted risk on small version number — the math is straightforward to vendor if needed. |
| **MenuBarExtraAccess** (orchetect/MenuBarExtraAccess) | latest | Programmatic show/hide of MenuBarExtra `.window` style | **Conditional — evaluate first** | SwiftUI's `MenuBarExtra` lacks any API to programmatically dismiss the popover (confirmed open Apple Feedback: FB10185203). MenuBarExtraAccess bridges this via `isPresented` Binding. Evaluate whether `@NSApplicationDelegateAdaptor` + `NSStatusItem` is cleaner for this project's level of control before adding this dep. |
### Development & Distribution Tools
| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| Xcode | 16.3+ | Build, sign, archive | Required by GRDB 7 (Swift 6 compiler). Use Xcode's built-in Archive → Notarize workflow. |
| create-dmg (sindresorhus/create-dmg) | 8.1.0 | DMG packaging with background image and symlink | Node.js 20+ required. `create-dmg <App.app> ./dist` produces a notarization-ready, code-signed DMG in one command. |
| notarytool (Xcode CLI) | bundled with Xcode | Apple notary service submission | `altool` deprecated Nov 2023; `notarytool` is the only supported path. `xcrun notarytool submit app.dmg --keychain-profile "AC_PASSWORD" --wait` |
| GRDBQuery (groue/GRDBQuery) | 0.x | SwiftUI `@Query` property wrapper for GRDB | Optional companion to GRDB; consider if views need reactive DB reads without manual `ValueObservation` plumbing. |
## Native-vs-Package Decisions (Explicit)
### MenuBarExtra vs NSStatusItem
### Global Hotkey: KeyboardShortcuts vs CGEventTap
### Syntax Highlighting: Highlightr vs HighlightSwift vs Native
### History Store: GRDB vs SwiftData vs Core Data vs UserDefaults
| Option | Verdict |
|--------|---------|
| SwiftData | Reject for v1. Documented critical bugs on macOS 14: inverse relationship observation broken, random element reordering, `ModelContext.didSave` non-functional. Targeting macOS 14 specifically makes these bugs unavoidable. |
| Core Data | Overkill. 100-item history does not need a persistent store coordinator + managed object context stack. Core Data adds ~5 MB cold-start cost and significant boilerplate for what is essentially a log table. |
| UserDefaults | Inadequate. No SQL `LIKE` for search, no ordered pagination, plist serialization of 100 items with large inputs may hit 4 MB limit edge cases. |
| GRDB | Use. Lightweight (< 1 MB), typed Swift Records via `FetchableRecord` + `PersistableRecord`, SQL `LIKE` for fuzzy search, `ValueObservation` for reactive SwiftUI updates. `DatabaseQueue` is thread-safe and Swift 6 compliant with `Sendable` structs. Migration support handles schema evolution. |
### Markdown: swift-markdown vs Ink vs AttributedString
### Diffing: SwiftDiff vs CollectionDifference
- `CollectionDifference` (native, Swift 5.1+): Use for line-level diff. Split both texts into `[String]` by line, compute `b.difference(from: a)`. Produces `.insert`/`.remove` operations for the side-by-side or unified view. Fast, zero-dep.
- `SwiftDiff` (turbolent): Use only for word-level highlight within a changed line. Feed the old and new versions of a single changed line into `Diff.diff(text1, text2)`. Produces `.equal`/`.insert`/`.delete` character-range operations for inline highlighting.
### Hashing: CryptoKit + CommonCrypto
- `SHA256`, `SHA384`, `SHA512`: use directly
- `SHA1` via `Insecure.SHA1`: use (JWT validation uses SHA1 in some contexts)
- `HMAC<SHA256>.authenticationCode(for:using:)` etc.: use for JWT HMAC verify
- MD5: `CC_MD5(data, len, result)` — CryptoKit surfaces `Insecure.MD5` but CommonCrypto is the safe import path for non-sandboxed targets
- CRC32: `crc32(0, data, len)` from `<zlib.h>` — CryptoKit has no CRC32; zlib ships on every macOS
### Color: NSColorSampler, NSColorPanel, OKLCH
- `NSColorSampler` (macOS 10.15+): use directly. Zero permissions, zero deps. `NSColorSampler().show(selectionHandler:)` returns an `NSColor?` asynchronously.
- `NSColorPanel`: already wrapped by SwiftUI `ColorPicker`. Use `ColorPicker("", selection: $color)` in SwiftUI; drop to `NSColorPanel.shared` only if custom panel configuration is needed.
- OKLCH conversion: **ChromaKit 0.1.1**. No native macOS API exists for OKLCH. ChromaKit follows CSS Color Level 4 math and extends `NSColor`. Acceptable addition for Phase 2.
### Launch at Login: SMAppService
### Auto-Update: Sparkle
### .dmg Packaging + Notarization
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **SwiftData** | Critical bugs on macOS 14: broken observation, random reordering, non-functional `didSave`. Not stable enough for production on the minimum-supported OS. | GRDB 7 |
| **Highlightr (raspu)** | Explicitly deprecated by maintainer as of 2026. Last release June 2020, 22 open issues, no Swift 6 compatibility statement. | HighlightSwift for display; custom NSTextStorage for editable views |
| **Ink** | No full GFM (missing task lists, limited tables in v0.6.0), community-maintained, static-site oriented. | swift-markdown (swiftlang-backed, cmark-gfm) |
| **CryptoSwift** | ~500 KB addition, pure-Swift implementations slower than system CryptoKit/CommonCrypto for SHA/HMAC. No benefit over native for this use case. | CryptoKit + CommonCrypto (system) |
| **CGEventTap for global hotkey** | Requires Accessibility permission prompt at runtime — kills zero-friction UX for a dev tool with no other Accessibility need. | KeyboardShortcuts 3.0.1 |
| **Core Data** | Overkill for 100-row history log. Adds ~5 MB cold-start overhead and significant boilerplate. | GRDB 7 |
| **NSStatusItem bare (without MenuBarExtra)** | Abandons SwiftUI lifecycle, requires manual NSWindow management and NSPopover wiring. Only justified if `MenuBarExtra` proves unworkable. | SwiftUI `MenuBarExtra` (.window style) |
| **altool** | Removed from Apple notary service November 2023. Submitting with altool fails. | `xcrun notarytool` |
| **SwiftUI AttributedString(markdown:)** | Inline Markdown only (bold, italic, links). No fenced code blocks, tables, or task lists. Insufficient for a Markdown preview pane. | swift-markdown → WKWebView |
## Alternatives Considered
| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| History store | GRDB 7.11.1 | SwiftData | Critical macOS 14 bugs make it unreliable on the min OS |
| History store | GRDB 7.11.1 | Core Data | Overkill for 100 rows; heavy boilerplate |
| History store | GRDB 7.11.1 | UserDefaults | No SQL search, plist size risk |
| Markdown parsing | swift-markdown 0.8.0 | Ink 0.6.0 | Incomplete GFM; not AST-based |
| Markdown rendering | WKWebView + swift-markdown | swift-markdown-ui | swift-markdown-ui is in maintenance mode (redirects to Textual); WKWebView gives PDF export for free |
| Syntax highlight (edit) | Custom NSTextStorage | Highlightr | Deprecated as of 2026 |
| Syntax highlight (display) | HighlightSwift 1.1.0 | Sourceful | Sourceful last released 2021, unmaintained |
| Global hotkey | KeyboardShortcuts 3.0.1 | CGEventTap | Requires Accessibility permission dialog |
| Auto-update | Sparkle 2.9.3 | Squirrel | Squirrel designed for Electron; unmaintained for native macOS |
| OKLCH | ChromaKit 0.1.1 | swift-oklch | swift-oklch is a single-file gist-level project; ChromaKit has proper SPM packaging |
| .dmg packaging | create-dmg 8.1.0 | Packages.app GUI | Not CI-automatable; create-dmg is scriptable and integrates with notarytool |
## Package Integration (Swift Package Manager)
## Version Compatibility
| Package | Swift Req | macOS Min | Notes |
|---------|-----------|-----------|-------|
| KeyboardShortcuts 3.0.1 | 6.2 (tools) | 10.15 | Swift 6 toolchain required; Xcode 16+ |
| GRDB 7.11.1 | 6.1+ | 10.15 | Requires Xcode 16.3+; Swift 6 strict concurrency; use Sendable structs for records |
| HighlightSwift 1.1.0 | 5.9+ | 13.0 (est.) | Uses JavaScriptCore via highlight.js |
| SwiftDiff | 5.x | 10.10+ | No formal version; pin to Oct 2024 commit |
| swift-markdown 0.8.0 | 5.9+ | — | cmark-gfm C dependency; cross-platform |
| Sparkle 2.9.3 | 5.x | 10.13 | Requires Hardened Runtime + Developer ID signing |
| ChromaKit 0.1.1 | 5.x | 12.0 (est.) | Uses SwiftUI.Color API; verify against macOS 14 |
## Footprint Estimate
| Component | Approx. Size Impact |
|-----------|-------------------|
| GRDB.swift (static) | ~800 KB |
| KeyboardShortcuts | ~200 KB |
| HighlightSwift + highlight.js bundle | ~400 KB |
| swift-markdown + cmark-gfm | ~600 KB |
| Sparkle.framework | ~4 MB (Phase 3) |
| ChromaKit | ~50 KB |
| SwiftDiff | ~30 KB |
| **Total packages (excl. Sparkle)** | **~2 MB** |
## Sources
- KeyboardShortcuts GitHub (verified 2026-06-25): https://github.com/sindresorhus/KeyboardShortcuts — version 3.0.1, Swift 6.2 tools, macOS 10.15+
- GRDB.swift GitHub releases (verified 2026-06-25): https://github.com/groue/GRDB.swift — version 7.11.1, Xcode 16.3+
- GRDB Migration Guide (Context7 HIGH): v7 requires Swift 6 compiler and Xcode 16+
- Highlightr deprecation notice (verified 2026-06-25): https://github.com/raspu/Highlightr — "no longer actively maintained, use HighlightSwift"
- HighlightSwift GitHub (verified 2026-06-25): https://github.com/appstefan/HighlightSwift — version 1.1.0
- Sparkle GitHub releases (verified 2026-06-25): https://github.com/sparkle-project/Sparkle — version 2.9.3
- swift-markdown GitHub releases (verified 2026-06-25): https://github.com/swiftlang/swift-markdown — version 0.8.0
- ChromaKit GitHub (verified 2026-06-25): https://github.com/HarshilShah/ChromaKit — version 0.1.1, OKLCH + NSColor
- create-dmg GitHub (verified 2026-06-25): https://github.com/sindresorhus/create-dmg — version 8.1.0
- SwiftDiff GitHub (verified 2026-06-25): https://github.com/turbolent/SwiftDiff — Google Diff port, Oct 2024 last commit
- Apple Developer Docs — SMAppService: https://developer.apple.com/documentation/servicemanagement/smappservice — macOS 13+
- Apple Developer Docs — NSColorSampler: macOS 10.15+, zero permissions needed
- Apple Developer Docs — MenuBarExtra: https://developer.apple.com/documentation/SwiftUI/MenuBarExtra
- MenuBarExtraAccess (programmatic dismiss workaround): https://github.com/orchetect/MenuBarExtraAccess
- SwiftData macOS 14 bugs documented: https://mjtsai.com/blog/2024/06/04/swiftdata-issues-in-macos-14-and-ios-17/
- Apple notarytool (altool deprecated Nov 2023): https://developer.apple.com/documentation/security/customizing-the-notarization-workflow
- CryptoKit limitations (no CRC32): https://www.andyibanez.com/posts/cryptokit-not-enough/
- Sparkle docs (EdDSA signing, appcast): https://sparkle-project.org/documentation/
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
