# Install and test the live-capture demo

## Cost and signing: read this first

GitHub Actions compiles the app on a hosted Mac. The artifact is **not device-provisioned**, so it cannot be installed directly. Version 0.2 applies ad-hoc signatures only to carry shared App Group entitlements. AltStore must re-sign it locally with your Apple account, including its embedded broadcast extension.

- Standard GitHub-hosted runners are free for public repositories. Private repositories have plan-specific included usage and limits; check your billing settings before enabling builds. No paid Apple membership or signing secrets are required by this workflow.
- The proposed free installation route is **AltStore Classic + AltServer on Windows** and a free Apple account. This is not AltStore PAL. Free provisioning expires after seven days and has app/App ID limits. Refresh using AltStore before expiry.
- Version 0.2 requires a shared App Group for persisting live OCR results while the host app is suspended. Keep both the App Group entitlement and broadcast extension when re-signing. Verify shared-storage status after installation; an installable app alone does not prove this capability works. See [recognition and signing details](recognition.md).
- Compatibility of this specific broadcast extension with your free provisioning account/iOS version is an acceptance test, not yet a verified promise. If signing/installing the extension fails, do not remove it to make installation succeed: capture requires it. Save the exact error so we can investigate.
- Do not put your Apple password, certificates, or provisioning profiles into GitHub Actions or chat. Enter account credentials only in the signing tool you choose to trust. Review AltStore's security information before using it.

## 1. Build using GitHub Actions

1. Push this project to your GitHub repository on `main` or `master`. A public repository exposes your source code; choose public only if that is acceptable.
2. Open the repository's **Actions** tab and select **Build iPhone capture demo**. It runs on relevant pushes; you can also use **Run workflow** after the workflow is on the default branch.
3. Wait for a successful run. It checks the OCR/pixel pipeline against the example screenshot, generates the Xcode project, compiles both device targets, packages the IPA with App Group entitlement carriers, and builds/launches a simulator app.
4. Download the **PokeCapture-demo** artifact and extract it. The app is `PokeCapture-unsigned.ipa`. You also get tool versions, a checksum, and simulator launch evidence. Build logs are in the separate **PokeCapture-diagnostics** artifact, which may also be uploaded after a failed build. A diagnostics upload does not mean an IPA was produced.
5. A green workflow does **not** establish that screen capture works on an iPhone. Complete the physical-device steps below.

If a workflow fails after **BUILD SUCCEEDED**, inspect the failing packaging/validation command: compilation success does not imply that an IPA was packaged. After fixing the source, commit and push the changes and use the new workflow run. **Re-run jobs** on an older run uses its original commit and will not include newly pushed fixes. The simulator and success summary normally skip after an earlier failure; diagnostic uploads and checkout cleanup can still run.

## 2. Set up AltStore Classic on Windows

Follow the current official [Windows installation guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows). In summary:

1. Install the Apple iTunes/iCloud versions specified by AltStore's guide, then install AltServer for Windows. Check its troubleshooting instructions if you already use Microsoft Store versions.
2. Connect your unlocked iPhone by USB, trust the computer, and enable Wi-Fi sync in iTunes.
3. Use AltServer's tray menu to install AltStore Classic on your iPhone. Supply your Apple account directly to AltServer, never to this project.
4. On the phone, trust your developer identity under **Settings → General → VPN & Device Management**, as instructed by AltStore.
5. Enable **Settings → Privacy & Security → Developer Mode** if required, then complete the restart/confirmation.

## 3. Install our IPA

1. Transfer `PokeCapture-unsigned.ipa` to the iPhone's Files app, for example with a cloud drive or iTunes file sharing. An unsigned IPA is not a secret, but do not publicly share any subsequently signed copy containing provisioning details.
2. Keep AltServer running and reachable, then open **AltStore → My Apps → +** and select the IPA, following its current sideloading instructions.
3. If AltStore asks about extensions, choose **Keep App Extensions**. The extension uses an additional App ID.
4. Open **Poke Capture → Scan**. Confirm an embedded provider identifier is shown, there is no “Broadcast extension missing” message, and shared scan storage is available.
5. If the extension is missing, reinstall with extensions retained. Do not treat an app-only installation as a successful test.

