# Publishing a Glance Unlock DMG

There are two release routes. Run commands from the repository root. The current app version is `0.1`, and the first release tag is `v0.1`.

| Route | Apple membership | First launch |
| --- | --- | --- |
| Free preview with an ad-hoc signature | Not required | Users may need to approve the app in Privacy & Security |
| Developer ID signing and notarization | Paid Apple Developer Program | Apple can verify the publisher and notarization ticket |

Developer ID and notarization are benefits of the paid program; an ad-hoc signature requires no certificate. [Apple's membership comparison](https://developer.apple.com/support/compare-memberships/).

## Free preview: build and publish

### Build the DMG

```bash
bash scripts/build-dmg.sh
```

The script builds the Release configuration for arm64 with ad-hoc signing, preserves the sandbox and camera entitlements, verifies the app's code signature, and packages the app, an Applications shortcut, and installation instructions. It creates:

- `dist/GlanceUnlock-0.1-arm64.dmg`
- `dist/SHA256SUMS.txt`

Build logs are in `dist/build.log`. Build outputs are ignored by Git. If a DMG with the same version exists, move it before rebuilding or increment the version in `GlanceUnlock/Info.plist` for a new release. The script reads the version from that file.

An ad-hoc signature verifies code integrity but does not establish an Apple-verified publisher. This route has no notarization or stapling step. A Gatekeeper assessment rejection is expected for an unnotarized downloaded build; it is not the same as a failed code-signature integrity check.

### Test the installed build

1. Open the DMG and drag GlanceUnlock.app into Applications.
2. Launch the installed app.
3. If macOS blocks the app and you trust its source, open System Settings → Privacy & Security → Open Anyway, then confirm opening. This exception may be unavailable on managed Macs.
4. Test camera access, five-sample enrolment, app selection, face-and-blink verification, and Touch ID or Password fallback.
5. Close the main window and check that the menu-bar icon remains with no Dock icon. Test pause/resume and quitting.
6. Check Launch at Login on this installed build. If it fails, document that limitation and launch the app manually after signing in.

Reference: [Apple — opening apps safely](https://support.apple.com/102445).

### Publish the preview

1. Open [New release](https://github.com/Shivam1303/glance-unlock-mac/releases/new).
2. Create tag `v0.1` targeting the tested source commit on `main`.
3. Enter title **Glance Unlock 0.1 — Public Preview**.
4. Attach the DMG and checksum file listed above.
5. Paste the release notes below, mark the release as a pre-release, and save the draft.
6. Review the assets and notes, then choose Publish release.
7. Download the published DMG through a browser and repeat installation testing to check Gatekeeper's downloaded-app behavior.

```markdown
Glance Unlock 0.1 — initial public preview

Requires macOS Tahoe 26.0 or later and an Apple silicon Mac (arm64).
This release is ad-hoc signed and has not been notarized by Apple.

Features:
- Local face matching and blink verification for selected applications.
- Touch ID or Password fallback through macOS.
- Menu-bar controls with no Dock icon.
- Face-profile storage in Keychain; no saved camera photos or video.

Installation:
1. Download GlanceUnlock-0.1-arm64.dmg and drag the app into Applications.
2. Open Glance Unlock. If macOS blocks it, approve it only if you trust the
   source: System Settings > Privacy & Security > Open Anyway.
3. Allow camera access, enrol your face, and choose protected apps.

Launch at Login is not validated for this preview. Open Glance manually
at sign-in if it is unavailable.

This is a privacy-layer prototype, not a replacement for the macOS lock
screen, Apple Face ID, or FileVault. Quitting Glance disables protection.
```

Do not upload an ad-hoc preview as though it were Developer ID-signed or notarized. Commit source and documentation; attach the DMG as a release asset.

Reference: [GitHub — managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

## Optional paid route: Developer ID and notarization

The rest of this guide applies only if you later enroll and choose Developer ID signing. It uses `GlanceUnlock-0.1.dmg` as the output filename.

## 1. Set up signing

You need Apple Developer Program membership, Xcode, and a **Developer ID Application** certificate with its private key installed in your Mac's Keychain.

1. In Xcode Settings → Accounts, sign in to your Apple Developer account.
2. Use Manage Certificates to create a Developer ID Application certificate if your account role permits it; otherwise ask your team's Account Holder to provide signing access.
3. Open `GlanceUnlock/GlanceUnlock.xcodeproj` and select the GlanceUnlock target.
4. Under Signing & Capabilities, select your team for the Release configuration and enable automatic signing. Keep Hardened Runtime and the camera entitlement enabled.
5. Confirm the bundle identifier belongs to your team. If you choose a new identifier for the first public release, keep it stable for later releases.

Check the certificate's exact name:

```bash
security find-identity -v -p codesigning
```

The list must include **Developer ID Application**. A local ad-hoc signature is for development, not this release workflow.

Reference: [Apple — signing with Developer ID](https://developer.apple.com/developer-id/).

## 2. Archive and export the app

1. Check `CFBundleShortVersionString` and `CFBundleVersion` in `GlanceUnlock/Info.plist`. For later releases, update the version and increment the build number before archiving; commit those changes before creating the release tag.
2. Select the GlanceUnlock scheme and My Mac, then choose Product → Archive. The archive should use the Release configuration.
3. In Organizer, choose Distribute App → Direct Distribution and complete signing and notarization. Some Xcode workflows show Developer ID instead.
4. Export the resulting app into `dist` at the repository root.
5. Confirm the exported file is `dist/GlanceUnlock.app`.

Verify the exported app before packaging:

```bash
codesign --verify --deep --strict --verbose=2 "dist/GlanceUnlock.app"
spctl --assess --type execute --verbose=2 "dist/GlanceUnlock.app"
```

Both checks must succeed. Do not package the unsigned Debug app from DerivedData.

Reference: [Apple — creating distribution-signed code](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/).

## 3. Create and sign the DMG

Copy these commands into Terminal. Replace the certificate placeholder with the exact Developer ID Application identity from step 1.

```bash
mkdir -p dist

release_version="$(plutil -extract CFBundleShortVersionString raw dist/GlanceUnlock.app/Contents/Info.plist)"
release_bundle_id="$(plutil -extract CFBundleIdentifier raw dist/GlanceUnlock.app/Contents/Info.plist)"
release_dmg="dist/GlanceUnlock-${release_version}.dmg"
release_staging="$(mktemp -d)"

ditto "dist/GlanceUnlock.app" "$release_staging/GlanceUnlock.app"
ln -s /Applications "$release_staging/Applications"

hdiutil create \
  -volname "Glance Unlock" \
  -srcfolder "$release_staging" \
  -format UDZO \
  "$release_dmg"

codesign --timestamp \
  --sign "Developer ID Application: YOUR NAME (TEAM_ID)" \
  --identifier "${release_bundle_id}.dmg" \
  "$release_dmg"

codesign --verify --verbose=2 "$release_dmg"
hdiutil verify "$release_dmg"
```

The DMG contains the app and an Applications shortcut. These commands do not overwrite an existing DMG; use a new version or move the previous local output before repackaging. Keep the same Terminal session for the following commands so `release_dmg` remains set.

Reference: [Apple — packaging Mac software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).

## 4. Notarize and staple the DMG

Store your notarization credentials once, replacing the placeholders:

```bash
xcrun notarytool store-credentials "glance-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID"
```

Enter an app-specific password when prompted locally. This stores the credentials in Keychain. Keep passwords out of commands, commits, and release notes.

Submit the signed DMG:

```bash
xcrun notarytool submit "$release_dmg" \
  --keychain-profile "glance-notary" \
  --wait
```

Continue only after the result says **Accepted**. If it says Invalid, inspect the submission log and fix the reported issue before resubmitting:

```bash
xcrun notarytool log "SUBMISSION_ID" \
  --keychain-profile "glance-notary" \
  "dist/notarization-log.json"
```

After acceptance, attach the ticket and validate it:

```bash
xcrun stapler staple "$release_dmg"
xcrun stapler validate "$release_dmg"
spctl --assess --type open --context context:primary-signature \
  --verbose=2 "$release_dmg"

(cd dist && shasum -a 256 "$(basename "$release_dmg")" > SHA256SUMS.txt)
```

Notarizing the app during Xcode export does not replace submitting the final signed DMG. Generate the checksum after stapling, because stapling changes the DMG file.

Reference: [Apple — customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## 5. Test the installation

Before publishing, test on a separate Mac or a clean user account:

- Open the DMG and drag the app into Applications.
- Launch the installed app and confirm camera permission, enrolment, and protected-app verification.
- Confirm Touch ID or Password fallback works.
- Close the main window and confirm the menu-bar icon remains with no Dock icon.
- Confirm pause/resume, quitting, and Launch at Login behave as documented.
- Check that the installed app passes `spctl --assess --type execute --verbose=2 /Applications/GlanceUnlock.app`.
- Check the build's architecture using `lipo -archs dist/GlanceUnlock.app/Contents/MacOS/GlanceUnlock`. Document the result; do not claim Intel support without testing it.

After publishing, also test downloading the DMG through a browser and installing it. This checks the normal Gatekeeper path for downloaded software.

## 6. Publish on GitHub

1. Open [the repository's Releases page](https://github.com/Shivam1303/glance-unlock-mac/releases).
2. Choose Draft a new release.
3. Create tag `v0.1` targeting the tested commit on `main`. For later versions, match the app version.
4. Use title **Glance Unlock 0.1 — Public Preview**.
5. Attach `dist/GlanceUnlock-0.1.dmg` and `dist/SHA256SUMS.txt`.
6. Use the release notes below and mark this initial prototype release as a pre-release.
7. Save the draft, review its files, then choose Publish release.

```markdown
Glance Unlock 0.1 is an initial public preview for macOS Tahoe 26.0 or later.

Features:
- Local face matching and blink verification for selected applications.
- Touch ID or Password fallback through macOS.
- Menu-bar controls, no Dock icon, and optional Launch at Login.
- Derived face-profile storage in Keychain; no saved camera images or video.

Installation: download GlanceUnlock-0.1.dmg, open it, and drag GlanceUnlock.app
into Applications. Launch the app and allow camera access.

Architecture: REPLACE WITH THE VERIFIED BUILD ARCHITECTURE.

This is a privacy-layer prototype. It does not replace the macOS lock screen,
Apple Face ID, or FileVault. Quitting Glance disables app protection.
```

Replace the architecture placeholder before publishing. The DMG is a release asset, not a file to commit into Git. Share the Releases page linked above; it also lists pre-releases.

Reference: [GitHub — managing releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
