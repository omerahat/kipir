#!/bin/bash
# Developer ID distribution path for Kıpır (maintainer only).
#
#   KIPIR_DEVELOPER_ID="Developer ID Application: Name (TEAMID)" \
#   KIPIR_NOTARY_PROFILE="<notarytool keychain profile>" \
#   bash Scripts/release-developer-id.sh [--notarize]
#
# Without --notarize everything stays local: universal Release build, Developer ID
# signature with secure timestamp and hardened runtime, verification, and a ZIP named
# dist/Kipir-<version>-unnotarized.zip that must NOT be distributed.
#
# WARNING: with --notarize the script UPLOADS the signed archive to Apple's notary
# service (xcrun notarytool submit), then staples and runs a Gatekeeper assessment.
# Only the maintainer, with explicit authorization, may pass --notarize. The
# notarytool keychain profile is created beforehand by the maintainer with
# `xcrun notarytool store-credentials`; this script never handles Apple ID passwords.
#
# Project signing settings and Config.xcconfig are never edited; the identity is
# supplied through xcodebuild command-line overrides only.
set -euo pipefail
cd "$(dirname "$0")/.."

notarize=0
case $# in
  0) ;;
  1) if [[ "$1" == "--notarize" ]]; then notarize=1; else
       echo "Usage: bash Scripts/release-developer-id.sh [--notarize]" >&2; exit 1; fi ;;
  *) echo "Usage: bash Scripts/release-developer-id.sh [--notarize]" >&2; exit 1 ;;
esac

if [[ -z "${KIPIR_DEVELOPER_ID:-}" || -z "${KIPIR_NOTARY_PROFILE:-}" ]]; then
  cat >&2 <<'MSG'
BLOCKED: Developer ID release prerequisites are missing. Nothing was built.
  - Apple Developer Program membership (paid).
  - A "Developer ID Application" certificate with its private key in the login keychain.
  - A notarytool keychain profile: xcrun notarytool store-credentials <profile-name>
  - Xcode and its command line tools.
  - Environment variables:
      KIPIR_DEVELOPER_ID      e.g. "Developer ID Application: Name (TEAMID)"
      KIPIR_NOTARY_PROFILE    the notarytool keychain profile name
See DISTRIBUTION.md.
MSG
  exit 2
fi
if [[ "$KIPIR_DEVELOPER_ID" != "Developer ID Application: "* ]]; then
  echo "BLOCKED: KIPIR_DEVELOPER_ID must be a 'Developer ID Application: ...' identity (Apple Development identities cannot be notarized for distribution)." >&2
  exit 2
fi

version=$(sed -nE 's/^MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' Config.xcconfig)
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Config.xcconfig must contain a three-part MARKETING_VERSION." >&2
  exit 1
fi
final_archive="dist/Kipir-${version}.zip"
local_archive="dist/Kipir-${version}-unnotarized.zip"
for existing in "$final_archive" "${final_archive}.sha256" "$local_archive"; do
  if [[ -e "$existing" ]]; then
    echo "Refusing to overwrite $existing. Bump the version or move the previous artifact first." >&2
    exit 1
  fi
done

identities=$(security find-identity -v -p codesigning 2>/dev/null || true)
if ! grep -qF "\"$KIPIR_DEVELOPER_ID\"" <<<"$identities"; then
  echo "BLOCKED: signing identity not found in the keychain (security find-identity -v -p codesigning). Nothing was built." >&2
  exit 2
fi

mkdir -p dist build
derived="build/developer-id"
log="build/release-developer-id.log"
xcodebuild -project Kipir.xcodeproj -scheme Kipir -configuration Release \
  -derivedDataPath "$derived" COMPILER_INDEX_STORE_ENABLE=NO ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="$KIPIR_DEVELOPER_ID" CODE_SIGN_STYLE=Manual CODE_SIGNING_ALLOWED=YES \
  OTHER_CODE_SIGN_FLAGS=--timestamp ENABLE_HARDENED_RUNTIME=YES \
  build > "$log" 2>&1 || { echo "Build failed; see $log" >&2; exit 1; }
app="$derived/Build/Products/Release/Kipir.app"

/usr/bin/codesign --verify --deep --strict "$app"
details=$(/usr/bin/codesign -dvv "$app" 2>&1)
grep -qF "Authority=$KIPIR_DEVELOPER_ID" <<<"$details" || { echo "Signature does not carry the requested identity." >&2; exit 1; }
grep -Eq 'flags=0x[0-9a-f]+\(.*runtime' <<<"$details" || { echo "Hardened runtime flag missing from signature." >&2; exit 1; }
grep -q '^Timestamp=' <<<"$details" || { echo "Secure timestamp missing from signature." >&2; exit 1; }
entitlements=$(/usr/bin/codesign -d --entitlements - "$app" 2>&1 || true)
if grep -q 'get-task-allow' <<<"$entitlements"; then
  echo "Release signature carries get-task-allow; notarization would reject it." >&2
  exit 1
fi
/usr/bin/lipo "$app/Contents/MacOS/Kipir" -verify_arch arm64 x86_64
actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$actual_version" == "$version" ]] || { echo "Built version $actual_version differs from $version." >&2; exit 1; }

if [[ "$notarize" == 0 ]]; then
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$local_archive"
  printf 'Signed and verified %s locally. NOT notarized; do not distribute. Rerun with --notarize (maintainer only).\n' "$local_archive"
  exit 0
fi

# Everything below uploads to Apple and requires explicit maintainer authorization.
submit_zip="build/Kipir-${version}-notary-submit.zip"
rm -f "$submit_zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$submit_zip"
notary_log="build/notarytool-submit.log"
xcrun notarytool submit "$submit_zip" --keychain-profile "$KIPIR_NOTARY_PROFILE" --wait 2>&1 | tee "$notary_log"
grep -q 'status: Accepted' "$notary_log" || { echo "Notarization was not accepted; see $notary_log. No release archive was created." >&2; exit 1; }
xcrun stapler staple "$app"
xcrun stapler validate "$app"
assessment=$(/usr/sbin/spctl -a -vv -t exec "$app" 2>&1 || true)   # the greps below decide, not the exit status
printf '%s\n' "$assessment"
grep -q 'accepted' <<<"$assessment" || { echo "Gatekeeper assessment did not accept the stapled app." >&2; exit 1; }
grep -q 'Notarized Developer ID' <<<"$assessment" || { echo "Gatekeeper source is not Notarized Developer ID." >&2; exit 1; }
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "$final_archive"
sha256=$(/usr/bin/shasum -a 256 "$final_archive" | awk '{print $1}')
printf '%s  %s\n' "$sha256" "Kipir-${version}.zip" > "${final_archive}.sha256"
printf 'Notarized and stapled %s (SHA-256 %s). Update Casks/kipir.rb and its caveat per DISTRIBUTION.md; nothing was published.\n' "$final_archive" "$sha256"
