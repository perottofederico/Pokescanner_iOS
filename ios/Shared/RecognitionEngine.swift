import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Vision

final class RecognitionEngine {
    private let parser: PokemonTextParser
    private let context = CIContext(options: [.cacheIntermediates: false])

    init(catalog: PokemonCatalog) {
        parser = PokemonTextParser(catalog: catalog)
    }

    func scan(data: Data) throws -> PokemonObservation {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw RecognitionError.invalidImage
        }
        return try scan(image: image)
    }

    func scan(image: CIImage) throws -> PokemonObservation {
        let scale = min(1, 1280 / max(image.extent.width, image.extent.height))
        let reduced = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let bitmap = context.createCGImage(reduced, from: reduced.extent) else {
            throw RecognitionError.invalidImage
        }
        return try scan(image: bitmap)
    }

    func scan(image: CGImage) throws -> PokemonObservation {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "it-IT"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.009
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let lines = (request.results ?? []).compactMap { observation -> OCRLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return OCRLine(text: candidate.string, confidence: candidate.confidence,
                           rect: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        }
        var observation = parser.parse(lines)
        if observation.isDetailScreen { observation.ivs = IVBarReader.read(image: image, lines: lines) }
        return observation
    }
}
