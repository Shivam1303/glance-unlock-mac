# Glance Unlock — Build Specification

## 1. Project summary

Build a native macOS application that demonstrates Face ID-style unlocking using
the MacBook camera. The first version is deliberately a **safe prototype**: it
creates a simulated full-screen lock experience inside the app and does not
replace or modify the real macOS login screen.

Target machine:

- MacBook Air with Apple M4
- macOS Tahoe 26.6
- Latest stable Xcode compatible with macOS Tahoe
- Apple silicon only for the initial version

Working name: **Glance Unlock**

One-line pitch:

> Look at your Mac, blink once, and watch a private on-device lock screen open.

## 2. Goals

The MVP must:

1. Be a polished native macOS app written in Swift and SwiftUI.
2. Request and use camera access correctly.
3. Detect exactly one face in the camera frame.
4. Let the user enrol their face locally.
5. Convert the face crop into a numerical feature representation.
6. Store the enrolled representation locally and securely.
7. Provide a simulated full-screen lock screen.
8. Compare the current face against the enrolled profile.
9. Require a basic liveness action, initially a natural blink.
10. Unlock the simulated screen only when both recognition and liveness succeed.
11. Work without an internet connection.
12. Never upload camera frames, face data, or analytics.

## 3. Non-goals and safety boundary

The first version must **not**:

- Replace the macOS login window.
- Install an Authorization Services plug-in, PAM module, launch daemon, system
  extension, or privileged helper.
- Read, save, request, paste, or simulate typing the user's Mac password.
- Disable FileVault, System Integrity Protection, Gatekeeper, or sandboxing.
- Claim security equivalent to Apple's Face ID.
- Unlock the computer after boot or decrypt FileVault storage.
- Send images or embeddings to a server.
- Use shell commands to manipulate macOS authentication databases.

Closing or force-quitting the app will bypass the simulated lock. This is
expected and must be clearly stated in the interface and README.

## 4. Why this is a prototype

The MacBook Air camera captures ordinary RGB video. It does not provide the
infrared depth map and specialized anti-spoofing hardware used by TrueDepth and
Face ID. Face matching plus blink detection can create a compelling demo, but it
may still be fooled by replayed video, a high-quality screen, or a sophisticated
mask. Treat it as a local experiment rather than a security product.

## 5. Recommended technology

Use only Apple frameworks in the MVP:

| Concern | Technology |
|---|---|
| Interface | SwiftUI |
| Camera capture | AVFoundation |
| Face detection and landmarks | Vision |
| Face crop feature representation | Vision image feature prints initially |
| Image processing | Core Image |
| Local secret storage | Keychain Services |
| Settings | UserDefaults for non-sensitive tuning values only |
| Concurrency | Swift structured concurrency and dedicated capture/analysis queues |
| Tests | XCTest |

Do not add third-party dependencies unless a native Apple API proves inadequate.
If a dedicated Core ML face-embedding model is later introduced, document its
source, license, model size, accuracy, and privacy behavior.

## 6. User experience

### 6.1 First launch

1. Show a short explanation:
   - Processing happens on the Mac.
   - No photo is stored.
   - This does not replace the real Mac lock screen.
2. Ask for camera permission only after the explanation is visible.
3. If permission is denied, show a button that opens the relevant System
   Settings page and explain how to enable access.

### 6.2 Face enrolment

1. Display a live camera preview with an oval positioning guide.
2. Require one clearly visible face.
3. Reject enrolment if:
   - No face is visible.
   - Multiple faces are visible.
   - The face is too small or too close to the frame edge.
   - Lighting or blur is clearly inadequate.
4. Capture several samples while the user looks forward and turns slightly left
   and right.
5. Show progress such as `1 of 5`, not raw technical measurements.
6. Save only derived face representations in Keychain.
7. Discard all captured image buffers after processing.
8. Confirm successful enrolment and allow the user to delete and repeat it.

### 6.3 Simulated lock

1. User selects **Try safe lock**.
2. Present a full-screen SwiftUI view containing:
   - Current time and date.
   - Circular camera preview.
   - Recognition state.
   - A clear **Exit safe lock** control.
   - A small notice that this is a prototype.
3. State sequence:
   - `Looking for a face`
   - `Face found`
   - `Blink once`
   - `Checking locally`
   - `Unlocked` or `Not recognized`
