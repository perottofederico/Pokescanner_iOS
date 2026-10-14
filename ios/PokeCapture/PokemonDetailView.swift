import SwiftUI

struct PokemonDetailView: View {
    @EnvironmentObject private var library: PokemonLibrary
    @Environment(\.dismiss) private var dismiss
    let recordID: UUID
    @State private var editing = false
    @State private var confirmingRemoval = false

    var body: some View {
        if let record = library.records.first(where: { $0.id == recordID }) {
            List {
                Section("Pokémon") {
                    HStack {
                        Spacer()
                        PokemonThumbnail(data: record.thumbnail, size: 200)
                        Spacer()
                    }
                    LabeledContent("Name", value: record.displayName)
                    LabeledContent("Species", value: record.species)
                    LabeledContent("Pokédex number", value: "\(record.speciesID)")
                    LabeledContent("Read name", value: record.observedName)
                }
                Section("Statistics") {
                    LabeledContent("CP", value: record.cp.map(String.init) ?? "Not detected")
                    LabeledContent("Current HP", value: record.currentHP.map(String.init) ?? "Not detected")
                    LabeledContent("Maximum HP", value: record.maxHP.map(String.init) ?? "Not detected")
                }
                Section {
                    ivRow("Attack", value: record.ivs.attack)
                    ivRow("Defense", value: record.ivs.defense)
                    ivRow("HP / Stamina", value: record.ivs.stamina)
                    HStack {
                        Text("IV total")
                        Spacer()
                        IVBadge(ivs: record.ivs, size: 64)
                    }
                } header: {
                    Text("Appraisal IVs")
                } footer: {
                    Text("IV values are estimated from visible bar lengths, not CP. Unclear or obstructed bars remain empty.")
                }
                Section {
                    if record.moves.isEmpty {
                        Text("Not detected").foregroundStyle(.secondary)
                    } else {
                        ForEach(record.moves) { move in Text(move.name) }
                    }
                } header: {
                    Text("Moves detected")
                } footer: {
                    Text("Only fully readable move names are saved. Scroll to the moves before switching Pokémon; an appraisal overlay can hide them.")
                }
                Section("Capture") {
                    LabeledContent("Source", value: record.source)
                    LabeledContent("Saved", value: record.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Updated", value: record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    if record.manuallyEdited == true { Text("Manually edited; scan updates cannot overwrite these fields.").font(.caption) }
                }
                Section {
                    DisclosureGroup("Temporary scan diagnostics") {
                        Text(diagnosticsText(record))
                            .font(.caption.monospaced()).textSelection(.enabled)
                        ShareLink(item: diagnosticsText(record)) {
                            Label("Share diagnostics", systemImage: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text("Includes CP attempts, top-screen OCR text/confidence/positions, image size, and live frame agreement. Up to 80 events are retained. Review before sharing; top-screen text can include private notifications.")
                }
            }
            .navigationTitle(record.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Edit") { editing = true }.disabled(library.isMutating)
                    Button(role: .destructive) { confirmingRemoval = true } label: {
                        Label("Remove", systemImage: "trash")
                    }.disabled(library.isMutating)
                }
            }
            .sheet(isPresented: $editing) { PokemonEditView(record: record) }
            .confirmationDialog("Remove \(record.displayName)?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                Button("Remove Pokémon", role: .destructive) {
                    Task { if await library.delete([record.id]) { dismiss() } }
                }
                Button("Cancel", role: .cancel) { }
            } message: { Text("This scan will not be re-imported automatically.") }
            .alert("Collection", isPresented: Binding(
                get: { library.message != nil && !editing }, set: { if !$0 { library.message = nil } }
            )) {
                Button("OK", role: .cancel) { library.message = nil }
            } message: { Text(library.message ?? "") }
        } else {
            Text("This record is unavailable.")
        }
    }

    private func diagnosticsText(_ record: PokemonRecord) -> String {
        guard let events = record.diagnostics, !events.isEmpty else {
            return "No diagnostics were stored for this scan. Scan or import it again with the updated app."
        }
        return events.map { "\($0.date.formatted(date: .abbreviated, time: .standard)) — \($0.message)" }.joined(separator: "\n\n")
    }

    private func ivRow(_ title: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(title, value: value.map { "\($0) / 15" } ?? "Not detected")
            if let value {
                ProgressView(value: Double(value), total: 15).tint(value == 15 ? .pink : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}
