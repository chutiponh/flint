---
status: complete
phase: 05-add-image-compression-feature
source: [05-01-SUMMARY.md, 05-02-SUMMARY.md, 05-03-SUMMARY.md, 05-04-SUMMARY.md, 05-05-SUMMARY.md]
started: 2026-06-30T09:30:00Z
updated: 2026-06-30T10:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test
expected: Quit Flint, then launch it fresh from the canonical build product (not a stale DerivedData copy). Menubar icon appears, popover opens fast, and the Image Compressor tool is present in the grid. No crash, no missing tool on cold launch.
result: pass
note: "Cold-launched clean Debug build (PID 21999) from canonical BUILD_DIR. Tool present, no crash. Separately observed an auto-update warning on launch — logged as out-of-scope issue below (not a phase-05 deliverable)."

### 2. Launcher search routing
expected: Searching the launcher for "image" or "compress" finds and routes to the Image Compressor tool.
result: pass

### 3. Drop images → live results table
expected: Dropping one or more images onto the tool shows a per-row thumbnail, original→new size, and a green "−NN%" saved (or secondary "+N%"/"0%" if it grew), updating live as each image finishes. A `-compressed` file is written beside each original.
result: pass

### 4. PNG photographic compression ratio (UAT Test 8 re-test)
expected: Compressing a photographic PNG now shrinks it meaningfully (indexed-color output) — comparable to a dedicated PNG optimizer, not the near-0% from before. Output stays the same dimensions and is a valid PNG.
result: pass

### 5. PNG transparency preserved
expected: Compressing a PNG that has transparent areas keeps those areas transparent after compression — no black/white fill replacing the transparency.
result: issue
reported: "transparency works, but the output is BIGGER — Google-Logo-2015.png went 30 KB → 46 KB (+55%)"
severity: major

### 6. Lossless slider gate (D-05)
expected: When every dropped file is PNG/TIFF, the quality slider is disabled and a helper line explains lossless formats ignore the quality setting.
result: issue
reported: "slider IS disabled correctly, but the slider/presets are contradictory with the workflow — dropping an image compresses it immediately, so there's no point at which the slider can affect the images you just dropped. When does it actually take effect?"
severity: minor

### 7. Quality presets (Web/Email/Max)
expected: The matching preset button (Web 60 / Email 75 / Max 95) renders prominent when active and plain otherwise; selecting a preset moves the slider. Lower quality on a JPEG produces a smaller file.
result: pass

### 8. Non-image / corrupt input never crashes (INFRA-17)
expected: Dropping a non-image (or corrupt image) alongside valid images shows a warning on the failed row; the app never crashes and the valid images still compress.
result: pass

### 9. Cancel mid-batch
expected: Pressing Cancel during a large batch stops pending rows; already-finished rows keep their results; the Cancel button hides afterward.
result: issue
reported: "after pressing Cancel the row keeps spinning (still processing) — the compressing image never stops and the row stays stuck in the spinner state"
severity: major

### 10. Collision disambiguation (D-07/D-08)
expected: Compressing the same source twice produces `photo-compressed.jpg` then `photo-compressed-1.jpg` — the original is never overwritten.
result: issue
reported: "dropping the same image a second time shows nothing new in the table AND writes no second file to disk — the re-drop appears to do nothing"
severity: major
note: "Tested immediately after the stuck-Cancel issue (Test 9). The disambiguation logic (-compressed-1) cannot be reached because the second compression never produces output. Likely interacts with the Test-9 stuck state; diagnosis must confirm whether a clean-state re-drop disambiguates correctly or whether the drop handler itself is at fault."

## Summary

total: 10
passed: 6
issues: 4
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "App launches cleanly without spurious update/error warnings"
  status: failed
  reason: "User reported: an auto-update warning appears on app launch"
  severity: minor
  test: 1
  scope: out-of-phase
  note: "Surfaced during phase-05 cold-start test but belongs to the Sparkle auto-update subsystem (Phase 03), not the image-compression feature. Logged for follow-up; does not block phase-05 verification."
  artifacts: []
  missing: []

- truth: "Compressed PNG output is never larger than the original file (it's a compressor)"
  status: failed
  reason: "User reported: Google-Logo-2015.png 30 KB → 46 KB (+55%). Transparency preserved, but file grew."
  severity: major
  test: 5
  root_cause: "ImageCompressTransformer.writePNGCompressed (lines 151-173) gates the never-larger guard against a TRUECOLOR RE-ENCODE, not the ORIGINAL FILE. For an already-optimized PNG (small palette/low-color logo), the quantized indexed output (46 KB) is larger than the original (30 KB) but smaller than a fresh truecolor RGBA re-encode, so quantized wins the {quantized, truecolor} comparison and gets written. The original 30 KB file is never a candidate. D-06's contract ('never larger than a truecolor re-encode') does not match the user expectation ('a compressor must never make a file bigger')."
  artifacts:
    - path: "Tools/ImageCompress/ImageCompressTransformer.swift"
      issue: "writePNGCompressed never-larger guard compares vs truecolor re-encode, not vs original source bytes (lines 151-173)"
  missing:
    - "When neither quantized nor truecolor beats the original source file size, copy the ORIGINAL through to destURL (or report 0%/skip) so output is never larger than input"
    - "Apply the same never-larger-than-original guard to the non-PNG ImageIO re-encode path (a re-saved JPEG/HEIC can also grow); currently only PNG has any guard"
  debug_session: ""

