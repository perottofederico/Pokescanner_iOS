import CoreGraphics
import Foundation
import ImageIO

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
        print(observation.diagnostics.joined(separator: "\n"))
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
        let firstMoveFrame = tracker.observe(movePage, at: date.addingTimeInterval(3.9))
        try require(firstMoveFrame == nil || firstMoveFrame?.moves.isEmpty == true,
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
        try checkCollection(catalog: catalog, observation: observation, partial: partialRecord)
        try checkCPParser()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try RecognitionStorage.save(partialRecord, directory: temporary)
        let restored = try RecognitionStorage.read(directory: temporary)
        try require(restored.records == [partialRecord], "Outbox persistence must preserve partial records.")
        try Data("not json".utf8).write(to: temporary.appendingPathComponent("broken.json"))
        let mixed = try RecognitionStorage.read(directory: temporary)
        try require(mixed.records == [partialRecord] && mixed.rejectedFiles == ["broken.json"],
                    "An unreadable scan must not hide valid records.")
        print("PASS: Apple Vision example, CP pairing, IV pixels/rounding, thumbnails, diagnostics, sorting, protected edits/deletions, migration, and persistence.")
    }

    static func checkCPParser() throws {
        let label = OCRLine(text: "CP", confidence: 0.30, rect: CGRect(x: 0.32, y: 0.04, width: 0.06, height: 0.025))
        let digits = OCRLine(text: "3583", confidence: 0.95, rect: CGRect(x: 0.39, y: 0.035, width: 0.19, height: 0.04))
        let split = CPReader.read([label, digits])
        try require(split.value == 3583 && split.diagnostics.contains(where: { $0.contains("paired") }),
                    "CP labels and digits in separate aligned OCR boxes must be paired and logged.")
        try require(CPReader.read([digits]).value == nil, "An unlabeled number must not be guessed to be CP.")
        let unrelated = OCRLine(text: "4200", confidence: 1, rect: CGRect(x: 0.7, y: 0.25, width: 0.15, height: 0.04))
        try require(CPReader.read([label, unrelated]).value == nil, "CP pairing must reject spatially unrelated numbers.")
        for prefix in ["CP", "PC", "PL"] {
            let inline = OCRLine(text: prefix + " 3 583", confidence: 1, rect: CGRect(x: 0.3, y: 0.25, width: 0.4, height: 0.025))
            try require(CPReader.read([inline]).value == 3583, "Supported CP labels and spaced digits should parse.")
        }
        let alternative = OCRLine(text: "CP 4000", confidence: 1, rect: CGRect(x: 0.3, y: 0.1, width: 0.3, height: 0.025))
        try require(CPReader.read([label, digits, alternative]).value == nil, "Conflicting CP candidates must remain missing.")
        let invalid = OCRLine(text: "CP 90000", confidence: 1, rect: label.rect)
        try require(CPReader.read([invalid]).value == nil, "Out-of-range CP must remain missing.")
    }

    static func checkCollection(catalog: PokemonCatalog, observation: PokemonObservation, partial: PokemonRecord) throws {
        try require(observation.thumbnail != nil, "The example should produce a cropped Pokémon image.")
        if let data = observation.thumbnail, let source = CGImageSourceCreateWithData(data as CFData, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            try require(max(image.width, image.height) <= 240, "Stored thumbnails must be small JPEGs.")
        } else {
            try require(false, "The stored thumbnail must decode as an image.")
        }
        try require(observation.diagnostics.contains(where: { $0.contains("CP accepted") }), "CP scan diagnostics must be retained.")
        try require(PokemonIVs(attack: 15, defense: 14, stamina: 15).roundedPercentage == 98, "97.8 percent must round up to 98.")
        try require(PokemonIVs(attack: 15, defense: 13, stamina: 15).roundedPercentage == 96, "95.6 percent must round up to 96.")
        try require(PokemonIVs(attack: 15, defense: 12, stamina: 15).roundedPercentage == 93, "93.3 percent must round down to 93.")
        try require(PokemonIVs().roundedPercentage == nil, "Incomplete IVs must not display zero percent.")
        for (value, band) in [(0, IVRating.grey), (60, .grey), (61, .blue), (80, .blue), (81, .green),
                              (95, .green), (96, .orange), (99, .orange), (100, .purple)] {
            try require(IVRating.band(for: value) == band, "IV color boundary \(value) is incorrect.")
        }
        let date = Date(timeIntervalSince1970: 1000)
        let scanned = PokemonRecord(observation: observation, identity: observation.identity!, source: "Test", date: date)
        var weaker = PokemonRecord(observation: PokemonObservation(identity: PokemonIdentity(id: 25, name: "Pikachu", observedName: "Pikachu"), cp: 500, ivs: PokemonIVs(attack: 5, defense: 5, stamina: 5)),
                                   identity: PokemonIdentity(id: 25, name: "Pikachu", observedName: "Pikachu"), source: "Test", date: date.addingTimeInterval(10))
        weaker.observedName = "Alpha"
        let list = [partial, scanned, weaker]
        for ascending in [true, false] {
            try require(PokemonSort.cp.sorted(list, ascending: ascending).last?.id == partial.id, "Missing CP must sort last in both directions.")
            try require(PokemonSort.iv.sorted(list, ascending: ascending).last?.id == partial.id, "Incomplete IVs must sort last in both directions.")
        }
        try require(PokemonSort.cp.sorted(list, ascending: false).first?.id == scanned.id, "CP sorting must order numeric values.")
        try require(PokemonSort.iv.sorted(list, ascending: false).first?.id == scanned.id, "IV sorting must order numeric values.")
        try require(PokemonSort.pokedex.sorted(list, ascending: true).first?.id == weaker.id, "Pokédex sorting must be numeric.")
        try require(PokemonSort.name.sorted(list, ascending: true).first?.id == weaker.id, "Name sorting must use the display name.")
        try require(PokemonSort.date.sorted([scanned, weaker], ascending: false).first?.id == weaker.id, "Date sorting must use scan dates.")
        var draft = PokemonEditDraft(record: scanned)
        draft.cp = "4000"
        draft.name = "My Haxorus"
        draft.defense = ""
        draft.moves[0] = "Dragon Tail"
        let edited = try draft.validatedRecord(from: scanned, catalog: catalog, at: date.addingTimeInterval(20))
        try require(edited.cp == 4000 && edited.ivs.defense == nil && edited.moves.count == 1 && edited.manuallyEdited == true,
                    "Edits must validate values, allow missing fields, and protect manual changes.")
        draft.attack = "16"
        do {
            _ = try draft.validatedRecord(from: scanned, catalog: catalog)
            try require(false, "Out-of-range IV edits must be rejected.")
        } catch is PokemonEditError { }
        var collection = PokemonCollection(records: [scanned])
        var intermediate = scanned
        intermediate.appendDiagnostics(["Diagnostic received while editing"], at: date.addingTimeInterval(15))
        intermediate.updatedAt = date.addingTimeInterval(15)
        _ = collection.merge([intermediate])
        try collection.update(edited)
        try require(collection.records.first?.diagnostics?.contains(where: { $0.message == "Diagnostic received while editing" }) == true,
                    "Saving an edit must not discard diagnostic events received while the editor was open.")
        var later = scanned
        later.updatedAt = date.addingTimeInterval(30)
        later.appendDiagnostics(["New scan diagnostic"], at: later.updatedAt)
        _ = collection.merge([later])
        try require(collection.records.first?.cp == 4000 && collection.records.first?.displayName == "My Haxorus"
                    && collection.records.first?.ivs.defense == nil, "Re-importing scans must not overwrite manual edits.")
        try require(collection.records.first?.diagnostics?.contains(where: { $0.message == "New scan diagnostic" }) == true,
                    "Manual edits should still receive new diagnostics.")
        try require(!collection.merge([later]), "Repeated scan imports must not keep rewriting manually edited records.")
        collection.delete([scanned.id])
        let persisted = try JSONEncoder().encode(collection)
        var restored = try PokemonCollection.decode(persisted)
        _ = restored.merge([later])
        try require(restored.records.isEmpty && restored.deletedIDs.contains(scanned.id), "Deleted scans must not resurrect after persistence and re-import.")
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(scanned)) as! [String: Any]
        var legacy = object
        for key in ["thumbnail", "diagnostics", "manuallyEdited"] { legacy.removeValue(forKey: key) }
        let migrated = try PokemonCollection.decode(JSONSerialization.data(withJSONObject: [legacy]))
        try require(migrated.records.count == 1 && migrated.records[0].thumbnail == nil && migrated.records[0].diagnostics == nil,
                    "Old records and the legacy array format must load without thumbnails or diagnostics.")
        var bounded = scanned
        bounded.appendDiagnostics((0..<100).map { "Event \($0)" }, at: date)
        try require(bounded.diagnostics?.count == 80, "Diagnostic storage must be bounded.")
        let repeated = String(repeating: "x", count: 700)
        bounded.appendDiagnostics([repeated, repeated], at: date)
        try require(bounded.diagnostics?.filter { $0.message == String(repeated.prefix(600)) }.count == 1,
                    "Repeated diagnostics must be truncated and deduplicated.")
    }
}
