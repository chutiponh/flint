---
status: complete
phase: 04-ux-improvement
source: [04-05-SUMMARY.md, 04-06-PLAN.md]
started: 2026-06-30T09:30:00Z
updated: 2026-06-30T12:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Default-OFF — no Accessibility prompt
expected: Toggle is OFF on first launch; no Accessibility permission dialog at launch or on opening Preferences (CF-02)
result: pass

### 2. Permission UI (redesigned — two-phase)
expected: When Accessibility not granted, show a "Grant Accessibility Permission…" button (no toggle). The button triggers the system prompt + opens Settings.
result: pass
note: |
  Original single-toggle+poll design was scrapped. Root cause of "no prompt" was
  NOT lack of signing — it was (a) 7 stale TCC records for com.flint.app
  suppressing the re-prompt (cleared via tccutil reset), and (b) macOS caching
  the per-process trust verdict so the poll hung. Redesigned to two-phase UI
  (button when ungranted, toggle when granted, re-check on window focus). Prompt
  now appears for the fresh dev.chutipon.flint identity. Verified working.

### 3. Toggle ON with permission — appears + persists
expected: With Accessibility granted (UI flips to toggle on window focus), the toggle enables/disables and the chosen state persists across tab switches.
result: pass
note: |
  Toggle now bound to @AppStorage("lathe.pasteBackEnabled") — the prior
  prefs.pasteBackEnabled binding (computed UserDefaults property, not instrumented
  by @Observable) silently dropped writes so the toggle reverted on tab switch.
  ON/OFF both persist now. Verified working.

### 4. End-to-end paste-back (⌘1 in Color tool)
expected: Focus a text field in another app, open Flint via hotkey, use Color tool, press ⌘1 — the HEX value is copied AND pasted into the previously-focused app's text field
result: pass
note: Verified working on hardware. Confirms RESEARCH A2/A3 assumptions (CGEvent virtual key code 9, 80ms activation delay) are correct.

### 5. Revoke permission while ON — copy only, no crash
expected: With toggle ON, revoke Accessibility in System Settings, then press ⌘1 in a tool — it copies the output only (no paste), and the app does not crash (T-04-12 re-verify)
result: pass

### 6. ⌘7 on NumberBase (only 4 rows) — no-op, no crash
expected: Open the Number Base tool (has fewer than 7 output rows) and press ⌘7 — nothing happens, no crash
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

(all resolved — see 04-06-PLAN.md; fixes committed 91f952c + 0e271bd)

Resolution summary:
- "No prompt" was NOT a signing issue. Two real causes found + fixed:
  1. 7 stale TCC records for com.flint.app suppressed the re-prompt → cleared
     with `tccutil reset`; renamed bundle id to dev.chutipon.flint (fresh identity).
  2. The single-toggle+30s-poll design hung on macOS's per-process trust cache →
     replaced with two-phase UI (grant button → toggle, re-check on window focus).
- "Toggle OFF/ON didn't persist" → bound to a computed @Observable UserDefaults
  property that the macro doesn't instrument (writes dropped). Fixed with
  @AppStorage("lathe.pasteBackEnabled").
- Signing deferred to release (Phase 3) as intended; not needed for dev verify.
