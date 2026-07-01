# 05-09 SUMMARY — UAT gap re-verification (Tests 5/6/9/10)

**Plan:** 05-09 (gap_closure, autonomous: false — human UAT)
**Status:** COMPLETE — all four gaps re-pass on a clean build.

## Result

| UAT Test | Gap | Verdict |
|----------|-----|---------|
| 5 — already-optimized PNG never grows | GAP 1 | ✅ pass |
| 6 — quality slider has a clear effect | GAP 2 | ✅ pass |
| 9 — Cancel stops the in-flight row | GAP 3 | ✅ pass |
| 10 — re-drop writes -compressed-1 | GAP 4 | ✅ pass |

Task 1 (automated gate): `xcodebuild clean build test` — **BUILD SUCCEEDED / TEST SUCCEEDED**, full
FlintTests suite green (never-larger, cancellation 0.75s, recompress, disambiguation, off-main proof,
plus the follow-up tests below). BUILD_DIR:
`~/Library/Developer/Xcode/DerivedData/Flint-bihwzmhhyditfbfymjsfewyxvknj/Build/Products/Debug`.

Task 2 (human verify, 2026-07-01): re-tested on the freshly-built binary launched by full path from
BUILD_DIR. Tests 5 and 6 passed as-shipped by 05-06/05-08.

## Follow-up fixes found during human UAT (beyond the original four plans)

Human re-test surfaced three residual issues on top of the gap-closure work. Fixed inline (small,
well-scoped edits + tests):

1. **Test 9 — cancelled compress left an output file.** The transformer's quantizer bails to the
   truecolor/copy-through fallback on cancel, which still writes `destURL`. Added a post-write
   `Task.isCancelled` gate in `ImageCompressTransformer.compress` that deletes the file and returns
   `.failure(.writeFailed)`. The ViewModel already discards the result on cancel. Test:
   `testCancellation` now also asserts no `-compressed` file remains on disk.

2. **Test 10 — re-drop overrode the row instead of adding one.** Every drop REPLACED `rows`, so a
   re-drop overwrote the previous row (file-level `-compressed-1` disambiguation was already correct).
   Refactored `ImageCompressViewModel` from a per-drop batch loop to a **single serial work queue**
   (`pendingQueue`): a drop enqueues rows + work items and starts the drain loop only if idle; drops
   accumulate whether the previous batch is finished OR still compressing (drop-while-loading). Rows
   are tracked by stable `id` so mid-flight appends never shift the in-flight item. Supersede
   (recompress) still cancels + replaces; cancel/clear drain the queue. Tests:
   `testAppendRedropAddsRow`, `testAppendWhileCompressing`.

3. **Clear button requested.** Wired the existing `clearInput()` to a "Clear" button in the results
   header; `clearInput()` now also forgets `lastSourceURLs`/`lastRunQuality` and bumps
   `batchGeneration` so a stale loop can't clobber after reset. Test: `testClearInputForgetsBatch`.

## Deviation worth flagging (carried from 05-07)

05-07 used `Task.detached` for off-main work, which contradicts the recorded MEMORY learning
"Off-main cancellable work pattern" (child `Task` + nonisolated static helper, NOT `Task.detached`).
The executor argued a plain child `Task {}` in a `@MainActor` context runs the synchronous nonisolated
helper on the main thread (freezing the UI). Human UAT of Test 9 confirmed the UI is **not** frozen —
Cancel responds immediately while compression runs — and `testOffMainProof` stays green. The
queue refactor here preserves the `Task.detached` inner-work primitive. The MEMORY note may need
revisiting (the documented pattern's claim about plain-Task-on-main-thread for *synchronous*
nonisolated calls appears to be the crux); left for a memory review, not changed here.

## Files touched (follow-up delta; 05-06/07/08 committed by their executors)

- `Tools/ImageCompress/ImageCompressTransformer.swift` — cancel-cleanup gate
- `Tools/ImageCompress/ImageCompressViewModel.swift` — serial work-queue refactor, clearInput reset
- `Tools/ImageCompress/ImageCompressView.swift` — accumulate on drop (append), Clear button
- `FlintTests/ImageCompressViewModelTests.swift` — 4 new/updated tests

`05-UAT.md` updated: 10/10 pass, four feature gaps `status: closed` (Test-1 auto-update gap is
out-of-phase, left `failed`).
