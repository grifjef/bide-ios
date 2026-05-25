---
name: ios-build
description: xcodebuild shortcuts for the Bide iOS project — build, test, clean, archive, list simulators. Use when Claude needs to compile, test, or archive the app, or when troubleshooting a CI build failure.
---

# ios-build

Compact reference for the `xcodebuild` commands we use in the Bide project. Project file: `Bide.xcodeproj`. Scheme: `Bide`. Default simulator: `iPhone 17 Pro`.

## Build for Simulator (debug, no signing)

```bash
xcodebuild build \
  -project Bide.xcodeproj \
  -scheme Bide \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

## Test (with coverage)

```bash
xcodebuild test \
  -project Bide.xcodeproj \
  -scheme Bide \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

To run a single test class:

```bash
xcodebuild test \
  -project Bide.xcodeproj \
  -scheme Bide \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BideTests/LargeVideosViewModelTests
```

## Clean

```bash
xcodebuild clean -project Bide.xcodeproj -scheme Bide
# Plus blow away DerivedData if a build is wedged:
rm -rf ~/Library/Developer/Xcode/DerivedData/Bide-*
```

## Build for device (release, requires signing)

```bash
xcodebuild build \
  -project Bide.xcodeproj \
  -scheme Bide \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  DEVELOPMENT_TEAM=<TEAM_ID>
```

## Archive (for TestFlight / App Store)

```bash
xcodebuild archive \
  -project Bide.xcodeproj \
  -scheme Bide \
  -configuration Release \
  -archivePath ./build/Bide.xcarchive \
  DEVELOPMENT_TEAM=<TEAM_ID>
```

## Export .ipa from archive

Requires an `ExportOptions.plist`. App Store distribution example:

```bash
xcodebuild -exportArchive \
  -archivePath ./build/Bide.xcarchive \
  -exportPath ./build/ \
  -exportOptionsPlist ./build/ExportOptions.plist
```

Minimal `ExportOptions.plist` for App Store:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string>TEAM_ID_HERE</string>
  <key>uploadSymbols</key>
  <true/>
  <key>uploadBitcode</key>
  <false/>
</dict>
</plist>
```

For TestFlight (same `method` works — TestFlight is a stage on App Store Connect, not a separate export option).

## List available simulators

```bash
xcrun simctl list devices available | grep -E "iPhone (1[5-9]|2[0-9])"
```

## Boot a simulator and install

```bash
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
xcrun simctl install booted /path/to/Bide.app
xcrun simctl launch booted com.bidephoto.bide
```

## Show available schemes / configurations

```bash
xcodebuild -project Bide.xcodeproj -list
```

## Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `requires Xcode, but active developer directory '/Library/Developer/CommandLineTools'` | `xcode-select` pointing at CLT, not Xcode | `sudo xcode-select -s /Applications/Xcode.app` |
| `No profiles for 'com.bidephoto.bide' were found` | No matching provisioning profile installed | Open Xcode → Signing & Capabilities → check "Automatically manage signing" and ensure Team is set |
| `xcrun: error: invalid active developer path` | Same as first; or Xcode just moved | Re-run `xcode-select -s` |
| Build hangs at "Compiling …" indefinitely | DerivedData corruption | `rm -rf ~/Library/Developer/Xcode/DerivedData/Bide-*` |
| Test target won't link | Scheme missing test target | `xcodebuild -list` to verify; re-add in Xcode if needed |
| Coverage missing from xcresult | `-enableCodeCoverage YES` not passed OR scheme has coverage disabled | Both must be set; check scheme's Test action → Options |
