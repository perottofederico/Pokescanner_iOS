import CoreGraphics
import Foundation

@main
struct RecognitionCheck {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "RecognitionCheck", code: 1,
                                       userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func main() throws {
        let catalog = try PokemonCatalog.load(url: URL(fileURLWithPath: "ios/Resources/pokemon-catalog.json"))
        let engine = RecognitionEngine(catalog: catalog)
        let observation = try engine.scan(data: Data(contentsOf: URL(fileURLWithPath: "assets/recognition-example.jpg")))
        print("Example OCR: species=\(observation.identity?.name ?? "missing"), CP=\(observation.cp.map(String.init) ?? "missing"), HP=\(observation.maxHP.map(String.init) ?? "missing")")
        print("Example bars: \(observation.ivs.attack.map(String.init) ?? "missing")/\(observation.ivs.defense.map(String.init) ?? "missing")/\(observation.ivs.stamina.map(String.init) ?? "missing")")
        try require(observation.identity?.name == "Haxorus", "Expected Haxorus in the supplied screenshot.")
        try require(observation.cp == 3583, "Expected CP 3583.")
        try require(observation.currentHP == 156 && observation.maxHP == 156, "Expected HP 156/156.")
        try require(observation.ivs == PokemonIVs(attack: 15, defense: 14, stamina: 15), "Expected visible appraisal bars 15/14/15.")
        try require(observation.moves.isEmpty, "Do not guess moves hidden by the appraisal overlay.")

        let parser = PokemonTextParser(catalog: catalog)
        let header = OCRLine(text: "Haxorus", confidence: 1, rect: CGRect(x: 0.3, y: 0.37, width: 0.3, height: 0.025))
        let partial = parser.parse([header,
            OCRLine(text: "WEIGHT", confidence: 1, rect: CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.02)),
            OCRLine(text: "HEIGHT", confidence: 1, rect: CGRect(x: 0.7, y: 0.5, width: 0.2, height: 0.02))])
        try require(partial.identity?.name == "Haxorus" && partial.cp == nil && partial.maxHP == nil,
                    "Recognizable species must survive missing statistics.")
        let partialRecord = PokemonRecord(observation: partial, identity: partial.identity!, source: "Fixture")
        let decoded = try JSONDecoder().decode(PokemonRecord.self, from: JSONEncoder().encode(partialRecord))
        try require(decoded == partialRecord && decoded.ivs.attack == nil, "Partial records must round-trip without inventing zero IVs.")

