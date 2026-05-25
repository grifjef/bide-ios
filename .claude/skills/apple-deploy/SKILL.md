---
name: apple-deploy
description: TestFlight and App Store upload commands for Bide. Use when archiving and submitting builds to App Store Connect, generating App Store Connect API keys, or troubleshooting upload failures.
---

# apple-deploy

End-to-end deployment from local archive to TestFlight / App Store Connect.

## Prerequisites

1. **Paid Apple Developer Program** active for `grif.jef@gmail.com` ✅ (confirmed 2026-05-25)
2. **Apple Developer Team ID** — 10-char alphanumeric, from developer.apple.com/account/#MembershipDetailsCard
3. **App Store Connect API key** — see [Creating an API key](#creating-an-app-store-connect-api-key) below. Required for `xcrun altool` / `notarytool` / `fastlane`.
4. **App created in App Store Connect** with Bundle ID `com.bidephoto.bide`
5. **Xcode signed in** to the Apple ID with development certificate installed

## Creating an App Store Connect API key

1. Go to https://appstoreconnect.apple.com/access/api
2. Click **Generate API Key** (or **+**)
3. Name: `bide-ci`
4. Access: **App Manager** (sufficient for TestFlight + App Store submission)
5. Click **Generate**
6. Download the `.p8` file **immediately** — it's only available once
7. Note the **Key ID** (10-char) and **Issuer ID** (UUID)

Store the `.p8` securely:

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
```

**NEVER commit the .p8 to git.** Our `.gitignore` excludes `AuthKey_*.p8` by default.

For CI uploads, store the same data in GitHub Actions secrets:
- `APP_STORE_CONNECT_API_KEY_ID` — the Key ID
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID` — the Issuer ID
- `APP_STORE_CONNECT_API_KEY_CONTENT` — base64 of the `.p8` file contents

## Full deploy flow (archive → TestFlight)

```bash
TEAM_ID=<your 10-char Team ID>
SCHEME=Bide
PROJECT=Bide.xcodeproj
ARCHIVE_PATH=./build/Bide.xcarchive
EXPORT_PATH=./build
KEY_ID=<App Store Connect key ID>
ISSUER_ID=<App Store Connect issuer ID>
P8_PATH=~/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8

# 1. Increment build number (CFBundleVersion)
agvtool next-version -all

# 2. Archive
xcodebuild archive \
  -project $PROJECT \
  -scheme $SCHEME \
  -configuration Release \
  -archivePath $ARCHIVE_PATH \
  DEVELOPMENT_TEAM=$TEAM_ID \
  | tee archive.log

# 3. Export .ipa
xcodebuild -exportArchive \
  -archivePath $ARCHIVE_PATH \
  -exportPath $EXPORT_PATH \
  -exportOptionsPlist ExportOptions.plist \
  | tee export.log

# 4. Upload to App Store Connect (TestFlight)
xcrun altool --upload-app \
  --type ios \
  --file "$EXPORT_PATH/Bide.ipa" \
  --apiKey "$KEY_ID" \
  --apiIssuer "$ISSUER_ID"

# Processing typically takes 15min–2hr. TestFlight pings when ready.
```

## Status check after upload

```bash
# List recent builds
xcrun altool --list-apps \
  --apiKey "$KEY_ID" \
  --apiIssuer "$ISSUER_ID"
```

Or use the App Store Connect UI: https://appstoreconnect.apple.com/apps/<app id>/testflight/ios

## Submit to App Store review

After TestFlight build processes, you can submit it for App Store review:

1. App Store Connect → My Apps → Bide → App Store tab
2. Fill in:
   - Description (from `docs/app-store-listing.md`)
   - Keywords (~100 chars total)
   - Screenshots (3.5", 5.5", 6.5", 6.9")
   - Privacy policy URL
   - Support URL
3. Privacy questionnaire (Bide's answer to most items: "No, we do not collect this data")
4. Build → select the TestFlight build you just uploaded
5. Save → Submit for Review

## ExportOptions.plist (App Store distribution)

Create at repo root as `ExportOptions.plist` (gitignored or use a `.template`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
```

## Notarization (not needed for App Store apps)

App Store apps are notarized automatically as part of the App Store review. We don't need to run `notarytool` ourselves.

## Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `Application Loader: ITMS-90168: Invalid Code Signing Entitlements` | Entitlements file references a capability not added in App Store Connect | App Store Connect → App → Capabilities → enable the missing one |
| `No matching profiles found for app store distribution` | Provisioning profile missing or expired | Xcode → Settings → Accounts → Download Manual Profiles |
| `Could not authenticate with the App Store API` | API key wrong, expired, or insufficient permissions | Regenerate key with at least App Manager role |
| Build stuck "Processing" in App Store Connect for >2hr | Apple-side delay or invalid binary metadata | Check email for Apple feedback; if none, contact App Store Connect support |
| `Invalid binary architecture` | Missing arm64 slice or extra slice (e.g. x86_64) | Build settings → Architectures → Standard (arm64); Excluded Architectures (Simulator) → arm64 |
