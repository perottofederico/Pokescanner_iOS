import Foundation

struct PokemonIVs: Codable, Equatable {
    var attack: Int?
    var defense: Int?
    var stamina: Int?

    var percentage: Double? {
        guard let attack, let defense, let stamina else { return nil }
        return Double(attack + defense + stamina) / 45 * 100
    }

    var roundedPercentage: Int? { percentage.map { Int($0.rounded(.toNearestOrAwayFromZero)) } }

    mutating func fill(from other: PokemonIVs) {
        if attack == nil { attack = other.attack }
        if defense == nil { defense = other.defense }
        if stamina == nil { stamina = other.stamina }
    }
}

struct RecognizedMove: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
}

struct PokemonIdentity: Codable, Equatable {
    let id: Int
    let name: String
    let observedName: String
}

struct PokemonObservation {
    var identity: PokemonIdentity?
    var cp: Int?
    var currentHP: Int?
    var maxHP: Int?
    var moves: [RecognizedMove] = []
    var ivs = PokemonIVs()
    var isDetailScreen = false
    var thumbnail: Data?
    var diagnostics: [String] = []
}

struct ScanDiagnostic: Codable, Equatable {
    let date: Date
    let message: String
}

struct PokemonRecord: Codable, Equatable, Identifiable {
    let id: UUID
    var speciesID: Int
    var species: String
    var observedName: String
    var cp: Int?
    var currentHP: Int?
    var maxHP: Int?
    var moves: [RecognizedMove]
    var ivs: PokemonIVs
    let capturedAt: Date
    var updatedAt: Date
    let source: String
    var thumbnail: Data?
    var diagnostics: [ScanDiagnostic]?
    var manuallyEdited: Bool?

    var displayName: String { observedName.isEmpty ? species : observedName }

    init(observation: PokemonObservation, identity: PokemonIdentity, source: String, date: Date = Date()) {
        id = UUID()
        speciesID = identity.id
        species = identity.name
        observedName = identity.observedName
        cp = observation.cp
        currentHP = observation.currentHP
        maxHP = observation.maxHP
        moves = observation.moves
        ivs = observation.ivs
        capturedAt = date
        updatedAt = date
        self.source = source
        thumbnail = observation.thumbnail
        appendDiagnostics(observation.diagnostics, at: date)
    }

    mutating func appendDiagnostics(_ messages: [String], at date: Date) {
        mergeDiagnostics(messages.map { ScanDiagnostic(date: date, message: $0) })
    }

    mutating func mergeDiagnostics(_ events: [ScanDiagnostic]) {
        var entries = diagnostics ?? []
        for event in events {
            let message = String(event.message.prefix(600))
            if !entries.contains(where: { $0.message == message }) {
                entries.append(ScanDiagnostic(date: event.date, message: message))
            }
        }
        if entries.count > 80 { entries.removeFirst(entries.count - 80) }
        if !entries.isEmpty { diagnostics = entries }
    }

    mutating func fill(from observation: PokemonObservation, at date: Date) -> Bool {
        let previous = self
        if cp == nil { cp = observation.cp }
        if currentHP == nil { currentHP = observation.currentHP }
        if maxHP == nil { maxHP = observation.maxHP }
        for move in observation.moves where !moves.contains(where: { $0.id == move.id }) {
            if moves.count < 3 { moves.append(move) }
        }
        ivs.fill(from: observation.ivs)
        if thumbnail == nil { thumbnail = observation.thumbnail }
        appendDiagnostics(observation.diagnostics, at: date)
        let changed = self != previous
        if changed { updatedAt = date }
        return changed
    }

    func conflicts(with observation: PokemonObservation) -> Bool {
        if let identity = observation.identity, identity.id != speciesID { return true }
        if let cp, let observedCP = observation.cp, cp != observedCP { return true }
        if let maxHP, let observedHP = observation.maxHP, maxHP != observedHP { return true }
        let pairs = [(ivs.attack, observation.ivs.attack), (ivs.defense, observation.ivs.defense),
                     (ivs.stamina, observation.ivs.stamina)]
        return pairs.contains { stored, observed in
            if let stored, let observed { return stored != observed }
            return false
        }
    }
}

final class PokemonTracker {
    private var current: PokemonRecord?
    private var lastDetailAt: Date?
    private var previousObservation: PokemonObservation?
    private var ownershipSuspended = false

    func observe(_ observation: PokemonObservation, at date: Date = Date()) -> PokemonRecord? {
        if let lastDetailAt, date.timeIntervalSince(lastDetailAt) > 12 {
            reset()
        }
        guard observation.isDetailScreen else {
            reset()
            return nil
        }
        lastDetailAt = date
        if let current, current.conflicts(with: observation) { ownershipSuspended = true }
        let previous = previousObservation
        previousObservation = observation
        guard let previous else { return nil }
        let stable = consensus(previous, observation)
        if let current, ownershipSuspended, !current.conflicts(with: previous),
           !current.conflicts(with: observation), stable.identity?.id == current.speciesID,
           let knownCP = current.cp, stable.cp == knownCP {
            ownershipSuspended = false
        }
        if var record = current, !ownershipSuspended,
           !record.conflicts(with: previous), !record.conflicts(with: observation) {
            if record.fill(from: stable, at: date) {
                current = record
                return record
            }
            return nil
        }
        guard let identity = stable.identity else { return nil }
        if let current, !current.conflicts(with: stable) {
            guard ownershipSuspended, !current.conflicts(with: previous),
                  !current.conflicts(with: observation) else { return nil }
        }
        let record = PokemonRecord(observation: stable, identity: identity, source: "Live broadcast", date: date)
        current = record
        ownershipSuspended = false
        return record
    }

    private func reset() {
        current = nil
        lastDetailAt = nil
        previousObservation = nil
        ownershipSuspended = false
    }

    private func consensus(_ previous: PokemonObservation, _ latest: PokemonObservation) -> PokemonObservation {
        var result = PokemonObservation(isDetailScreen: true)
        if previous.identity?.id == latest.identity?.id { result.identity = latest.identity }
        if previous.cp == latest.cp { result.cp = latest.cp }
        if previous.currentHP == latest.currentHP { result.currentHP = latest.currentHP }
        if previous.maxHP == latest.maxHP { result.maxHP = latest.maxHP }
        if previous.ivs.attack == latest.ivs.attack { result.ivs.attack = latest.ivs.attack }
        if previous.ivs.defense == latest.ivs.defense { result.ivs.defense = latest.ivs.defense }
        if previous.ivs.stamina == latest.ivs.stamina { result.ivs.stamina = latest.ivs.stamina }
        result.moves = latest.moves.filter { move in previous.moves.contains(where: { $0.id == move.id }) }
        if result.identity != nil { result.thumbnail = latest.thumbnail ?? previous.thumbnail }
        result.diagnostics = previous.diagnostics + latest.diagnostics
        result.diagnostics.append("CP consensus: previous=\(previous.cp.map(String.init) ?? "missing"), latest=\(latest.cp.map(String.init) ?? "missing"), confirmed=\(result.cp.map(String.init) ?? "missing").")
        return result
    }
}
