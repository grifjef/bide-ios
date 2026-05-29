#!/usr/bin/env bash
#
# archive-and-upload.sh — one-command TestFlight submit for Bide.
#
# Flow: regenerate project → archive (Release) → export .ipa →
#       upload to App Store Connect (TestFlight).
#
# Credentials come from .secrets/apple.env (gitignored). Expected vars:
#   ASC_TEAM_ID      — 10-char Apple Developer Team ID
#   ASC_KEY_ID       — App Store Connect API key ID
#   ASC_ISSUER_ID    — App Store Connect issuer ID
#   ASC_P8_PATH      — path to the AuthKey_*.p8 (default:
#                      ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8)
#
# Usage:
#   scripts/archive-and-upload.sh            # full archive + upload
#   scripts/archive-and-upload.sh --dry-run  # archive + export, NO upload
#
# The .p8 key is NEVER committed; the script refuses to run if it finds
# the key inside the repo working tree.

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SCHEME="Bide"
PROJECT="Bide.xcodeproj"
ARCHIVE_PATH="./build/Bide.xcarchive"
EXPORT_PATH="./build/export"
EXPORT_OPTS="./build/ExportOptions.plist"

# --- Preflight ---------------------------------------------------------

ENV_FILE=".secrets/apple.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Create it with ASC_TEAM_ID / ASC_KEY_ID /"
  echo "       ASC_ISSUER_ID / ASC_P8_PATH (see scripts/archive-and-upload.sh header)."
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${ASC_TEAM_ID:?ASC_TEAM_ID missing from $ENV_FILE}"
if [[ "$DRY_RUN" -eq 0 ]]; then
  : "${ASC_KEY_ID:?ASC_KEY_ID missing from $ENV_FILE}"
  : "${ASC_ISSUER_ID:?ASC_ISSUER_ID missing from $ENV_FILE}"
fi
ASC_P8_PATH="${ASC_P8_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

# Safety: refuse to run if a .p8 key is sitting inside the repo tree.
if find "$REPO_ROOT" -name "AuthKey_*.p8" -not -path "*/.secrets/*" | grep -q .; then
  echo "ERROR: Found an AuthKey_*.p8 inside the repo working tree. Never commit"
  echo "       the App Store Connect private key. Move it outside the repo."
  exit 1
fi

mkdir -p ./build

# --- 1. Regenerate the Xcode project ----------------------------------

echo "==> xcodegen generate"
xcodegen generate

# --- 2. Bump build number ---------------------------------------------
# CURRENT_PROJECT_VERSION lives in project.yml; bump it there before
# running this so the upload isn't rejected as a duplicate build. We
# only echo a reminder rather than mutate project.yml from a shell.
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
  "$(find . -name Info.plist -path '*Bide*' | head -1)" 2>/dev/null || echo '?')"
echo "==> Current build number (CFBundleVersion): $CURRENT_BUILD"
echo "    (bump CURRENT_PROJECT_VERSION in project.yml if this build was already uploaded)"

# --- 3. Generate ExportOptions.plist ----------------------------------

cat > "$EXPORT_OPTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string>${ASC_TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
PLIST

# --- 4. Archive --------------------------------------------------------

echo "==> Archiving (Release)"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=iOS' \
  DEVELOPMENT_TEAM="$ASC_TEAM_ID" \
  | tee ./build/archive.log | tail -5

# --- 5. Export .ipa ----------------------------------------------------

echo "==> Exporting .ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  | tee ./build/export.log | tail -5

IPA="$(find "$EXPORT_PATH" -name '*.ipa' | head -1)"
echo "==> Built: $IPA"

# --- 6. Upload ---------------------------------------------------------

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> --dry-run: skipping upload. IPA is at $IPA"
  exit 0
fi

if [[ ! -f "$ASC_P8_PATH" ]]; then
  echo "ERROR: API key not found at $ASC_P8_PATH"
  exit 1
fi

echo "==> Uploading to App Store Connect (TestFlight)"
xcrun altool --upload-app \
  --type ios \
  --file "$IPA" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo "==> Upload submitted. Processing takes 15min–2hr; TestFlight pings when ready."
