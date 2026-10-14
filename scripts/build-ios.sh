#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build/artifacts build/package/Payload

xcodebuild \
  -project PokeCapture.xcodeproj \
  -scheme PokeCapture \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | tee build/device-build.log

app_path='build/device/Build/Products/Release-iphoneos/PokeCapture.app'
extension_path="$app_path/PlugIns/BroadcastUpload.appex"
test -f "$app_path/PokeCapture"
test -f "$extension_path/BroadcastUpload"
xcrun lipo "$app_path/PokeCapture" -verify_arch arm64
xcrun lipo "$extension_path/BroadcastUpload" -verify_arch arm64

codesign --force --sign - --entitlements ios/Shared/PokeCapture.entitlements "$extension_path"
codesign --force --sign - --entitlements ios/Shared/PokeCapture.entitlements "$app_path"
codesign --verify --strict "$extension_path"
codesign --verify --strict "$app_path"

ditto "$app_path" build/package/Payload/PokeCapture.app
(
  cd build/package
  ditto -c -k --keepParent --norsrc Payload ../artifacts/PokeCapture-unsigned.ipa
)
python3 scripts/validate-project.py --ipa build/artifacts/PokeCapture-unsigned.ipa
shasum -a 256 build/artifacts/PokeCapture-unsigned.ipa > build/artifacts/SHA256SUMS.txt
cp docs/iphone-testing.md build/artifacts/INSTALL.md
{
  xcodebuild -version
  xcodegen --version
  echo "Commit: $(git rev-parse HEAD)"
  echo 'Signing: ad-hoc entitlement carrier only; re-sign both targets with a device provisioning profile before installation.'
} > build/artifacts/build-info.txt
