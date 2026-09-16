#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

release_version="$(plutil -extract CFBundleShortVersionString raw GlanceUnlock/Info.plist)"
release_dmg="$project_root/dist/GlanceUnlock-${release_version}-arm64.dmg"

if [ -e "$release_dmg" ]; then
  echo "An existing DMG is at $release_dmg. Move it or update the app version before rebuilding." >&2
  exit 1
fi

mkdir -p dist
release_staging="$(mktemp -d)"
trap 'rm -rf "$release_staging"' EXIT

echo "Building an ad-hoc-signed Release app for Apple silicon..."
if ! xcodebuild \
  -project GlanceUnlock/GlanceUnlock.xcodeproj \
  -scheme GlanceUnlock \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$project_root/dist/DerivedData" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build > "$project_root/dist/build.log" 2>&1; then
  tail -n 60 "$project_root/dist/build.log" >&2
  exit 1
fi

release_app="$project_root/dist/DerivedData/Build/Products/Release/GlanceUnlock.app"
codesign --verify --deep --strict --verbose=2 "$release_app"
lipo -archs "$release_app/Contents/MacOS/GlanceUnlock"

ditto "$release_app" "$release_staging/GlanceUnlock.app"
ln -s /Applications "$release_staging/Applications"
cat > "$release_staging/INSTALL.txt" <<'INSTALL'
Glance Unlock — Apple silicon preview for macOS 26.0 or later

This build is ad-hoc signed. It is not signed with Developer ID and has not
been notarized by Apple.

1. Drag GlanceUnlock.app into Applications.
2. Open Glance Unlock from Applications.
3. If macOS blocks it, approve it only if you trust the release source:
   System Settings > Privacy & Security > Open Anyway, then confirm opening.
   Managed Macs may prohibit this exception.
4. Allow camera access, enrol your face, and choose protected apps.

Glance stays in the menu bar without a Dock icon. Closing its main window
keeps monitoring active; quitting Glance stops it. Launch at Login needs
manual validation on this unnotarized build; if unavailable, open Glance
manually after signing in.

This is a privacy-layer prototype, not a macOS lock-screen replacement.
Quitting the app bypasses its protection.

Source and documentation:
https://github.com/Shivam1303/glance-unlock-mac
INSTALL

hdiutil create -volname "Glance Unlock" \
  -srcfolder "$release_staging" -format UDZO "$release_dmg"
hdiutil verify "$release_dmg"

(cd "$project_root/dist" && shasum -a 256 "$(basename "$release_dmg")" > SHA256SUMS.txt)
echo "DMG: $release_dmg"
echo "Checksum: $project_root/dist/SHA256SUMS.txt"
echo "This build is ad-hoc signed and unnotarized. Test installation before publishing."
