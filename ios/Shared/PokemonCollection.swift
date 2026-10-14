import Foundation

enum PokemonSort: String, CaseIterable, Identifiable {
    case iv = "IV"
    case cp = "CP"
    case pokedex = "Pokédex number"
    case date = "Scan date"
    case name = "Name"

    var id: String { rawValue }
    var defaultAscending: Bool { self == .name || self == .pokedex }

    func sorted(_ records: [PokemonRecord], ascending: Bool) -> [PokemonRecord] {
        records.sorted { left, right in
            switch self {
            case .iv:
                if let result = compare(left.ivs.roundedPercentage, right.ivs.roundedPercentage, ascending: ascending) { return result }
            case .cp:
                if let result = compare(left.cp, right.cp, ascending: ascending) { return result }
            case .pokedex:
                if left.speciesID != right.speciesID { return ascending ? left.speciesID < right.speciesID : left.speciesID > right.speciesID }
            case .date:
                if left.capturedAt != right.capturedAt { return ascending ? left.capturedAt < right.capturedAt : left.capturedAt > right.capturedAt }
            case .name:
                let order = left.displayName.localizedCaseInsensitiveCompare(right.displayName)
                if order != .orderedSame { return ascending ? order == .orderedAscending : order == .orderedDescending }
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private func compare(_ left: Int?, _ right: Int?, ascending: Bool) -> Bool? {
        switch (left, right) {
        case (nil, nil): return nil
        case (nil, _): return false
        case (_, nil): return true
        case let (left?, right?): return left == right ? nil : (ascending ? left < right : left > right)
        }
    }
}

struct PokemonCollection: Codable {
    var records: [PokemonRecord] = []
    var deletedIDs: Set<UUID> = []

    static func decode(_ data: Data) throws -> PokemonCollection {
        let decoder = JSONDecoder()
        if let collection = try? decoder.decode(Self.self, from: data) { return collection }
        return PokemonCollection(records: try decoder.decode([PokemonRecord].self, from: data))
    }

    mutating func merge(_ scans: [PokemonRecord]) -> Bool {
        var indexed = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        var changed = false
        for incoming in scans where !deletedIDs.contains(incoming.id) {
            if var local = indexed[incoming.id], local.manuallyEdited == true {
                guard incoming.updatedAt > local.updatedAt else { continue }
                let previous = local
                local.mergeDiagnostics(incoming.diagnostics ?? [])
                if local.thumbnail == nil { local.thumbnail = incoming.thumbnail }
                local.updatedAt = incoming.updatedAt
                if local != previous { indexed[local.id] = local; changed = true }
            } else if indexed[incoming.id] == nil || (indexed[incoming.id]?.updatedAt ?? .distantPast) < incoming.updatedAt {
                indexed[incoming.id] = incoming
                changed = true
            }
        }
        if changed { records = indexed.values.sorted { $0.capturedAt > $1.capturedAt } }
        return changed
    }

    mutating func delete(_ ids: Set<UUID>) {
        deletedIDs.formUnion(ids)
        records.removeAll { ids.contains($0.id) }
    }

    mutating func update(_ record: PokemonRecord) throws {
        guard !deletedIDs.contains(record.id), let index = records.firstIndex(where: { $0.id == record.id }) else {
            throw PokemonEditError.invalid("This Pokémon was removed. Its edits cannot be saved.")
        }
        var updated = record
        updated.mergeDiagnostics(records[index].diagnostics ?? [])
        if updated.thumbnail == nil { updated.thumbnail = records[index].thumbnail }
        records[index] = updated
    }
}
