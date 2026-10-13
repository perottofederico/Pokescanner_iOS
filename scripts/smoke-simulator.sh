#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build/artifacts

xcodebuild \
  -project PokeCapture.xcodeproj \
  -scheme PokeCapture \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/simulator \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | tee build/simulator-build.log

xcrun simctl list devices available --json > build/simulator-devices.json
device_id=$(python3 - <<'PY'
import json
from pathlib import Path

devices = json.loads(Path('build/simulator-devices.json').read_text())['devices']
for runtime, candidates in sorted(devices.items(), reverse=True):
    if 'iOS' not in runtime:
        continue
    for device in candidates:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            print(device['udid'])
            raise SystemExit(0)
raise SystemExit('No available iPhone simulator runtime on this runner.')
PY
)

trap 'xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true' EXIT
state=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; devices=json.load(sys.stdin)["devices"]; print(next(device["state"] for group in devices.values() for device in group if device["udid"] == sys.argv[1]))' "$device_id")
if [[ "$state" != 'Booted' ]]; then
  xcrun simctl boot "$device_id"
fi
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" build/simulator/Build/Products/Debug-iphonesimulator/PokeCapture.app
xcrun simctl launch "$device_id" com.pokecapture.demo | tee build/artifacts/simulator-launch.txt
sleep 5
xcrun simctl io "$device_id" screenshot build/artifacts/simulator-launch.png
xcrun simctl terminate "$device_id" com.pokecapture.demo
echo 'Simulator launch passed. Physical-device recording has NOT been tested.' | tee -a build/artifacts/simulator-launch.txt