4. On success, play a restrained animation and dismiss the simulated lock after
   roughly 700–1,000 milliseconds.
5. After repeated failure, keep the exit control available. Never trap the user.

## 7. Recognition design

### 7.1 Frame processing

- Capture frames using `AVCaptureSession` and `AVCaptureVideoDataOutput`.
- Process at approximately 4–6 analysis frames per second rather than every
  camera frame.
- Run Vision work away from the main thread.
- Publish only UI state back to the main actor.
- Correctly account for the front camera's orientation and mirrored preview.
- Detect all faces and continue only when exactly one valid face exists.
- Add proportional padding around the detected face before creating a feature
  representation.

### 7.2 Enrolment samples

Store multiple feature samples rather than relying on a single frame. Start with
five samples:

1. Straight ahead.
2. Slightly left.
3. Slightly right.
4. Straight ahead with a natural expression.
5. A final high-quality straight-ahead sample.

Before accepting each sample, require a stable face position for several
consecutive analysis frames. Do not store nearly identical samples taken from
the same instant.

### 7.3 Matching

- Compare the current feature representation with each enrolled sample.
- Use the median or average of the best three distances to reduce outliers.
- Keep the threshold configurable in a developer-only tuning panel.
- Do not label a derived score as a scientific probability.
- Display a friendly confidence indicator only for debugging builds.
- Record no face images or recognition history.

The initial threshold must be treated as provisional. Calibrate it on the target
M4 Mac using genuine attempts across different lighting and simple impostor
attempts. Prefer false rejection over false acceptance.

## 8. Blink liveness check

Use Vision face landmarks to estimate whether both eyes are open or closed. A
successful blink should follow this state machine:

```text
open for consecutive frames
    -> closed for consecutive frames
    -> open again for consecutive frames
    -> liveness passed
```

Requirements:

- Start the challenge only after a stable, matching face is present.
- Require both eyes when landmarks are available.
- Use consecutive-frame confirmation to avoid landmark noise.
- Add a reasonable timeout and restart the challenge when it expires.
- Reset liveness whenever the face disappears or a different face is detected.
- Never unlock because of a blink alone; matching and liveness must both pass.

Later improvements may randomize the challenge between blink, turn left, turn
right, or smile. Do not add those to the first milestone unless the basic blink
flow is reliable.

## 9. Local storage and privacy

Sensitive face representations must be archived and stored through Keychain
Services with a device-only accessibility class. Do not write them to:

- `UserDefaults`
- Plain JSON, plist, or SQLite files
- Logs
- Crash messages
- Analytics
- Clipboard

Recommended Keychain accessibility:

`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`

Provide a **Reset face profile** action that permanently deletes the Keychain
item. Keep matching tolerance and onboarding completion in `UserDefaults`, as
these are not biometric representations.

Add `NSCameraUsageDescription` with plain language explaining local face
matching. Enable only the camera sandbox entitlement needed by the app.

## 10. Architecture

Use small components with clear ownership:

| Component | Responsibility |
|---|---|
| `AppModel` | Top-level navigation and app state |
| `CameraService` | Permission, capture session, frame delivery |
| `FaceAnalyzer` | Face detection, quality checks, crop, landmarks |
| `FeaturePrintService` | Feature creation and distance calculation |
| `LivenessDetector` | Blink state machine and timeout |
| `FaceProfileStore` | Keychain save, load, and delete |
| `EnrollmentViewModel` | Enrolment workflow and sample collection |
| `UnlockViewModel` | Match policy and simulated unlock state |
| `CameraPreview` | `AVCaptureVideoPreviewLayer` bridge to SwiftUI |
| `PrototypeLockView` | Full-screen safe-lock experience |

Keep AVFoundation capture logic separate from Vision analysis so it can be
tested and changed independently. The view models should consume semantic
results such as `noFace`, `multipleFaces`, `poorQuality`, or `validFace`, not raw
Vision request objects.

## 11. Suggested project structure

