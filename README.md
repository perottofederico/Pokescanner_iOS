<img src="assets/icon.svg" width="64" height="64" alt="">

# Pokegenie for me

A native **iOS Pokémon scanner**, developed on Windows and compiled using GitHub Actions. The SwiftUI app displays a persistent collection; its ReplayKit extension performs on-device Apple Vision OCR while Pokémon GO is open.

## Try it on an iPhone

1. Push this project to a GitHub repository on `main` or `master`.
2. Run **Actions → Build iPhone capture demo**.
3. Download and extract **PokeCapture-demo** from the successful run.
4. Re-sign/install `PokeCapture-unsigned.ipa` with **AltStore Classic on Windows**, retaining the broadcast extension.
5. Open **Scan**, start the broadcast, and hold the Pokémon detail, appraisal, and moves pages steady for 3–5 seconds each. Return to **Pokémon** to open the saved records. Stop using iOS's recording controls.
6. Alternatively, use **Import a screenshot** in the Pokémon tab to recognize a single image, including the example in `assets/recognition-example.jpg`.

**Read [the installation guide](docs/iphone-testing.md) and [recognition guide](docs/recognition.md) first.** The IPA cannot be installed directly: it uses ad-hoc signatures to carry the shared App Group entitlement, then AltStore must re-sign both targets for your device. Shared storage is new in version 0.2; its availability must be checked after installation. No Apple credentials are used by CI.

## Scope and privacy

- Reads English/Italian species names, CP, current/max HP, and full move names. No 3D-model classifier yet.
- Measures visible appraisal bars for attack/defense/stamina IVs. Unclear fields stay missing, not zero.
- Persists partial Pokémon records, enriching the current scan across nearby pages without globally merging same-species specimens.
- Sorts by IV, CP, Pokédex number, scan date, or name; supports protected edits and persistent removal. Rounded IV circles use quality color bands.
- Saves cropped Pokémon thumbnails and temporary, shareable CP/OCR diagnostics. CP supports split labels/digits and enlarged top-crop retries.
- Samples one frame at a time, approximately every 1.3 seconds with backpressure. Full frames/audio are discarded; fields, thumbnails, and bounded diagnostic text stay on device.
- Includes native macOS checks for the supplied screenshot, parser/merging behavior, and persistence. Live capture still requires a physical-device test.

## Project layout

- `ios/PokeCapture/`: SwiftUI app, system picker, and capture diagnostics.
- `ios/BroadcastUpload/`: ReplayKit sample handler.
- `ios/Shared/`: OCR, IV pixels, record models, catalog parsing, and shared App Group outbox.
- `ios/Resources/`: bundled English/Italian PokéAPI species/move names and required license.
- `project.json`: XcodeGen specification for both targets (iOS 16+).
- `.github/workflows/ios-demo.yml`: unsigned device build, IPA artifact, and simulator smoke check.
- `scripts/`: project/IPA validation, catalog generation, native recognition checks, and macOS builds.

Run `python scripts/validate-project.py` on Windows. On a Mac or CI runner with Xcode and XcodeGen, run:

```bash
xcodegen generate --spec project.json
bash scripts/build-ios.sh
bash scripts/smoke-simulator.sh
```

Generated Xcode projects and build artifacts are ignored. Xcode builds without developer signing; packaging applies local ad-hoc signatures only to preserve App Group entitlements for the sideloading tool. No developer certificate, third-party SDK, or server is required to build. The catalog is pinned to a source revision and regenerated only by `python scripts/generate-catalog.py`; the running app never downloads it.