The app finds the embedded extension's actual identifier at runtime because sideloading tools can rewrite bundle identifiers. It does not assume the original identifier survives re-signing.

## 4. Physical-device acceptance test

Record your iPhone model, exact iOS version, workflow run/commit, signing tool version, and any error text. Avoid private notifications while broadcasting.

| Step | Expected result |
| --- | --- |
| Launch Poke Capture | UI opens without crashing; embedded provider is present. |
| Tap the recording icon | iOS shows its broadcast controls with **Poke Capture** as provider. |
| Tap **Start Broadcast** | After the iOS countdown, the red recording indicator appears. The app cannot bypass this user confirmation. |
| Remain in the demo briefly | **Receiving live video** appears and video heartbeats increase. These signals are sent only after a video buffer reaches the extension. |
| Switch to Pokémon GO for 15–30 seconds | The system recording indicator remains active. The extension, not the backgrounded host app, receives screen buffers. |
| Return to the demo and wait a few seconds | Fresh video heartbeats appear again. This checks extension survival, not OCR of the Pokémon screen while away. |
| Stop using the red system indicator or broadcast controls | The recording indicator disappears; the heartbeat count stops and recent-video status clears within about three seconds. |
| Start a second session | The extension starts again and new heartbeats are observed. |

If the in-app picker fails, add Screen Recording to Control Center if necessary, long-press its recording control, select **Poke Capture**, and start the broadcast there. To stop, use the system recording indicator or the same Control Center controls.

The heartbeat display is **best-effort diagnostic telemetry** using payload-free Darwin notifications. It is not durable shared storage, an authenticated channel, or a frame counter. Signals can be coalesced or missed while the host app is suspended. A stale indicator means “no recent video confirmed,” not necessarily “recording is off.” Use iOS's recording indicator and controls as the authority for stopping capture. Keep only one copy of this demo installed because the diagnostic notification namespace is fixed.

If the system says capture is active but no heartbeats appear even after returning, report that as a diagnostic failure. Do not claim the complete live-capture test passed. Device logs under subsystem `com.pokecapture.demo`, category `Broadcast`, contain lifecycle events and frame dimensions/counts, not screen contents; collecting them may require additional device-log tooling.

## Recognition scope

- Version 0.3 adds sorting, protected editing/removal, cropped images, rounded/color-coded IV circles, and per-record CP diagnostics to the name-based OCR collection. See [the recognition guide](recognition.md) for supported fields and acceptance tests. It does not reproduce Poke Genie's UI or classify 3D models.
- No saved video or Photos entry: this is a ReplayKit broadcast receiver, not a video-file recorder.
- No automatic network connection, server, uploading, saved video, or audio processing. Small cropped model images and bounded top-screen OCR logs are retained locally; logs can be shared explicitly from details. One sampled pixel buffer can be retained temporarily while its OCR request runs; at most one request runs at a time.
- The scanner uses visible detail-screen features, not a privileged foreground-app identifier. Verify recognition by inspecting saved Pokémon records, not just video heartbeats.
- No automated start/stop bypassing Apple's controls, App Store submission, or TestFlight distribution.

## Validation boundaries

On Windows, run `python scripts/validate-project.py` to check configuration, plists, catalog, and shared entitlements. Actual Apple Vision fixture checks, Swift compilation, and simulator launch require Apple's SDKs and run in GitHub Actions. The physical-device broadcast, shared-group provisioning, and multi-page recognition test remain manual.

## Primary references

- [Apple: developer account and free provisioning limits](https://developer.apple.com/support/compare-memberships/)
- [Apple: ReplayKit broadcast sample handler](https://developer.apple.com/documentation/replaykit/rpbroadcastsamplehandler)
- [Apple: system broadcast picker](https://developer.apple.com/documentation/replaykit/rpsystembroadcastpickerview)
- [GitHub: hosted runners and public-repository usage](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [AltStore Classic: Windows setup](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [AltStore Classic: getting started and sideloading](https://faq.altstore.io/altstore-classic/your-altstore)