- truth: "The quality slider/presets have a clear, non-contradictory relationship to the compress action"
  status: failed
  reason: "User reported: drop-to-compress is immediate, so the quality slider can never affect the images already dropped. Its effect is invisible/deferred-to-next-drop, and it's disabled entirely for PNG/TIFF — so for the all-lossless case it appears to do nothing at all."
  severity: minor
  test: 6
  root_cause: "ImageCompressView triggers viewModel.compress(urls:quality:) immediately on drop (onDrop → DispatchGroup join → compress). The @AppStorage quality value is only read at drop time, so changing the slider after a drop has no effect on the current results — there is no 're-run with new quality' affordance. The slider reads as a control over 'this compression' but is actually 'the next one'. UX-design gap, not a code defect."
  artifacts:
    - path: "Tools/ImageCompress/ImageCompressView.swift"
      issue: "compress fires immediately onDrop; no re-run-on-quality-change path; slider effect is deferred and non-obvious"
  missing:
    - "Either: re-run compression on the current batch when quality/preset changes, OR make it explicit that quality applies to the next drop (e.g. set quality before dropping), OR add a 'Re-compress' action"
    - "Design decision needed — defer to discuss/plan; this is a workflow contract, not a one-line fix"
  debug_session: ""

- truth: "Pressing Cancel stops in-flight work and the compressing row leaves the spinner state"
  status: failed
  reason: "User reported: after Cancel the single compressing row keeps spinning; the image never stops processing and the row stays stuck in .compressing."
  severity: major
  test: 9
  root_cause: "ImageCompressViewModel.compress runs the heavy ImageIO/quantization work as a synchronous `autoreleasepool { ImageCompressTransformer.compress(...) }` inside `await Task.detached(...).value` (lines 173-177). That synchronous work has NO cancellation check, so cancel() cannot interrupt it — a slow PNG quantization runs to completion. Worse, on return the post-await `guard !Task.isCancelled else { break }` (line 181) breaks BEFORE applying the result, so rows[i] is never moved out of .compressing — the row spins forever. cancel() also sets isCompressing=false immediately (hides the Cancel button) even though work is still running, matching the screenshot (button gone, spinner persists)."
  artifacts:
    - path: "Tools/ImageCompress/ImageCompressViewModel.swift"
      issue: "in-flight Task.detached ImageIO work is non-cancellable (lines 173-177); on cancel the current row is abandoned in .compressing instead of a terminal/cancelled state (line 181 breaks before apply)"
  missing:
    - "On cancel, reset any .compressing row to a terminal state (e.g. .pending or a .cancelled state) so no row is left spinning"
    - "Make the per-image work cancellation-aware where possible (check Task.isCancelled inside the loop body before/after the detached call and update the row), OR accept that the in-flight image finishes but ensure its row resolves rather than dangles"
    - "Do not flip isCompressing=false until the in-flight image's row has been resolved, or visibly reflect 'cancelling…' state"
  debug_session: ""

- truth: "Compressing the same source twice writes photo-compressed then photo-compressed-1 without overwriting the original (D-07/D-08)"
  status: failed
  reason: "User reported (clarified): dropping the same image a second time shows nothing new in the table AND writes no second file to disk — the re-drop appears to do nothing."
  severity: major
  test: 10
  root_cause: "UNCONFIRMED — needs diagnosis. The second compress() apparently produces no output (no disk write), so disambiguatedCompressedURL (which is sound on its own) is never exercised. Strong suspect: state poisoning from the Test-9 stuck-cancel path — the orphaned non-cancellable Task.detached from the prior batch plus task=nil / isCompressing=false in cancel() can leave the ViewModel unable to surface a fresh batch. Must verify whether a clean-state (relaunch) re-drop disambiguates correctly, which would tie this gap to the cancel bug rather than the drop handler."
  artifacts:
    - path: "Tools/ImageCompress/ImageCompressViewModel.swift"
      issue: "compress() replaces rows wholesale each drop; possible interaction with orphaned in-flight task from a prior cancelled batch (lines 141-156, 235-239)"
    - path: "Tools/ImageCompress/ImageCompressView.swift"
      issue: "onDrop → DispatchGroup → compress path; confirm second drop fires and produces non-empty urls (lines 43-69)"
  missing:
    - "Diagnose whether the re-drop failure is independent or a downstream symptom of the Test-9 cancel bug; reproduce from a clean launch"
    - "Ensure a fresh compress() always supersedes any prior batch state and reliably writes output"
  debug_session: ""
