#!/usr/bin/env bash
# Fails when line coverage of hand-written library code is below the gate,
# or when a library under lib/ has no coverage record (no test loads it, so
# the gate cannot see it). Run from the repository root.
#
# Usage: tool/check_coverage.sh [lcov file] [minimum percent]
#   defaults: coverage/lcov.info, 90
#
# Excluded from the gate:
#   lib/src/proto/**                      generated protobuf bindings
#   lib/src/rtc/flutter_webrtc_adapter*.dart  platform glue (a library and its
#                                         parts), covered by device tests
# Never recorded (no executable code):
#   lib/fishjam_client.dart               exports only
#   lib/src/version.dart                  constants only
set -euo pipefail

LCOV="${1:-coverage/lcov.info}"
MIN="${2:-90}"

if [[ ! -f "$LCOV" ]]; then
  echo "coverage file $LCOV not found; run: flutter test --coverage" >&2
  exit 66
fi

unrecorded=0
while IFS= read -r file; do
  case "$file" in
    lib/src/proto/* | lib/src/rtc/flutter_webrtc_adapter*.dart | \
      lib/fishjam_client.dart | lib/src/version.dart) continue ;;
  esac
  if ! grep -qx "SF:$file" "$LCOV"; then
    echo "FAIL: $file has no coverage record; load it from a test" >&2
    unrecorded=1
  fi
done < <(find lib -name '*.dart' | sort)
if [[ $unrecorded -ne 0 ]]; then exit 1; fi

awk -v min="$MIN" '
  /^SF:/ {
    file = substr($0, 4)
    skip = (file ~ /lib\/src\/proto\// || file ~ /lib\/src\/rtc\/flutter_webrtc_adapter[a-z_]*\.dart$/)
    next
  }
  /^DA:/ && !skip {
    split(substr($0, 4), parts, ",")
    total++
    if (parts[2] > 0) hit++
    per_total[file]++
    if (parts[2] > 0) per_hit[file]++
  }
  END {
    if (total == 0) { print "no coverable lines found"; exit 1 }
    for (f in per_total) {
      printf "%6.1f%%  %s\n", 100 * per_hit[f] / per_total[f], f | "sort -n"
    }
    close("sort -n")
    pct = 100 * hit / total
    printf "\nline coverage: %.2f%% (%d/%d lines), gate: %d%%\n", pct, hit, total, min
    if (pct + 1e-9 < min) { print "FAIL: coverage below gate"; exit 1 }
  }
' "$LCOV"
