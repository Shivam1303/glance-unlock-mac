# Glance Unlock project checklist

This is the living implementation and validation checklist. Update it when features, tests, or safety decisions change.

## Completed implementation

- [x] Native SwiftUI macOS app, Apple silicon target, and Xcode project.
- [x] Camera sandbox entitlement and plain-language `NSCameraUsageDescription`.
- [x] Dark minimal UI, first-launch privacy explanation, and permission recovery path.
- [x] Isolated AVFoundation capture service with a mirrored preview and throttled frame delivery.
- [x] Isolated Vision face analysis with zero/one/multiple face states, face size, centering, and basic lighting guidance.
- [x] Core Image-based local crop/lighting processing; frames are discarded after analysis.
- [x] Five-sample enrolment workflow with stable-frame gating.
- [x] Observable per-sample progress, paced pose prompts, and notch-style capture feedback.
- [x] Vision feature-print creation on a dedicated worker queue.
- [x] Keychain storage for derived feature-print archives only, using device-only Data Protection when signing supports it and encrypted login-Keychain storage for local ad-hoc builds.
- [x] Non-interactive Keychain access; the app never presents a Keychain password prompt.
- [x] Profile loading, reset, and re-enrolment.
- [x] Best-three-average match policy with configurable debug-only threshold.
- [x] Conservative consecutive-frame matching before a liveness challenge begins.
- [x] Open → closed → open blink detector with confirmation frames, timeout, and reset behavior.
- [x] Full-screen simulated lock with clock, state feedback, unlock animation, and always-available exit control.
- [x] Camera-notch status presentation for enrolment and safe-lock state changes, including reduced-motion support.
- [x] Minimal macOS workspace redesign with explicit enrolment steps and accessible state feedback.
- [x] No network client, analytics, image persistence, password handling, or system-authentication integration.
- [x] XCTest coverage for liveness transitions, timeout/reset, and matching policy aggregation.
- [x] Xcode 26.6 native arm64 Debug build and unit-test suite passing.

## Manual validation remaining

- [ ] Enrol and unlock in daylight and typical indoor lighting.
- [ ] Test with glasses on/off, where relevant.
- [ ] Confirm response to no face, two faces, an obscured camera, and poor lighting.
- [ ] Confirm camera permission denial and re-enabling access in System Settings.
- [ ] Confirm reset removes the profile, then confirm it is absent after relaunch.
- [ ] Measure genuine unlock consistency at 45–75 cm and slight left/right angles.
- [ ] Test simple impostor attempts: another person, printed photo, and phone-displayed photo.
- [ ] Tune the debug threshold conservatively using only local, non-image notes.
- [ ] Test full-screen entry/exit, window resizing, camera interruption, sleep, and wake.
- [ ] Confirm the app remains responsive during enrolment and safe lock.

## Follow-up test work

- [ ] Add Keychain store tests through a protocol-based Keychain test double.
- [ ] Add unit tests for unlock multi-frame consensus and lost-face reset.
- [ ] Add UI tests for permission-recovery and exit-safe-lock visibility.
- [ ] Add a documented manual-test result template that contains no biometric data.

## Deferred work — do not implement as part of this prototype

- [ ] Randomized liveness challenges.
- [ ] Reviewed passive anti-spoofing model, only after a separate privacy/accuracy review.
- [ ] Multiple local face profiles, if a concrete user need emerges.
- [ ] Signed/notarized distribution.
- [ ] Any real macOS login-window, PAM, FileVault, authorization, privileged-helper, or system-lock integration.
# Password-protected controls

- [ ] With protection active, choose **Pause Protection** in the menu bar: verify a Mac account password prompt appears and cancelling keeps protection active.
- [ ] Enter an incorrect password: verify protection remains active. Enter the correct password: verify protection pauses. Resume without a prompt.
- [ ] Repeat pause/cancel and pause/success using the protection settings switch; verify removing an app's protection also requires the password.
- [ ] Choose **Quit Glance** and cancel: verify monitoring continues. Repeat with Command-Q. Enter the correct password: verify Glance quits.
- [ ] On a Mac with Touch ID or Apple Watch configured, verify these controls still require the account password.
- [ ] After successful authentication, request another protected action: verify a fresh password prompt appears.
