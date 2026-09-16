# Glance Unlock

**Face-and-blink verification for selected Mac apps. Local processing. A quiet menu-bar presence.**

Glance Unlock is a native SwiftUI macOS app that hides selected applications and asks for face-and-blink verification before restoring them. You can also authenticate through the standard macOS **Use Touch ID or Password** dialog.

> Glance is a privacy-layer prototype. It does not replace the macOS lock screen, Apple Face ID, or FileVault. Protection works only while Glance is running and can be bypassed by quitting it.

[Releases](https://github.com/Shivam1303/glance-unlock-mac/releases) · [User guide](USER_GUIDE.md) · [Release guide](RELEASING.md) · [Report an issue](https://github.com/Shivam1303/glance-unlock-mac/issues)

## Features

- **Protect selected apps** — choose which applications should ask for verification when you switch to them.
- **Face matching and blink checks** — enrol five face samples, then verify a consistent match followed by a natural blink.
- **macOS authentication fallback** — use Touch ID or Password through a system-owned dialog.
- **Menu-bar controls** — open Glance, manage apps, pause or resume protection, and quit. No Dock icon.
- **Optional Launch at Login** — keep Glance available after signing in, subject to macOS approval.
- **Local face-profile storage** — derived face representations live in Keychain; camera photos and video are never saved.
- **Face Check demo** — try verification in a simulated lock view with an exit control.

## Requirements

| Requirement | Details |
| --- | --- |
| Operating system | macOS Tahoe 26.0 or later |
| Hardware | Apple silicon Mac; development validated on an M4 MacBook Air |
| Camera | Built-in or compatible camera, with camera access allowed |
| Building from source | Xcode 26.6 and its macOS SDK |

Intel Macs have not been validated. Check the release notes for the architecture included in each downloadable build.

## Download and install

1. Open [Releases](https://github.com/Shivam1303/glance-unlock-mac/releases) and select a release containing a `.dmg` asset.
2. Download and open the DMG, then drag **GlanceUnlock.app** into **Applications**.
3. Launch Glance Unlock from Applications and allow camera access when prompted.
4. After setup, use the face icon in the menu bar to reopen Glance.

If no DMG is listed, use the source-build instructions below. GitHub's automatically generated source archives are not installable app builds.

## First-time setup

1. Choose **Set up face profile** and read the explanation of local camera processing.
2. Capture five samples in even lighting, making small head turns between samples.
3. Open **Manage Protected Apps**, enable protection, and select the applications to cover.
4. Optionally enable **Launch at Login**. Approve Glance in **System Settings → General → Login Items** if requested.
5. Switch to a protected app, look toward the camera, and blink when prompted. You can choose **Use Touch ID or Password** instead.

Closing Glance's main window keeps protection running. **Quit Glance** stops monitoring. Switching away from a verified app relocks it.

See the [user guide](USER_GUIDE.md) for camera-permission recovery, calibration, and resetting your face profile.

## Privacy and security

- Camera frames are processed in memory and discarded. They are never saved as photos or video.
- Face matching runs locally with Apple frameworks. The app has no network client or analytics.
- Only derived Vision feature-print representations are stored in Keychain. The app uses the device-only Data Protection Keychain where signing entitlements permit it, with an encrypted login-Keychain fallback for local ad-hoc builds.
- Glance never reads, requests, stores, or types your Mac password. The authentication fallback is handled entirely by macOS.
- The app does not modify the login window, PAM, Authorization database, FileVault, SIP, or other system authentication components.
- You can remove the stored profile using **Reset face profile**.

An ordinary RGB camera has no TrueDepth infrared or depth hardware. Replay videos, high-quality displays, or sophisticated masks may defeat the blink check. Cooperative app hiding is not a tamper-resistant security boundary. Use normal macOS locking for device security.

## Build from source

```bash
git clone https://github.com/Shivam1303/glance-unlock-mac.git
cd glance-unlock-mac
open GlanceUnlock/GlanceUnlock.xcodeproj
```

In Xcode, select the **GlanceUnlock** scheme and **My Mac**, then choose **Product → Run**. Debug builds use local ad-hoc signing. A public release needs Developer ID signing and notarization; see the [release guide](RELEASING.md).

To run the unit tests, choose **Product → Test**, or run:

```bash
xcodebuild test \
  -project GlanceUnlock/GlanceUnlock.xcodeproj \
  -scheme GlanceUnlock \
  -destination 'platform=macOS,arch=arm64'
```

The tests cover matching policy, blink detection, and face-profile storage behavior. Real camera, lighting, spoofing, and application-protection scenarios also require manual testing.

## Documentation

- [User guide](USER_GUIDE.md) — enrolment, protected apps, permissions, and troubleshooting.
- [Release guide](RELEASING.md) — sign, package, notarize, and publish a DMG.
- [Project checklist](PROJECT_CHECKLIST.md) — completed work and remaining validation.
- [Build specification](GLANCE_UNLOCK_BUILD_SPEC.md) — original requirements and prototype boundaries.

## Feedback

[Open an issue](https://github.com/Shivam1303/glance-unlock-mac/issues) with your macOS version, Mac model, app version, and steps to reproduce. Do not include camera images, face-profile data, passwords, or signing credentials.

Maintained by [Shivam1303](https://github.com/Shivam1303).
