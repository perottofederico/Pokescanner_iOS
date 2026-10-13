<img src="assets/icon.svg" width="64" height="64" alt="">

# Pokegenie for me

First milestone: a native **iOS live-capture proof of concept**, developed on Windows and compiled using GitHub Actions. It contains a SwiftUI host app and a ReplayKit Broadcast Upload Extension. No OCR or Pokémon collection yet.

## Try it on an iPhone

1. Push this project to a GitHub repository on `main` or `master`.
2. Run **Actions → Build iPhone capture demo**.
3. Download and extract **PokeCapture-demo** from the successful run.
4. Re-sign/install `PokeCapture-unsigned.ipa` with **AltStore Classic on Windows**, retaining the broadcast extension.
5. Launch **Poke Capture**, tap its broadcast icon, and confirm **Start Broadcast** in the iOS dialog. Check live video heartbeats, switch to Pokémon GO, return, then stop using iOS's recording controls.

**Read [the installation and device-test guide](docs/iphone-testing.md) first.** The IPA is unsigned and cannot be installed directly. Free provisioning requires periodic refresh; this extension's compatibility still needs testing on your device. Public repositories use free standard GitHub-hosted runners; private repositories have plan-specific limits. No Apple secrets are used by CI.

## Scope and privacy

- Uses the real system broadcast picker and receives real video buffers in a separate extension.
- Displays best-effort foreground video heartbeats, not simulated recording status.
- Discards buffers immediately; no videos, screenshots, audio, or uploads are saved by the demo.
- The simulator workflow checks compilation/launch only. Actual cross-app recording requires the manual iPhone test.

## Project layout

- `ios/PokeCapture/`: SwiftUI app, system picker, and capture diagnostics.
- `ios/BroadcastUpload/`: ReplayKit sample handler.
- `ios/Shared/`: payload-free diagnostic notifications; no App Group entitlement required.
- `project.json`: XcodeGen specification for both targets (iOS 16+).
- `.github/workflows/ios-demo.yml`: unsigned device build, IPA artifact, and simulator smoke check.
- `scripts/`: project/IPA validation and macOS build scripts.

Run `python scripts/validate-project.py` on Windows. On a Mac or CI runner with Xcode and XcodeGen, run:

```bash
xcodegen generate --spec project.json
bash scripts/build-ios.sh
bash scripts/smoke-simulator.sh
```

Generated Xcode projects and build artifacts are ignored. Configuration disables signing by default; no certificate, paid team, App Group, third-party SDK, or server is required to build this demo.
