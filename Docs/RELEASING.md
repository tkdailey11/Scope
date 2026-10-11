# Releasing Scope

Scope is distributed directly (Developer ID, notarized, App Sandbox off). A release is cut by
`Scripts/Release.sh`; the GitHub workflow only supplies credentials and publishes the zip.

## Versions

`VERSION` holds the `major.minor` series. The patch number is the next unused tag in that series
(`Scripts/Version.sh`), and the build number is the commit count.

## Cutting a release

- **From GitHub:** run the *Release* workflow (Actions → Release → Run workflow). It tags the next
  version and creates a draft release; untick *draft* to publish immediately.
- **From a tag:** push `v1.0.N`. The tag must belong to the series in `VERSION`.
- **From a laptop:** `SCOPE_PROFILE_NAME="<profile name>" AC_KEYCHAIN_PROFILE=<profile> Scripts/Release.sh`.

## One-time setup

Secrets go in a GitHub environment named **Prod** (Settings → Environments).

| Secret | What it is |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | "Developer ID Application" certificate exported as .p12, base64-encoded |
| `P12_PASSWORD` | Password used when exporting the .p12 |
| `KEYCHAIN_PASSWORD` | Any throwaway password for the CI keychain |
| `PROVISIONING_PROFILE_BASE64` | Developer ID provisioning profile for `com.tylerdailey.Scope` with iCloud (CloudKit) and Push, base64-encoded |
| `AC_API_KEY_ID`, `AC_API_ISSUER_ID`, `AC_API_KEY_BASE64` | App Store Connect API key (.p8, base64-encoded) used by `notarytool` |

Encode a file with `base64 -i file | pbcopy`.

### Why a provisioning profile

Scope's entitlements include iCloud/CloudKit and push. Those are restricted entitlements, so a
Developer ID build only launches if it is signed with a profile that grants them. Create the
profile at developer.apple.com → Profiles → *Developer ID* for the Scope App ID, with iCloud
(container `iCloud.com.tylerdailey.Scope`) enabled.

The entitlements file currently says `aps-environment = development`. If notarized builds
misbehave with push or CloudKit, check that the exported app's entitlements say `production`.
