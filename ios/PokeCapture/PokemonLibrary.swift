import Combine
import Foundation

struct CollectionReload {
    let records: [PokemonRecord]
    let warning: String?
}

actor PokemonRepository {
    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeCapture", isDirectory: true)
        fileURL = directory.appendingPathComponent("collection.json")
    }

    func refresh(sharedDirectory: URL?) throws -> CollectionReload {
        var records = try load()
        var batch = StoredScanBatch()
        var warning: String?
        if let sharedDirectory {
            do {
                batch = try RecognitionStorage.read(directory: sharedDirectory)
                if !batch.rejectedFiles.isEmpty {
                    warning = "Skipped \(batch.rejectedFiles.count) unreadable scan file(s); valid records are still available."
                }
            } catch {
                warning = "Saved collection loaded, but shared scans could not be read: " + error.localizedDescription
            }
        }
        var changed = false
        var indexed = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for record in batch.records {
            if indexed[record.id] == nil || (indexed[record.id]?.updatedAt ?? .distantPast) < record.updatedAt {
                indexed[record.id] = record
                changed = true
            }
        }
        records = indexed.values.sorted { $0.capturedAt > $1.capturedAt }
        if changed { try persist(records) }
        return CollectionReload(records: records, warning: warning)
    }

    func add(_ record: PokemonRecord) throws -> [PokemonRecord] {
        var records = try load()
        records.insert(record, at: 0)
        try persist(records)
        return records
    }

    private func load() throws -> [PokemonRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([PokemonRecord].self, from: Data(contentsOf: fileURL))
    }

    private func persist(_ records: [PokemonRecord]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(records).write(to: fileURL, options: .atomic)
    }
}

@MainActor
final class PokemonLibrary: ObservableObject {
    @Published private(set) var records: [PokemonRecord] = []
    @Published private(set) var isImporting = false
    @Published var message: String?
    @Published private(set) var storageWarning: String?
    let sharedDirectory = RecognitionStorage.sharedDirectory
    private let repository = PokemonRepository()
    private var refreshing = false

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        Task {
            defer { refreshing = false }
            do {
                let result = try await repository.refresh(sharedDirectory: sharedDirectory)
                records = result.records
                storageWarning = result.warning
            } catch {
                storageWarning = "Could not load saved scans: " + error.localizedDescription
            }
        }
    }

    func importScreenshot(_ data: Data) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let observation = try await Task.detached(priority: .userInitiated) {
                try autoreleasepool {
                    try RecognitionEngine(catalog: PokemonCatalog.load()).scan(data: data)
                }
            }.value
            guard let identity = observation.identity else {
                message = "No Pokémon species could be read. Try an unobscured detail or appraisal screenshot with its species name visible."
                return
            }
            let record = PokemonRecord(observation: observation, identity: identity, source: "Screenshot import")
            records = try await repository.add(record)
            message = "Saved \(identity.name). Any unreadable fields are marked Not detected."
        } catch {
            message = "Screenshot recognition failed: " + error.localizedDescription
        }
    }
}
