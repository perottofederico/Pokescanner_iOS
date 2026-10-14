import SwiftUI

struct PokemonDetailView: View {
    @EnvironmentObject private var library: PokemonLibrary
    let recordID: UUID

    var body: some View {
        if let record = library.records.first(where: { $0.id == recordID }) {
            List {
                Section("Pokémon") {
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
                    LabeledContent("IV total", value: record.ivs.percentage.map {
                        String(format: "%.1f%%", $0)
                    } ?? "Not detected")
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
                }
            }
            .navigationTitle(record.species)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("This record is unavailable.")
        }
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
