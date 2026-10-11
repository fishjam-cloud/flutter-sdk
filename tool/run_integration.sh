#!/usr/bin/env bash
# Runs the example app's integration tests on an iOS simulator against a
# running Fishjam server. Prerequisites: example/integration_test/README.md.
#
# Usage:
#   FISHJAM_URL=http://localhost:<port> FISHJAM_MANAGEMENT_TOKEN=<token> \
#     tool/run_integration.sh [simulator name or UDID]
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

# Grant media access up front so no permission dialog blocks the test.
for service in microphone camera; do
  xcrun simctl privacy "$TARGET" grant "$service" "$BUNDLE_ID" || true
done

cd "$ROOT/example"
mise exec -- flutter pub get
mise exec -- flutter test integration_test \
  -d "$TARGET" \
  --dart-define=FISHJAM_URL="$FISHJAM_URL" \
  --dart-define=FISHJAM_MANAGEMENT_TOKEN="$FISHJAM_MANAGEMENT_TOKEN"
