---
status: partial
phase: 04-ux-improvement
source: [04-05-SUMMARY.md]
started: 2026-06-30T09:30:00Z
updated: 2026-06-30T09:50:00Z
---

## Current Test

number: 6
name: ⌘7 on NumberBase (only 4 rows) — no-op, no crash
expected: |
  Open the Number Base tool (fewer than 7 output rows) and press ⌘7. Nothing
  happens and the app does not crash. (Does not require Accessibility permission.)
awaiting: user response

## Tests

### 1. Default-OFF — no Accessibility prompt
expected: Toggle is OFF on first launch; no Accessibility permission dialog at launch or on opening Preferences (CF-02)
result: pass

### 2. Toggle ON without permission — prompt + revert + denial UI
expected: Flipping toggle ON (no permission granted) shows the system Accessibility prompt; after declining/timeout the toggle reverts to OFF, an orange "permission was denied" message and an "Open System Settings" button appear
result: blocked
blocked_by: release-build
reason: |
  No prompt appeared on toggle ON. Root cause: machine has NO code-signing
  identities ("0 valid identities found"), so the Debug build is ad-hoc signed
  (codesign flags=0x2 adhoc, TeamIdentifier=not set). macOS TCC cannot anchor an
  Accessibility prompt/grant to an ad-hoc binary with no stable identity, so
  AXIsProcessTrustedWithOptions(prompt:true) silently shows nothing. Toggle-handler
  CODE is correct (PreferencesView.swift:228-267) — this is an environment blocker.
  Requires a Developer ID-signed build to verify.

### 3. Toggle ON with permission — stays ON + confirmation
expected: With Accessibility granted, flipping the toggle ON keeps it ON and shows confirmation text "Accessibility permission granted. ⌘1–⌘9 will copy and paste the result into the previously-focused app."
result: blocked
blocked_by: release-build
reason: Depends on a real Accessibility grant, which cannot persist for an ad-hoc-signed build (no signing cert on machine). Needs a signed build.

### 4. End-to-end paste-back (⌘1 in Color tool)
expected: Focus a text field in another app, open Flint via hotkey, use Color tool, press ⌘1 — the HEX value is copied AND pasted into the previously-focused app's text field
result: blocked
blocked_by: release-build
reason: CGEvent paste synthesis is gated on AXIsProcessTrusted() at call time; cannot be exercised without a real grant, which requires a signed build. Virtual key code 9 + 80ms delay (RESEARCH A2/A3) remain unconfirmed on hardware.

### 5. Revoke permission while ON — copy only, no crash
expected: With toggle ON, revoke Accessibility in System Settings, then press ⌘1 in a tool — it copies the output only (no paste), and the app does not crash (T-04-12 re-verify)
result: blocked
blocked_by: release-build
reason: Cannot reach the ON-with-permission state to revoke from, on an ad-hoc build. Needs a signed build.

### 6. ⌘7 on NumberBase (only 4 rows) — no-op, no crash
expected: Open the Number Base tool (has fewer than 7 output rows) and press ⌘7 — nothing happens, no crash
result: [pending]

## Summary

total: 6
passed: 1
issues: 0
pending: 1
skipped: 0
blocked: 4

## Gaps

- truth: "Toggling paste-back ON requests Accessibility permission and a granted permission persists, enabling ⌘1–⌘9 to paste into the previously-focused app"
  status: blocked
  reason: "Machine has no code-signing cert → ad-hoc build → no stable identity (signing-identifier + cdhash change every rebuild) → macOS TCC cannot show prompt or persist grant. Toggle-handler code is correct by inspection (PreferencesView.swift:228-267)."
  severity: blocker
  test: "2,3,4,5"
  root_cause: "Ad-hoc / unsigned build has no stable TCC identity. Evidence: prev build Identifier=Flint cdhash=8933a224 (linker-signed); rebuild Identifier=com.flint.app cdhash=206b34db. security find-identity → 0 valid identities."
  artifacts:
    - path: "Flint.xcodeproj/project.pbxproj"
      issue: "No DEVELOPMENT_TEAM; ad-hoc signing fallback; bundle id com.flint.app to be renamed dev.chutipon.flint"
    - path: "UI/PreferencesView.swift"
      issue: "handlePasteBackToggleOn: 30s silent wait with no feedback when prompt cannot surface"
  missing:
    - "Stable signing identity via free Apple Development cert (DEVELOPMENT_TEAM)"
    - "Bundle id rename com.flint.app → dev.chutipon.flint"
    - "Immediate 'waiting for permission' status during the poll"
  debug_session: ".planning/phases/04-ux-improvement/04-06-PLAN.md"
