#!/bin/bash
# Archive, sign, notarize and staple a distributable Scope.app, then zip it for release.
#
# This is the single source of truth for how a Scope build is cut. CI calls it with the same
# arguments a person would, so a release can always be produced from a laptop, and notarization
# problems can be debugged interactively instead of through push cycles.
#
# Credentials, all required:
#   - A "Developer ID Application" identity in the keychain.
#   - A Developer ID provisioning profile for com.tylerdailey.Scope with iCloud (CloudKit)
#     enabled, installed in ~/Library/MobileDevice/Provisioning Profiles. Scope's entitlements
#     include iCloud and push, which are restricted: without a profile that grants them the
#     signed app is killed at launch. SCOPE_PROFILE_NAME is the profile's name.
#   - An App Store Connect API key: AC_API_KEY_ID, AC_API_ISSUER_ID, AC_API_KEY_PATH (a .p8 file).
#     Alternatively, set AC_KEYCHAIN_PROFILE to a profile stored with
#     xcrun notarytool store-credentials
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

# The version is the next unused patch in VERSION's series (see Scripts/Version.sh). CI passes
# SCOPE_VERSION when a pushed tag has already chosen it.
version="${SCOPE_VERSION:-$(Scripts/Version.sh)}"
# The build number must increase with every build a tester can install. Commit count is
# monotonic and needs no state.
build="${SCOPE_BUILD_NUMBER:-$(git rev-list --count HEAD)}"
output="${SCOPE_OUTPUT_DIR:-$repo_root/.build/release}"
archive="$output/Scope.xcarchive"
export_dir="$output/export"
export_options="$output/ExportOptions.plist"
app="$export_dir/Scope.app"
zip="$output/Scope-$version.zip"

: "${SCOPE_PROFILE_NAME:?set SCOPE_PROFILE_NAME to the name of the installed Developer ID provisioning profile}"
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo 'No "Developer ID Application" identity in the keychain. Create one at' >&2
    echo 'developer.apple.com → Certificates, and install it before releasing.' >&2
    exit 1
fi

team="$(sed -nE 's/.*DEVELOPMENT_TEAM = ([A-Z0-9]+);.*/\1/p' Scope.xcodeproj/project.pbxproj | head -1)"
bundle_id="com.tylerdailey.Scope"

echo "==> Scope $version ($build)"
rm -rf "$output"
mkdir -p "$output"

cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>$bundle_id</key>
		<string>$SCOPE_PROFILE_NAME</string>
	</dict>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
PLIST

echo "==> Archiving"
xcodebuild archive \
    -project Scope.xcodeproj \
    -scheme Scope \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$archive" \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$team" \
    PROVISIONING_PROFILE_SPECIFIER="$SCOPE_PROFILE_NAME" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

echo "==> Exporting"
xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$export_options" \
    -exportPath "$export_dir"

echo "==> Verifying the signature before asking Apple to look at it"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dv --verbose=4 "$app" 2>&1 | grep -E "Authority|TeamIdentifier|Timestamp|flags" || true

echo "==> Notarizing"
ditto -c -k --keepParent "$app" "$zip"
auth=()
if [[ -n "${AC_KEYCHAIN_PROFILE:-}" ]]; then
    auth=(--keychain-profile "$AC_KEYCHAIN_PROFILE")
else
    : "${AC_API_KEY_ID:?set AC_API_KEY_ID or AC_KEYCHAIN_PROFILE}"
    : "${AC_API_ISSUER_ID:?set AC_API_ISSUER_ID}"
    : "${AC_API_KEY_PATH:?set AC_API_KEY_PATH}"
    auth=(--key "$AC_API_KEY_PATH" --key-id "$AC_API_KEY_ID" --issuer "$AC_API_ISSUER_ID")
fi

# JSON rather than the human output: the id is needed to fetch Apple's reasons on a rejection.
result="$(xcrun notarytool submit "$zip" "${auth[@]}" --wait --timeout 30m --output-format json)"
echo "$result"
status="$(printf '%s' "$result" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')"
submission="$(printf '%s' "$result" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))')"
if [[ "$status" != "Accepted" ]]; then
    echo "==> Notarization failed with status: ${status:-unknown}. Apple's reasons:" >&2
    [[ -n "$submission" ]] && xcrun notarytool log "$submission" "${auth[@]}" >&2 || true
    exit 1
fi

echo "==> Stapling"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
# What a user's Mac will actually decide when they double-click it.
spctl --assess --type execute --verbose=4 "$app"

# Re-zip: the notarized ticket is stapled into the app, not into the zip that was uploaded.
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

echo
echo "==> Scope $version ($build) is notarized and stapled"
echo "    $zip"
