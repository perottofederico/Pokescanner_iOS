import SwiftUI

struct PokemonEditView: View {
    @EnvironmentObject private var library: PokemonLibrary
    @Environment(\.dismiss) private var dismiss
    let record: PokemonRecord
    @State private var draft: PokemonEditDraft
    @State private var errorMessage: String?
    @State private var saving = false

    init(record: PokemonRecord) {
        self.record = record
        _draft = State(initialValue: PokemonEditDraft(record: record))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pokémon") {
                    TextField("Species", text: $draft.species)
                    TextField("Display name", text: $draft.name)
                }
                Section {
                    numberField("CP", text: $draft.cp)
                    numberField("Current HP", text: $draft.currentHP)
                    numberField("Maximum HP", text: $draft.maxHP)
                } header: {
                    Text("Statistics")
                } footer: {
                    Text("Leave a field empty if unknown. CP: 1–20000. HP: 0–2000; maximum HP must be positive.")
                }
                Section {
                    numberField("Attack", text: $draft.attack)
                    numberField("Defense", text: $draft.defense)
                    numberField("HP / Stamina", text: $draft.stamina)
                } header: {
                    Text("IVs (0–15)")
                }
                Section {
                    ForEach(0..<3, id: \.self) { index in
                        TextField("Move \(index + 1)", text: $draft.moves[index])
                    }
                } header: {
                    Text("Moves")
                } footer: {
                    Text("Use full English or Italian species and move names. Saved edits are protected from later scan updates; diagnostics can still be added.")
                }
            }
            .disabled(saving)
            .navigationTitle("Edit Pokémon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { save() }
                        .disabled(saving || library.isMutating)
                }
            }
            .interactiveDismissDisabled(saving)
            .alert("Could not save", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Not detected", text: text)
                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
        }
    }

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            do {
                let catalog = try PokemonCatalog.load()
                let updated = try draft.validatedRecord(from: record, catalog: catalog)
                if await library.update(updated) {
                    dismiss()
                } else {
                    errorMessage = library.message ?? "Edits could not be saved."
                    library.message = nil
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
