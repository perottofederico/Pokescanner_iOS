import CoreGraphics
import Foundation

struct OCRLine {
    let text: String
    let confidence: Float
    let rect: CGRect
}

final class PokemonTextParser {
    private let species: [PokemonCatalog.Entry]
    private let speciesByName: [String: PokemonCatalog.Entry]
    private let movesByName: [String: PokemonCatalog.Entry]

    init(catalog: PokemonCatalog) {
        species = catalog.species.sorted { $0.name.count > $1.name.count }
        var speciesIndex: [String: PokemonCatalog.Entry] = [:]
        var moveIndex: [String: PokemonCatalog.Entry] = [:]
        for entry in catalog.species {
            for alias in entry.aliases { speciesIndex[PokemonCatalog.normalize(alias)] = entry }
        }
        for entry in catalog.moves {
            for alias in entry.aliases { moveIndex[PokemonCatalog.normalize(alias)] = entry }
        }
        speciesByName = speciesIndex
        movesByName = moveIndex
    }

    func parse(_ lines: [OCRLine]) -> PokemonObservation {
        let reliable = lines.filter { $0.confidence >= 0.4 }
        var result = PokemonObservation()
        let statLabels = reliable.filter { IVBarReader.stat(for: $0.text) != nil && $0.rect.minY > 0.48 }
        let hasAppraisal = statLabels.count >= 2
        let normalized = reliable.map { PokemonCatalog.normalize($0.text) }
        let hasMeasurements = normalized.contains(where: { $0 == "weight" || $0 == "peso" })
            && normalized.contains(where: { $0 == "height" || $0 == "altezza" })
        let hasMoveContext = normalized.contains(where: {
            $0.contains("gyms raids") || $0.contains("palestre raid") || $0 == "battles" || $0 == "lotte"
        })

        for line in reliable {
            if line.rect.minY < 0.23,
               let captures = captures(#"(?:CP|PC)\s*[:.]?\s*(\d{1,5})"#, in: line.text.uppercased()),
               let value = Int(captures[0]), (1...20000).contains(value) {
                result.cp = value
            }
            if line.rect.minY > 0.2 && line.rect.minY < 0.65,
               let captures = captures(#"(\d{1,4})\s*/\s*(\d{1,4})\s*(?:HP|PS|PV)"#, in: line.text.uppercased()),
               let current = Int(captures[0]), let maximum = Int(captures[1]),
               maximum > 0, maximum <= 2000, current <= maximum {
                result.currentHP = current
                result.maxHP = maximum
            }
        }

        let nameLines = reliable.filter { $0.confidence >= 0.55 && $0.rect.minY >= 0.24 && $0.rect.minY < 0.52 }
        for line in nameLines.sorted(by: { $0.confidence > $1.confidence }) {
            if let identity = identity(for: line.text) {
                result.identity = identity
                break
            }
        }
        if result.identity == nil && hasAppraisal {
            for line in reliable where line.rect.minY > 0.75 {
                let sentence = " " + PokemonCatalog.normalize(line.text) + " "
                let matches = species.filter { entry in
                    entry.aliases.contains { sentence.contains(" " + PokemonCatalog.normalize($0) + " ") }
                }
                if matches.count == 1, let entry = matches.first {
                    result.identity = PokemonIdentity(id: entry.id, name: entry.name, observedName: entry.name)
                    break
                }
            }
        }

        if !hasAppraisal {
            for line in reliable.sorted(by: { $0.rect.minY < $1.rect.minY })
                where line.confidence >= 0.55 && line.rect.minY > 0.45 && line.rect.minY < 0.96 && line.rect.minX < 0.72 {
                let cleaned = line.text.replacingOccurrences(of: #"\s+\d+(?:\s*\+)?\s*$"#, with: "", options: .regularExpression)
                if let entry = movesByName[PokemonCatalog.normalize(cleaned)],
                   !result.moves.contains(where: { $0.id == entry.id }), result.moves.count < 3 {
                    result.moves.append(RecognizedMove(id: entry.id, name: entry.name))
                }
            }
        }
        result.isDetailScreen = hasAppraisal || hasMeasurements || result.maxHP != nil
            || (result.cp != nil && result.identity != nil) || (hasMoveContext && !result.moves.isEmpty)
        if !result.isDetailScreen { result.identity = nil; result.moves = [] }
        return result
    }

    private func identity(for text: String) -> PokemonIdentity? {
        let normalized = PokemonCatalog.normalize(text)
        var variants = [normalized]
        for prefix in ["mega ", "primal ", "alolan ", "galarian ", "hisuian ", "paldean "] {
            if normalized.hasPrefix(prefix) { variants.append(String(normalized.dropFirst(prefix.count))) }
        }
        for suffix in [" male", " female", " x", " y"] {
            if normalized.hasSuffix(suffix) { variants.append(String(normalized.dropLast(suffix.count))) }
        }
        for variant in variants {
            if let entry = speciesByName[variant] {
                return PokemonIdentity(id: entry.id, name: entry.name, observedName: text)
            }
        }
        return nil
    }

    private func captures(_ pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap {
            guard let range = Range(match.range(at: $0), in: text) else { return nil }
            return String(text[range])
        }
    }
}
