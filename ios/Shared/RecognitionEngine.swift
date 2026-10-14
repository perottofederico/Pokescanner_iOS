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
        let lines = try recognize(image: image, minimumTextHeight: 0.006)
        var observation = parser.parse(lines)
        observation.diagnostics.append("Image: \(image.width)×\(image.height); full-frame OCR returned \(lines.count) lines.")
        if observation.cp == nil {
            do {
                let cropHeight = image.height * 3 / 10
                if let crop = image.cropping(to: CGRect(x: 0, y: 0, width: image.width, height: cropHeight)) {
                    let enhanced = CIImage(cgImage: crop).applyingFilter("CIColorControls", parameters: [
                        kCIInputSaturationKey: 0, kCIInputContrastKey: 1.35
                    ]).transformed(by: CGAffineTransform(scaleX: 2, y: 2))
                    if let bitmap = context.createCGImage(enhanced, from: enhanced.extent) {
                        let croppedLines = try recognize(image: bitmap, minimumTextHeight: 0.004)
                        let mapped = croppedLines.map { line in
                            OCRLine(text: line.text, confidence: line.confidence,
                                    rect: CGRect(x: line.rect.minX, y: line.rect.minY * 0.30,
                                                 width: line.rect.width, height: line.rect.height * 0.30))
                        }
                        let reading = CPReader.read(mapped, stage: "Enlarged top crop")
                        if let value = reading.value {
                            let reparsed = parser.parse(lines + mapped)
                            observation.identity = reparsed.identity
                            observation.isDetailScreen = reparsed.isDetailScreen
                            observation.cp = value
                        }
                        observation.diagnostics += reading.diagnostics
                    }
                }
            } catch {
                observation.diagnostics.append("CP crop retry failed: " + error.localizedDescription)
            }
        }
        if observation.isDetailScreen { observation.ivs = IVBarReader.read(image: image, lines: lines) }
        if observation.identity != nil { observation.thumbnail = thumbnail(image: image, observation: observation, lines: lines) }
        observation.diagnostics.append("Final scan: species=\(observation.identity?.name ?? "missing"), CP=\(observation.cp.map(String.init) ?? "missing"), IVs=\(observation.ivs.attack.map(String.init) ?? "missing")/\(observation.ivs.defense.map(String.init) ?? "missing")/\(observation.ivs.stamina.map(String.init) ?? "missing"), thumbnail=\(observation.thumbnail == nil ? "missing" : "saved").")
        return observation
    }

    private func recognize(image: CGImage, minimumTextHeight: Float) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "it-IT"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = minimumTextHeight
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { observation -> OCRLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return OCRLine(text: candidate.string, confidence: candidate.confidence,
                           rect: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
        }
    }

    private func thumbnail(image: CGImage, observation: PokemonObservation, lines: [OCRLine]) -> Data? {
        let name = PokemonCatalog.normalize(observation.identity?.observedName ?? "")
        let nameLine = lines.first { PokemonCatalog.normalize($0.text) == name && $0.rect.minY > 0.24 && $0.rect.minY < 0.52 }
        let bottom = min(0.44, max(0.26, Double(nameLine?.rect.minY ?? 0.36) - 0.015))
        let bounds = CGRect(x: Double(image.width) * 0.10, y: Double(image.height) * 0.07,
                            width: Double(image.width) * 0.80, height: Double(image.height) * (bottom - 0.07))
        guard let crop = image.cropping(to: bounds.integral) else { return nil }
        let scale = min(1, 240 / Double(max(crop.width, crop.height)))
        let resized = CIImage(cgImage: crop).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let bitmap = context.createCGImage(resized, from: resized.extent),
              let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, bitmap, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
