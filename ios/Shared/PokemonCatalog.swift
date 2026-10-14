import Foundation

struct PokemonCatalog: Decodable {
    struct Entry: Decodable {
        let id: Int
        let name: String
        let aliases: [String]
    }

    let species: [Entry]
    let moves: [Entry]

    static func load(url: URL? = Bundle.main.url(forResource: "pokemon-catalog", withExtension: "json")) throws -> PokemonCatalog {
        guard let url else { throw RecognitionError.catalogMissing }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "♀", with: " female")
            .replacingOccurrences(of: "♂", with: " male")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}

enum RecognitionError: LocalizedError {
    case catalogMissing
    case invalidImage
    case sharedStorageUnavailable

    var errorDescription: String? {
        switch self {
        case .catalogMissing: return "The bundled species/move catalog is missing. Rebuild the app."
        case .invalidImage: return "This image could not be decoded."
        case .sharedStorageUnavailable: return "Shared scan storage is unavailable. Reinstall with the App Group and broadcast extension retained."
        }
    }
}
