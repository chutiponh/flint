# Deferred Items — Phase 03

## Discovered during 03-01 execution

- **Headless `xcodebuild -scheme Flint` test-target build fails on `XCTest` module resolution**
  (`FlintTests/PinnedToolReorderTests.swift:22 import XCTest` — "compilation search paths unable
  to resolve module dependency: 'XCTest'"). Pre-existing: the file was added in commit `5a4632c`
  ("rename project Lathe -> Flint…"), before plan 03-01's first commit (`2572090`). Out of scope
  for 03-01 (no app-target source files changed by this plan are implicated; none of the 03-01
  files produce compile errors). The app target's own Swift sources (including the three new
  03-01 files) compile cleanly under the scheme; the failure is isolated to the XCTest module
  search path for the test bundle under CLI `xcodebuild`. Verify in Xcode's GUI build / re-run
  with a resolved package graph during the Phase 03 batched manual-verification pass.
