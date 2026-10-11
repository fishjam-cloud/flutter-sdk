#!/usr/bin/env bash
# Runs the example app's integration tests on an iOS simulator against a
# running Fishjam server. Prerequisites: example/integration_test/README.md.
#
# Usage:
#   FISHJAM_URL=http://localhost:<port> FISHJAM_MANAGEMENT_TOKEN=<token> \
#     tool/run_integration.sh [simulator UDID]
#
# Without an argument the first available iPhone simulator is used.
set -euo pipefail

: "${FISHJAM_URL:?set FISHJAM_URL to the Fishjam server URL}"
: "${FISHJAM_MANAGEMENT_TOKEN:?set FISHJAM_MANAGEMENT_TOKEN to its management token}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="io.fishjam.example.fishjamExample"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  TARGET="$(xcrun simctl list devices available |
    sed -nE 's/^ +iPhone[^(]* \(([0-9A-F-]{36})\) \((Booted|Shutdown)\).*$/\1/p' |
    head -n 1)"
  if [[ -z "$TARGET" ]]; then
    echo "No available iPhone simulator; create one in Xcode." >&2
    exit 1
  fi
fi

echo "Using simulator $TARGET"
xcrun simctl boot "$TARGET" 2>/dev/null || true # already booted is fine
xcrun simctl bootstatus "$TARGET" -b >/dev/null
open -a Simulator

DEFINES=(
  --dart-define=FISHJAM_URL="$FISHJAM_URL"
  --dart-define=FISHJAM_MANAGEMENT_TOKEN="$FISHJAM_MANAGEMENT_TOKEN"
)

cd "$ROOT/example"
mise exec -- flutter pub get

# Install the test app first: privacy grants apply to an installed app.
mise exec -- flutter build ios --simulator --debug \
  -t integration_test/room_test.dart "${DEFINES[@]}"
xcrun simctl install "$TARGET" build/ios/iphonesimulator/Runner.app

# Grant media access so no permission dialog blocks the test.
for service in microphone camera; do
  if ! xcrun simctl privacy "$TARGET" grant "$service" "$BUNDLE_ID"; then
    echo "WARNING: could not grant $service access to $BUNDLE_ID;" \
      "the test may stop at a permission dialog." >&2
  fi
done

mise exec -- flutter test integration_test \
  -d "$TARGET" \
  "${DEFINES[@]}"
