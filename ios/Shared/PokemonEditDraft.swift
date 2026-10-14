import Foundation

enum PokemonEditError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

struct PokemonEditDraft {
    var species: String
    var name: String
    var cp: String
    var currentHP: String
    var maxHP: String
    var attack: String
    var defense: String
    var stamina: String
    var moves: [String]

    init(record: PokemonRecord) {
        species = record.species
        name = record.displayName
        cp = record.cp.map(String.init) ?? ""
        currentHP = record.currentHP.map(String.init) ?? ""
        maxHP = record.maxHP.map(String.init) ?? ""
        attack = record.ivs.attack.map(String.init) ?? ""
        defense = record.ivs.defense.map(String.init) ?? ""
        stamina = record.ivs.stamina.map(String.init) ?? ""
        moves = (0..<3).map { $0 < record.moves.count ? record.moves[$0].name : "" }
    }

    func validatedRecord(from original: PokemonRecord, catalog: PokemonCatalog, at date: Date = Date()) throws -> PokemonRecord {
        guard let entry = catalog.species.first(where: {
            $0.aliases.contains { PokemonCatalog.normalize($0) == PokemonCatalog.normalize(species) }
        }) else { throw PokemonEditError.invalid("Enter a recognized English or Italian species name.") }
        var result = original
        result.speciesID = entry.id
        result.species = entry.name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count <= 80 else { throw PokemonEditError.invalid("The display name must be at most 80 characters.") }
        result.observedName = trimmedName.isEmpty ? entry.name : trimmedName
        result.cp = try number(cp, label: "CP", range: 1...20000)
        result.currentHP = try number(currentHP, label: "Current HP", range: 0...2000)
        result.maxHP = try number(maxHP, label: "Maximum HP", range: 1...2000)
        if let current = result.currentHP, let maximum = result.maxHP, current > maximum {
            throw PokemonEditError.invalid("Current HP cannot exceed maximum HP.")
        }
        result.ivs = PokemonIVs(attack: try number(attack, label: "Attack IV", range: 0...15),
                               defense: try number(defense, label: "Defense IV", range: 0...15),
                               stamina: try number(stamina, label: "Stamina IV", range: 0...15))
        result.moves = []
        for text in moves where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let move = catalog.moves.first(where: {
                $0.aliases.contains { PokemonCatalog.normalize($0) == PokemonCatalog.normalize(text) }
            }) else { throw PokemonEditError.invalid("Unknown move '\(text)'. Enter its full English or Italian name, or leave it empty.") }
            guard !result.moves.contains(where: { $0.id == move.id }) else {
                throw PokemonEditError.invalid("A move cannot be entered twice.")
            }
            result.moves.append(RecognizedMove(id: move.id, name: move.name))
        }
        result.updatedAt = date
        result.manuallyEdited = true
        result.appendDiagnostics(["Manually edited; future scan snapshots cannot overwrite edited fields."], at: date)
        return result
    }

    private func number(_ text: String, label: String, range: ClosedRange<Int>) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard trimmed.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(trimmed), range.contains(value) else {
            throw PokemonEditError.invalid("\(label) must be a whole number from \(range.lowerBound) to \(range.upperBound), or empty.")
        }
        return value
    }
}
