#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/ios-sweep-alert"
ARTIFACTS_DIR="${ASC_ARTIFACTS_DIR:-$APP_DIR/.asc/artifacts}"

: "${ASC_KEY_ID:?Missing ASC_KEY_ID}"
: "${ASC_PRIVATE_KEY_PATH:?Missing ASC_PRIVATE_KEY_PATH}"
ASC_BUNDLE_ID="${ASC_BUNDLE_ID:-ai.revyl.sweepalert.swift}"
: "${APPLE_TEAM_ID:?Missing APPLE_TEAM_ID}"
ASC_MARKETING_VERSION="${ASC_MARKETING_VERSION:-1.0}"
ASC_BUILD_NUMBER="${ASC_BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
ASC_PROJECT="${ASC_PROJECT:-$APP_DIR/SweepAlertSwift.xcodeproj}"
ASC_SCHEME="${ASC_SCHEME:-SweepAlertSwift}"
ASC_CONFIGURATION="${ASC_CONFIGURATION:-Release}"
ASC_EXPORT_OPTIONS="${ASC_EXPORT_OPTIONS:-$APP_DIR/ExportOptions-TestFlight.plist}"
ASC_ARCHIVE_PATH="${ASC_ARCHIVE_PATH:-$ARTIFACTS_DIR/SweepAlertSwift-$ASC_BUILD_NUMBER.xcarchive}"
ASC_IPA_PATH="${ASC_IPA_PATH:-$ARTIFACTS_DIR/SweepAlertSwift-$ASC_BUILD_NUMBER.ipa}"
ASC_LOGIN_NAME="${ASC_LOGIN_NAME:-sweepalert-testflight}"
ASC_TESTFLIGHT_GROUP="${ASC_TESTFLIGHT_GROUP:-}"
ASC_TEST_NOTES="${ASC_TEST_NOTES:-Test shared SweepAlert car crews, invite links, Auth0 login, Convex sync, push notifications, map parking pin placement, and street cleaning reminders.}"
ASC_TEST_NOTES_LOCALE="${ASC_TEST_NOTES_LOCALE:-en-US}"

if [[ -z "${ASC_ISSUER_ID:-}" ]]; then
  cat >&2 <<'EOF'
Missing ASC_ISSUER_ID.

Find it in App Store Connect:
Users and Access -> Integrations -> App Store Connect API -> Issuer ID

Then run:
  export ASC_ISSUER_ID="<issuer-id>"
  npm run ios:testflight
EOF
  exit 2
fi

if [[ ! -f "$ASC_PRIVATE_KEY_PATH" ]]; then
  echo "App Store Connect private key was not found at: $ASC_PRIVATE_KEY_PATH" >&2
  exit 2
fi

for tool in asc xcodebuild xcrun /usr/bin/python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool is missing: $tool" >&2
    exit 2
  fi
done

asc_cmd=(asc)
if [[ -n "${ASC_PROFILE:-}" ]]; then
  asc_cmd+=(--profile "$ASC_PROFILE")
fi

mkdir -p "$ARTIFACTS_DIR"

if [[ "${ASC_SKIP_AUTH_LOGIN:-0}" != "1" ]]; then
  "${asc_cmd[@]}" auth login \
    --name "$ASC_LOGIN_NAME" \
    --key-id "$ASC_KEY_ID" \
    --issuer-id "$ASC_ISSUER_ID" \
    --private-key "$ASC_PRIVATE_KEY_PATH" \
    --network
fi

if [[ -z "${ASC_APP_ID:-}" ]]; then
  ASC_APP_ID="$(
    "${asc_cmd[@]}" apps list --bundle-id "$ASC_BUNDLE_ID" --limit 1 --output json |
      /usr/bin/python3 -c '
import json
import sys

payload = json.load(sys.stdin)
item = None
if isinstance(payload, dict):
    data = payload.get("data")
    if isinstance(data, list) and data:
        item = data[0]
    elif isinstance(payload.get("id"), str):
        item = payload
elif isinstance(payload, list) and payload:
    item = payload[0]

if not item:
    sys.exit("No App Store Connect app matched the bundle identifier.")

app_id = item.get("id") if isinstance(item, dict) else None
if not app_id:
    sys.exit("Could not read the App Store Connect app id from asc output.")

print(app_id)
'
  )"
fi

if [[ -z "$ASC_APP_ID" ]]; then
  echo "Missing ASC_APP_ID and app lookup did not return an app." >&2
  exit 2
fi

echo "Publishing SweepAlert iOS to TestFlight"
echo "  App Store Connect app: $ASC_APP_ID"
echo "  Bundle identifier:     $ASC_BUNDLE_ID"
echo "  Version/build:         $ASC_MARKETING_VERSION ($ASC_BUILD_NUMBER)"
echo "  Archive path:          $ASC_ARCHIVE_PATH"
echo "  IPA path:              $ASC_IPA_PATH"

rm -rf "$ASC_ARCHIVE_PATH" "$ASC_IPA_PATH"

publish_args=(
  publish testflight
  --app "$ASC_APP_ID"
  --project "$ASC_PROJECT"
  --scheme "$ASC_SCHEME"
  --configuration "$ASC_CONFIGURATION"
  --version "$ASC_MARKETING_VERSION"
  --build-number "$ASC_BUILD_NUMBER"
  --archive-path "$ASC_ARCHIVE_PATH"
  --ipa-path "$ASC_IPA_PATH"
  --export-options "$ASC_EXPORT_OPTIONS"
  --clean
  --wait
  --archive-xcodebuild-flag=-destination
  --archive-xcodebuild-flag=generic/platform=iOS
  --archive-xcodebuild-flag="DEVELOPMENT_TEAM=$APPLE_TEAM_ID"
  --archive-xcodebuild-flag="MARKETING_VERSION=$ASC_MARKETING_VERSION"
  --archive-xcodebuild-flag="CURRENT_PROJECT_VERSION=$ASC_BUILD_NUMBER"
  --archive-xcodebuild-flag=-allowProvisioningUpdates
  --archive-xcodebuild-flag=-authenticationKeyPath
  --archive-xcodebuild-flag="$ASC_PRIVATE_KEY_PATH"
  --archive-xcodebuild-flag=-authenticationKeyID
  --archive-xcodebuild-flag="$ASC_KEY_ID"
  --archive-xcodebuild-flag=-authenticationKeyIssuerID
  --archive-xcodebuild-flag="$ASC_ISSUER_ID"
  --export-xcodebuild-flag=-allowProvisioningUpdates
  --export-xcodebuild-flag=-authenticationKeyPath
  --export-xcodebuild-flag="$ASC_PRIVATE_KEY_PATH"
  --export-xcodebuild-flag=-authenticationKeyID
  --export-xcodebuild-flag="$ASC_KEY_ID"
  --export-xcodebuild-flag=-authenticationKeyIssuerID
  --export-xcodebuild-flag="$ASC_ISSUER_ID"
)

if [[ -n "${ASC_TESTFLIGHT_GROUP:-}" ]]; then
  publish_args+=(--group "$ASC_TESTFLIGHT_GROUP")
fi

if [[ -n "${ASC_TEST_NOTES:-}" ]]; then
  publish_args+=(--test-notes "$ASC_TEST_NOTES" --locale "$ASC_TEST_NOTES_LOCALE")
fi

if [[ "${ASC_NOTIFY_TESTERS:-0}" == "1" ]]; then
  publish_args+=(--notify)
fi

"${asc_cmd[@]}" "${publish_args[@]}"

echo "TestFlight upload complete."
