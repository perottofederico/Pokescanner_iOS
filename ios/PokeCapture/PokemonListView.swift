import PhotosUI
import SwiftUI

struct PokemonListView: View {
    @EnvironmentObject private var library: PokemonLibrary
    @State private var selectedPhoto: PhotosPickerItem?
    @AppStorage("pokemonSort") private var sortName = PokemonSort.date.rawValue
    @AppStorage("pokemonSortAscending") private var ascending = false
    @State private var pendingDeletion: PokemonRecord?
    @State private var confirmingRemoval = false

    private var sort: PokemonSort { PokemonSort(rawValue: sortName) ?? .date }
    private var sortedRecords: [PokemonRecord] { sort.sorted(library.records, ascending: ascending) }

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
                Text("English and Italian text are supported. Unreadable fields remain empty. Cropped Pokémon images and temporary top-screen OCR diagnostics are saved locally.")
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
                    ForEach(sortedRecords) { record in
                        NavigationLink {
                            PokemonDetailView(recordID: record.id)
                        } label: {
                            HStack(spacing: 10) {
                                PokemonThumbnail(data: record.thumbnail)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.displayName).font(.headline)
                                    Text(record.cp.map { "CP \($0)" } ?? "CP not detected")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text("#\(record.speciesID) · " + record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                IVBadge(ivs: record.ivs)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions {
                            Button("Remove", role: .destructive) { pendingDeletion = record; confirmingRemoval = true }
                                .disabled(library.isMutating)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pokémon")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $sortName) {
                        ForEach(PokemonSort.allCases) { option in Text(option.rawValue).tag(option.rawValue) }
                    }
                    Toggle("Ascending", isOn: $ascending)
                } label: { Label("Sort by \(sort.rawValue)", systemImage: "arrow.up.arrow.down") }
            }
        }
        .onChange(of: sortName) { value in ascending = (PokemonSort(rawValue: value) ?? .date).defaultAscending }
        .confirmationDialog("Remove \(pendingDeletion?.displayName ?? "Pokémon")?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Remove Pokémon", role: .destructive) {
                if let record = pendingDeletion { Task { _ = await library.delete([record.id]) } }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { Text("This scan will be removed from your collection and will not be re-imported automatically.") }
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