        let tracker = PokemonTracker()
        let date = Date()
        try require(tracker.observe(observation, at: date) == nil, "A live identity must be stable across two frames.")
        let first = tracker.observe(observation, at: date.addingTimeInterval(1.3))
        try require(first != nil, "Stable live Pokémon should be saved.")
        try require(tracker.observe(observation, at: date.addingTimeInterval(2.6)) == nil,
                    "Repeated unchanged frames must not duplicate records.")
        let movePage = PokemonObservation(moves: [RecognizedMove(id: 525, name: "Dragon Tail")], isDetailScreen: true)
        try require(tracker.observe(movePage, at: date.addingTimeInterval(3.9)) == nil,
                    "A move must not be committed from only one frame.")
        let enriched = tracker.observe(movePage, at: date.addingTimeInterval(5.2))
        try require(enriched?.id == first?.id && enriched?.moves.count == 1,
                    "A nearby moves page must enrich the current record.")
        var other = observation
        other.cp = 2000
        try require(tracker.observe(other, at: date.addingTimeInterval(6.5)) == nil, "Changed CP must establish a new stable identity.")
        let second = tracker.observe(other, at: date.addingTimeInterval(7.8))
        try require(second != nil && second?.id != first?.id && second?.cp == 2000,
                    "Two same-species Pokémon with different CP must not be merged.")
        try require(tracker.observe(PokemonObservation(), at: date.addingTimeInterval(9)) == nil,
                    "Non-detail navigation must clear record ownership.")
        try require(tracker.observe(movePage, at: date.addingTimeInterval(10.3)) == nil,
                    "An identity-less moves page after navigation must not enrich the previous Pokémon.")
        try require(tracker.observe(observation, at: date.addingTimeInterval(30)) == nil,
                    "The first frame after a timeout starts a new candidate.")
        try require(tracker.observe(observation, at: date.addingTimeInterval(31.3)) != nil,
                    "Recognition must recover after a timeout.")
        for changedSpecies in [false, true] {
            let ownershipTracker = PokemonTracker()
            _ = ownershipTracker.observe(observation, at: date)
            let owner = ownershipTracker.observe(observation, at: date.addingTimeInterval(1.3))
            var conflicting = observation
            if changedSpecies {
                conflicting.identity = PokemonIdentity(id: 25, name: "Pikachu", observedName: "Pikachu")
            } else {
                conflicting.cp = 2000
            }
            try require(ownershipTracker.observe(conflicting, at: date.addingTimeInterval(2.6)) == nil,
                        "One contradictory frame must suspend ownership without saving a new record.")
            _ = ownershipTracker.observe(movePage, at: date.addingTimeInterval(3.9))
            try require(ownershipTracker.observe(movePage, at: date.addingTimeInterval(5.2)) == nil,
                        "Identity-less moves must not enrich a record after contradictory evidence.")
            _ = ownershipTracker.observe(observation, at: date.addingTimeInterval(6.5))
            _ = ownershipTracker.observe(observation, at: date.addingTimeInterval(7.8))
            _ = ownershipTracker.observe(movePage, at: date.addingTimeInterval(9.1))
            let recovered = ownershipTracker.observe(movePage, at: date.addingTimeInterval(10.4))
            try require(recovered?.id == owner?.id && recovered?.moves.count == 1,
                        "Two positively matching frames may restore ownership after a transient OCR error.")
        }
        let partialOwnerTracker = PokemonTracker()
        _ = partialOwnerTracker.observe(partial, at: date)
        let partialOwner = partialOwnerTracker.observe(partial, at: date.addingTimeInterval(1.3))
        var differentSpecies = observation
        differentSpecies.identity = PokemonIdentity(id: 25, name: "Pikachu", observedName: "Pikachu")
        _ = partialOwnerTracker.observe(differentSpecies, at: date.addingTimeInterval(2.6))
        _ = partialOwnerTracker.observe(partial, at: date.addingTimeInterval(3.9))
        let newPartialOwner = partialOwnerTracker.observe(partial, at: date.addingTimeInterval(5.2))
        try require(newPartialOwner != nil && newPartialOwner?.id != partialOwner?.id,
                    "Species alone must not restore a partial record after contradictory navigation.")
        _ = partialOwnerTracker.observe(movePage, at: date.addingTimeInterval(6.5))
        let newPartialMoves = partialOwnerTracker.observe(movePage, at: date.addingTimeInterval(7.8))
        try require(newPartialMoves?.id == newPartialOwner?.id && newPartialMoves?.id != partialOwner?.id,
                    "Moves after re-identification belong to the new partial record, not the old one.")
        let uncertainTracker = PokemonTracker()
        var disagreement = observation
        disagreement.ivs.defense = 12
        _ = uncertainTracker.observe(disagreement, at: date)
        let uncertain = uncertainTracker.observe(observation, at: date.addingTimeInterval(1.3))
        try require(uncertain?.ivs.defense == nil, "Disagreeing IV measurements must remain missing.")
        let corrected = uncertainTracker.observe(observation, at: date.addingTimeInterval(2.6))
        try require(corrected?.ivs.defense == 14 && corrected?.id == uncertain?.id,
                    "Repeated agreeing IVs should enrich the partial record.")
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try RecognitionStorage.save(partialRecord, directory: temporary)
        let restored = try RecognitionStorage.read(directory: temporary)
        try require(restored.records == [partialRecord], "Outbox persistence must preserve partial records.")
        try Data("not json".utf8).write(to: temporary.appendingPathComponent("broken.json"))
        let mixed = try RecognitionStorage.read(directory: temporary)
        try require(mixed.records == [partialRecord] && mixed.rejectedFiles == ["broken.json"],
                    "An unreadable scan must not hide valid records.")
        print("PASS: Apple Vision example, IV pixels, partial records, stable-session merging, and persistence.")
    }
}