```text
GlanceUnlock/
├── GlanceUnlock.xcodeproj
├── GlanceUnlock/
│   ├── App/
│   │   ├── GlanceUnlockApp.swift
│   │   └── AppModel.swift
│   ├── Camera/
│   │   ├── CameraService.swift
│   │   └── CameraPreview.swift
│   ├── Recognition/
│   │   ├── FaceAnalyzer.swift
│   │   ├── FeaturePrintService.swift
│   │   ├── FaceQuality.swift
│   │   └── LivenessDetector.swift
│   ├── Storage/
│   │   └── FaceProfileStore.swift
│   ├── Enrollment/
│   │   ├── EnrollmentView.swift
│   │   └── EnrollmentViewModel.swift
│   ├── Unlock/
│   │   ├── PrototypeLockView.swift
│   │   └── UnlockViewModel.swift
│   ├── Shared/
│   │   ├── DesignSystem.swift
│   │   └── StatusPill.swift
│   ├── Resources/
│   │   └── Assets.xcassets
│   ├── Info.plist
│   └── GlanceUnlock.entitlements
├── GlanceUnlockTests/
│   ├── LivenessDetectorTests.swift
│   ├── MatchPolicyTests.swift
│   └── FaceProfileStoreTests.swift
└── README.md
```

## 12. Implementation milestones

### Milestone 0 — Project foundation

- Create a macOS SwiftUI app.
- Set deployment target compatible with the M4 Air and Tahoe 26.6.
- Configure camera usage description and camera sandbox entitlement.
- Add a dark, minimal visual system.
- Add README safety and privacy notes.

Definition of done: the app builds, launches, and shows the initial screen on the
target Mac without warnings caused by project configuration.

### Milestone 1 — Camera and face guidance

- Implement camera permission handling.
- Show a mirrored front-camera preview.
- Detect zero, one, or multiple faces.
- Add face size, centering, and basic quality guidance.
- Throttle Vision analysis.

Definition of done: UI state reliably follows the camera scene, and denied
permission has a complete recovery path.

### Milestone 2 — Enrolment and storage

- Generate feature representations from normalized face crops.
- Collect five stable enrolment samples.
- Archive and save them in Keychain.
- Load them on the next launch.
- Implement deletion and re-enrolment.

Definition of done: no image is persisted, the profile survives app restart, and
reset removes it.

### Milestone 3 — Recognition

- Compare live features with enrolled samples.
- Implement a separate match policy with a configurable threshold.
- Stabilize the decision across multiple frames.
- Reset state correctly when the face disappears.
- Add developer diagnostics that contain no biometric data.

Definition of done: the enrolled user passes under reasonable lighting while a
small set of other people and printed-photo attempts are rejected during manual
testing.

### Milestone 4 — Blink liveness

- Implement and unit-test the blink state machine.
- Require open, closed, and reopened states across consecutive frames.
- Add timeout and reset behavior.
- Combine the result with face matching.

Definition of done: a still photograph cannot complete the basic challenge, and
a natural blink works consistently for the enrolled user.

### Milestone 5 — Safe lock experience

- Add a full-screen simulated lock screen.
- Display clock, date, camera state, and clear instructions.
- Animate successful unlock.
- Keep an always-available exit control.
- Test window resizing, full screen, camera interruption, sleep, and resume.

Definition of done: the complete enrol → safe lock → blink → unlock flow feels
cohesive and does not alter system authentication.

### Milestone 6 — Hardening and polish

- Add unit tests for matching policy, liveness transitions, timeouts, and reset.
- Add privacy-focused logging rules.
- Verify the main thread remains responsive.
- Verify camera buffers are not retained unnecessarily.
- Test without network access.
- Run static analysis and resolve all actionable warnings.

## 13. Acceptance criteria

The MVP is complete when:

- [ ] It builds and runs natively on the M4 MacBook Air with macOS Tahoe 26.6.
- [ ] Camera permission is requested with a clear explanation.
- [ ] Denied permission can be recovered without reinstalling the app.
- [ ] Zero, one, and multiple faces produce distinct states.
- [ ] Five face samples can be enrolled.
- [ ] Only derived representations are stored.
- [ ] The face profile persists after restarting the app.
- [ ] Reset deletes the stored profile.
- [ ] Recognition requires several consistent frames.
- [ ] Blink liveness requires open → closed → open.
- [ ] Recognition and liveness are both required for success.
- [ ] A still photo does not unlock during basic manual testing.
- [ ] The simulated lock always has an exit path.
- [ ] No network request is made.
- [ ] No real macOS authentication component is modified.
- [ ] The README clearly describes the limitations.

## 14. Testing plan

### Automated tests

Test logic independently from the physical camera:

