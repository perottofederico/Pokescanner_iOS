import Foundation

struct StoredScanBatch {
    var records: [PokemonRecord] = []
    var rejectedFiles: [String] = []
}

enum RecognitionStorage {
    static let groupIdentifier = "group.com.pokecapture.shared"

    static var sharedDirectory: URL? {
        #if targetEnvironment(simulator)
        return nil
        #else
        let rewritten = (Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? [])
            .filter { $0 == groupIdentifier || $0.hasPrefix(groupIdentifier + ".") }
        for identifier in rewritten + [groupIdentifier] {
            if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
                return container.appendingPathComponent("RecognizedPokemon", isDirectory: true)
            }
        }
        return nil
        #endif
    }

    static func save(_ record: PokemonRecord, directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(record)
        try data.write(to: directory.appendingPathComponent(record.id.uuidString + ".json"), options: .atomic)
    }

    static func read(directory: URL) throws -> StoredScanBatch {
        guard FileManager.default.fileExists(atPath: directory.path) else { return StoredScanBatch() }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var batch = StoredScanBatch()
        for file in files where file.pathExtension == "json" {
            do {
                batch.records.append(try JSONDecoder().decode(PokemonRecord.self, from: Data(contentsOf: file)))
            } catch {
                batch.rejectedFiles.append(file.lastPathComponent)
            }
        }
        return batch
    }
}
