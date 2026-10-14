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
        var collection = try load()
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
        if collection.merge(batch.records) { try persist(collection) }
        return CollectionReload(records: collection.records, warning: warning)
    }

    func add(_ record: PokemonRecord) throws -> [PokemonRecord] {
        var collection = try load()
        collection.records.insert(record, at: 0)
        try persist(collection)
        return collection.records
    }

    func update(_ record: PokemonRecord) throws -> [PokemonRecord] {
        var collection = try load()
        try collection.update(record)
        try persist(collection)
        return collection.records
    }

    func delete(_ ids: Set<UUID>) throws -> [PokemonRecord] {
        var collection = try load()
        collection.delete(ids)
        try persist(collection)
        return collection.records
    }

    private func load() throws -> PokemonCollection {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return PokemonCollection() }
        return try PokemonCollection.decode(Data(contentsOf: fileURL))
    }

    private func persist(_ collection: PokemonCollection) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(collection).write(to: fileURL, options: .atomic)
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
    private var revision = 0
    @Published private(set) var isMutating = false

    func refresh() {
        guard !refreshing, !isMutating else { return }
        refreshing = true
        let expectedRevision = revision
        Task {
            defer { refreshing = false }
            do {
                let result = try await repository.refresh(sharedDirectory: sharedDirectory)
                guard revision == expectedRevision else { return }
                records = result.records
                storageWarning = result.warning
            } catch {
                if revision == expectedRevision { storageWarning = "Could not load saved scans: " + error.localizedDescription }
            }
        }
    }

    func update(_ record: PokemonRecord) async -> Bool {
        guard !isMutating else { message = "Another collection change is still saving. Please retry."; return false }
        isMutating = true
        revision += 1
        defer { isMutating = false }
        do {
            records = try await repository.update(record)
            return true
        } catch {
            message = "Could not save edits: " + error.localizedDescription
            return false
        }
    }

    func delete(_ ids: Set<UUID>) async -> Bool {
        guard !isMutating else { message = "Another collection change is still saving. Please retry."; return false }
        isMutating = true
        revision += 1
        defer { isMutating = false }
        do {
            records = try await repository.delete(ids)
            return true
        } catch {
            message = "Could not remove Pokémon: " + error.localizedDescription
            return false
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
            guard !isMutating else { message = "Another collection change is saving. Please import again."; return }
            isMutating = true
            revision += 1
            defer { isMutating = false }
            records = try await repository.add(record)
            message = "Saved \(identity.name). Any unreadable fields are marked Not detected."
        } catch {
            message = "Screenshot recognition failed: " + error.localizedDescription
        }
    }
}
