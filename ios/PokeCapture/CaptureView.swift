import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var library: PokemonLibrary
    @StateObject private var monitor = BroadcastMonitor()
    private let extensionIdentifier = EmbeddedBroadcast.identifier

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    diagnostics
                    controls
                    instructions
                    privacy
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Poke Capture")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("LIVE POKÉMON RECOGNITION", systemImage: "record.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)
            Text("Scan. Appraise. Save.")
                .font(.largeTitle.weight(.bold))
            Text("Start a broadcast, open Pokémon GO, and hold each Pokémon's detail, appraisal, and moves screens steady for a few seconds. Readable fields are combined in your saved list.")
                .foregroundStyle(.secondary)
        }
    }

    private var diagnostics: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let receiving = monitor.hasRecentVideo(at: context.date)
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    receiving ? "Receiving live video" : "No recent video confirmed",
                    systemImage: receiving ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(.headline)
                .foregroundStyle(receiving ? Color.green : Color.secondary)
                Text(monitor.lifecycle)
                LabeledContent("Saved Pokémon", value: "\(library.records.count)")
                if let problem = monitor.recognitionProblem {
                    Text(problem).foregroundStyle(.orange)
                }
                #if !targetEnvironment(simulator)
                if library.sharedDirectory == nil {
                    Text(RecognitionError.sharedStorageUnavailable.localizedDescription)
                        .foregroundStyle(.orange)
                }
                #endif
                LabeledContent("Video heartbeats observed", value: "\(monitor.heartbeatCount)")
                    .font(.subheadline.monospacedDigit())
                if let lastVideoAt = monitor.lastVideoAt {
                    Text("Last observed video: \(lastVideoAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                }
                Text("This is best-effort foreground telemetry, not a total frame count. If signals are missed, use the iOS recording indicator and broadcast controls to check or stop capture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screen broadcast")
                .font(.title2.weight(.semibold))
            #if targetEnvironment(simulator)
            Label("Capture requires a physical iPhone or iPad.", systemImage: "iphone")
            Text("The simulator only checks that this app builds and launches. It cannot pass the live-capture test.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            #else
            if let extensionIdentifier {
                HStack(spacing: 16) {
                    BroadcastPicker(extensionIdentifier: extensionIdentifier)
                        .frame(width: 64, height: 64)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tap the recording icon")
                            .font(.headline)
                        Text("Then confirm Start Broadcast in the iOS dialog. Use the same controls to stop.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Label("Broadcast extension missing", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Reinstall the IPA and choose Keep App Extensions in your sideloading tool. The broadcast extension is required.")
                    .font(.subheadline)
            }
            #endif
            if let extensionIdentifier {
                Text("Embedded provider: \(extensionIdentifier)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device test")
                .font(.title2.weight(.semibold))
            Text("1. Start Broadcast and wait for the countdown.")
            Text("2. Verify the red iOS recording indicator and live video status here.")
            Text("3. Hold the detail, appraisal, and moves pages for 3–5 seconds each. Keep the species name visible on the first page.")
            Text("4. Return to the Pokémon tab to inspect saved records, including partial scans.")
            Text("5. Stop using the red iOS indicator or broadcast controls. Heartbeats should stop.")
        }
        .font(.subheadline)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("On-device recognition", systemImage: "lock.shield")
                .font(.headline)
            Text("Species names, CP, HP, moves, IVs, a cropped Pokémon image, and temporary top-screen OCR diagnostics are saved locally. Full frames and audio are discarded; there are no network uploads or saved recordings. Diagnostics can include notification text; inspect them before sharing. Name-based recognition supports English/Italian; nickname-only and 3D-model-only recognition are not supported yet.")
            Text("iOS may warn that everything on screen is captured. Avoid passwords and private notifications; stop the broadcast when you finish testing.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
