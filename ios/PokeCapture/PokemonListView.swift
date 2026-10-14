import PhotosUI
import SwiftUI

struct PokemonListView: View {
    @EnvironmentObject private var library: PokemonLibrary
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(library.isImporting ? "Reading screenshot…" : "Import a screenshot", systemImage: "photo")
                }
                .disabled(library.isImporting)
                if library.isImporting { ProgressView() }
                if let warning = library.storageWarning {
                    Text(warning).font(.caption).foregroundStyle(.orange)
                }
            } footer: {
                Text("English and Italian text are supported. Unreadable fields remain empty; screenshots are not stored.")
            }
            if library.records.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No Pokémon saved yet", systemImage: "tray")
                            .font(.headline)
                        Text("Import your example image, or open Scan and start a broadcast. Hold each Pokémon's detail and appraisal pages steady for a few seconds.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
            } else {
                Section("Saved Pokémon (\(library.records.count))") {
                    ForEach(library.records) { record in
                        NavigationLink {
                            PokemonDetailView(recordID: record.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.species).font(.headline)
                                HStack {
                                    Text(record.cp.map { "CP \($0)" } ?? "CP not detected")
                                    Spacer()
                                    Text(record.ivs.percentage.map { String(format: "%.1f%% IV", $0) } ?? "IVs incomplete")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                Text(record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pokémon")
        .refreshable { library.refresh() }
        .onChange(of: selectedPhoto) { photo in
            guard let photo else { return }
            Task {
                do {
                    if let data = try await photo.loadTransferable(type: Data.self) {
                        await library.importScreenshot(data)
                    } else {
                        library.message = "The selected photo could not be loaded."
                    }
                } catch {
                    library.message = error.localizedDescription
                }
                selectedPhoto = nil
            }
        }
        .alert("Recognition", isPresented: Binding(
            get: { library.message != nil },
            set: { if !$0 { library.message = nil } }
        )) {
            Button("OK", role: .cancel) { library.message = nil }
        } message: {
            Text(library.message ?? "")
        }
    }
}
