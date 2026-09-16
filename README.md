# Glance Unlock

Glance Unlock is a native macOS **privacy-layer prototype** that can hide selected apps and ask for local face-and-blink verification before restoring them. Apple’s standard Touch ID, Apple Watch, or Mac password dialog is always available as a fallback. It is not a replacement for the macOS lock screen or Apple Face ID.

## Documentation

- [User guide](USER_GUIDE.md): install, enrol, use, reset, and troubleshoot the prototype.
- [Project checklist](PROJECT_CHECKLIST.md): implemented features, validation work, and planned follow-up.
- [Build specification](GLANCE_UNLOCK_BUILD_SPEC.md): original MVP requirements and safety boundary.

## Safety and privacy

- The app never reads, requests, stores, or types a Mac password.
- It does not modify the login window, Authorization database, PAM, FileVault, SIP, or any system authentication component.
- Camera frames are processed in memory and discarded. They are never written to disk, logs, analytics, clipboard, or a network service.
- Only derived Vision feature-print representations are stored securely in Keychain. Team-signed builds use the device-only Data Protection Keychain (`AfterFirstUnlockThisDeviceOnly`); local ad-hoc Xcode builds use the encrypted macOS login Keychain because they have no Keychain access-group entitlement.
- The app gate requires successful authentication and always exposes **Use Touch ID or Password**. There is no cancel/back action on the gate; cancelling the macOS dialog returns to the locked gate.
- App protection works only while Glance is running. Quitting Glance disables monitoring, and selected apps can still be reopened normally.
- Glance runs in the menu bar without a Dock icon. Choose **Open Glance** from the menu bar to open its main window; protection remains running when the window is closed. Launch at Login uses macOS Service Management and may require approval under System Settings → General → Login Items.

## Build and run

1. Open `GlanceUnlock/GlanceUnlock.xcodeproj` in Xcode 26.6.
2. Select the `GlanceUnlock` scheme and **My Mac**, then choose Run.
3. To run automated checks, choose Product → Test, or run `xcodebuild test` from Terminal.

The native arm64 Debug build and XCTest suite pass with Xcode 26.6.

## Quick use

1. Choose **Set up face profile** and approve camera access after reading the local-processing explanation.
2. Capture five samples, changing your head angle slightly between samples.
3. Select **Manage Protected Apps**, turn on app protection, and enable it for the apps you want to cover.
4. Optionally enable **Launch at Login** so Glance is available automatically after you sign in.
5. Close the Glance window if desired; protection and the menu-bar control remain running.
6. Switch to a selected app. Look toward the camera and blink when prompted, or choose **Use Touch ID or Password**.
7. The gate stays in place until face-and-blink or macOS authentication succeeds.

See the [user guide](USER_GUIDE.md) for calibration, reset, and troubleshooting details.

## Limitations

An ordinary MacBook RGB camera has no TrueDepth infrared/depth hardware. A blink check can be fooled by replay video, a high-quality display, or a sophisticated mask. App hiding is cooperative and can be bypassed by quitting Glance. This project is an offline privacy convenience, not a security boundary; it cannot unlock macOS after boot or decrypt FileVault.