- Liveness state changes only for the correct sequence.
- A one-frame landmark error does not count as a blink.
- Liveness expires and resets.
- Loss of face resets liveness.
- Match policy accepts values below the configured distance threshold.
- Match policy rejects values above the threshold.
- Multiple samples use the documented aggregation method.
- Keychain save, load, replacement, and deletion report errors correctly.

Do not put real face representations in the source repository. Use fabricated
distance values and protocol-based test doubles.

### Manual test matrix

Test the enrolled user with:

- Daylight and indoor evening lighting.
- Glasses on and off, if applicable.
- Face roughly 45–75 cm from the camera.
- Slight left and right angles.
- Normal expression.

Test rejection with:

- At least two other people.
- A printed photo.
- A photo displayed on a phone.
- No face.
- Two faces.
- Covered camera.

Record only pass/fail and feature distance ranges. Do not save test camera frames.

## 15. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Printed-photo spoof | Require blink liveness; clearly label remaining limitations |
| Replay-video spoof | Later randomize challenges; do not claim production security |
| False acceptance | Use conservative threshold and multi-frame consensus |
| False rejection | Capture varied enrolment samples and provide careful tuning |
| UI freezes | Throttle analysis and keep Vision off the main actor |
| Sensitive data leakage | Keychain-only embeddings, no image persistence, privacy-safe logs |
| Camera permission failure | Explicit denied state and System Settings recovery action |
| User thinks Mac is truly locked | Persistent prototype label and always-visible exit control |
| Future API changes | Isolate Vision and AVFoundation behind app-owned protocols |

## 16. Development rules

1. Complete milestones in order.
2. Keep the app buildable after every milestone.
3. Before editing, inspect the current project and preserve unrelated changes.
4. Use native Apple frameworks first.
5. Do not weaken macOS security or leave the safe-prototype boundary.
6. Never invent an Apple API; confirm symbols against the locally installed SDK.
7. Do not silence concurrency, camera, or Keychain errors without addressing them.
8. Keep UI updates on the main actor.
9. Keep capture and Vision processing off the main actor.
10. Add tests when introducing policy or state-machine logic.
11. Run the build and tests after each meaningful group of edits.
12. If Xcode reports an unavailable or changed Tahoe API, inspect the SDK and
    adapt the implementation instead of lowering safety requirements.
13. Stop and ask before adding third-party code, changing the storage design, or
    attempting real system-lock integration.

## 17. Initial implementation brief

Use the following implementation brief together with this specification:

```text
Build the Glance Unlock safe prototype described in GLANCE_UNLOCK_BUILD_SPEC.md.

Target my M4 MacBook Air running macOS Tahoe 26.6 and use the locally installed
Xcode SDK as the source of truth. Create a native SwiftUI macOS app using
AVFoundation, Vision, Core Image, Keychain Services, and XCTest. Do not use any
third-party dependency unless you stop and get my approval first.

Start with Milestone 0 and continue through the milestones in order. Keep the
project buildable after every milestone. Run builds and tests locally, resolve
warnings that affect correctness, and make small coherent commits if this
directory is a Git repository.

Respect the safety boundary absolutely: this is an in-app simulated lock. Do not
modify the macOS login window, authorization database, PAM configuration,
FileVault, System Integrity Protection, or any system authentication component.
Never request or store my Mac password.

Store only derived face representations in Keychain and never persist camera
frames. Structure camera capture, face analysis, feature matching, liveness, and
storage as separate components. Implement multiple-sample enrolment, conservative
multi-frame matching, and an open → closed → open blink state machine. Include an
always-available Exit safe lock action.

Before writing code, inspect this specification and produce a concise task list
mapped to its milestones. Then implement the project rather than only explaining
it. At the end, show build/test results, remaining limitations, and exact manual
steps for running and calibrating it on my Mac.
```

## 18. Possible version 2 work

Only after the MVP is reliable:

- Random liveness challenges.
- Better passive spoof detection using a reviewed Core ML model.
- Menu-bar mode and configurable automatic presentation.
- Recognition calibration dashboard with privacy-safe aggregate measurements.
- Multiple local profiles, if there is a clear user need.
- Signed and notarized distribution.

Research into a real macOS lock-screen authorization plug-in must be a separate
project phase with a second administrator account, tested recovery procedure,
signed installer/uninstaller, OS-version compatibility matrix, and independent
security review. It is intentionally outside this document's implementation
scope.
