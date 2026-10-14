import CoreGraphics
import Foundation

struct ImagePixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init?(image: CGImage) {
        width = image.width
        height = image.height
        var storage = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = storage.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
            return true
        }
        guard rendered else { return nil }
        bytes = storage
    }

    func color(_ horizontal: Int, _ vertical: Int) -> (red: Int, green: Int, blue: Int) {
        let offset = (min(max(vertical, 0), height - 1) * width + min(max(horizontal, 0), width - 1)) * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }

    func isWhite(_ horizontal: Int, _ vertical: Int) -> Bool {
        let color = color(horizontal, vertical)
        let minimum = min(color.red, color.green, color.blue)
        let maximum = max(color.red, color.green, color.blue)
        return minimum > 218 && maximum - minimum < 35
    }

    func isFill(_ horizontal: Int, _ vertical: Int) -> Bool {
        let color = color(horizontal, vertical)
        return color.red > 155 && Double(color.red) > Double(color.green) * 1.09
            && Double(color.red) > Double(color.blue) * 1.12 && color.blue < 190
    }

    func isTrack(_ horizontal: Int, _ vertical: Int) -> Bool {
        if isFill(horizontal, vertical) { return true }
        let color = color(horizontal, vertical)
        let minimum = min(color.red, color.green, color.blue)
        let maximum = max(color.red, color.green, color.blue)
        return minimum >= 145 && maximum <= 230 && maximum - minimum < 22
    }
}

enum IVBarReader {
    enum Stat: Hashable { case attack, defense, stamina }

    static func stat(for text: String) -> Stat? {
        switch PokemonCatalog.normalize(text) {
        case "attack", "attacco": return .attack
        case "defense", "defence", "difesa": return .defense
        case "hp", "ps", "pv": return .stamina
        default: return nil
        }
    }

    static func read(image: CGImage, lines: [OCRLine]) -> PokemonIVs {
        guard let pixels = ImagePixels(image: image) else { return PokemonIVs() }
        let labels = lines.filter { $0.confidence >= 0.4 && stat(for: $0.text) != nil
            && $0.rect.minY > 0.48 && $0.rect.minX < 0.65 }.sorted { $0.rect.minY < $1.rect.minY }
        guard Set(labels.compactMap { stat(for: $0.text) }).count == 3 else { return PokemonIVs() }
        var result = PokemonIVs()
        for (index, label) in labels.enumerated() {
            let nextLabel = index + 1 < labels.count ? labels[index + 1].rect.minY : 1
            guard let value = measure(label: label, nextLabel: nextLabel, pixels: pixels) else { continue }
            switch stat(for: label.text) {
            case .attack: result.attack = value
            case .defense: result.defense = value
            case .stamina: result.stamina = value
            case nil: break
            }
        }
        return result
    }

    private static func measure(label: OCRLine, nextLabel: CGFloat, pixels: ImagePixels) -> Int? {
        let start = Int(label.rect.minX * CGFloat(pixels.width))
        let referenceRow = max(0, Int(label.rect.minY * CGFloat(pixels.height)) - 4)
        let center = Int(label.rect.midX * CGFloat(pixels.width))
        guard pixels.isWhite(center, referenceRow) else { return nil }
        var panelLeft = center
        var panelRight = center
        while panelLeft > 0 && pixels.isWhite(panelLeft - 1, referenceRow) { panelLeft -= 1 }
        while panelRight + 1 < pixels.width && pixels.isWhite(panelRight + 1, referenceRow) { panelRight += 1 }
        let margin = start - panelLeft
        let end = panelRight - margin
        let panelWidth = panelRight - panelLeft
        guard margin >= pixels.width / 50, panelWidth > pixels.width / 5,
              panelWidth < pixels.width * 3 / 4, end - start > pixels.width / 6 else { return nil }

        let firstRow = Int(label.rect.maxY * CGFloat(pixels.height)) + 2
        let lastRow = min(Int(nextLabel * CGFloat(pixels.height)) - 2,
                          firstRow + max(8, pixels.height / 35), pixels.height - 1)
        guard firstRow < lastRow else { return nil }
        var bestRow: Int?
        var bestCount = 0
        let scanStart = max(panelLeft + pixels.width / 50, start - pixels.width / 40)
        for row in firstRow...lastRow {
            let count = (scanStart...end).filter { pixels.isTrack($0, row) }.count
            if count > bestCount { bestCount = count; bestRow = row }
        }
        guard let row = bestRow,
              let detectedStart = (scanStart...end).first(where: { pixels.isTrack($0, row) }),
              abs(detectedStart - start) <= max(3, pixels.width / 40) else { return nil }
        let detectedEnd = panelRight - (detectedStart - panelLeft)
        let fullWidth = detectedEnd - detectedStart + 1
        guard fullWidth > pixels.width / 6, detectedEnd < pixels.width,
              Double(bestCount) / Double(fullWidth) >= 0.62 else { return nil }
        let filled = (detectedStart...detectedEnd).filter { pixels.isFill($0, row) }
        guard let filledEnd = filled.last else { return 0 }
        guard let filledStart = filled.first, filledStart - detectedStart <= max(3, fullWidth / 25) else { return nil }
        let filledWidth = filledEnd - detectedStart + 1
        guard Double(filled.count) / Double(filledWidth) >= 0.82 else { return nil }
        let estimate = Double(filledWidth) / Double(fullWidth) * 15
        let rounded = estimate.rounded()
        guard abs(estimate - rounded) <= 0.32 else { return nil }
        return min(15, max(0, Int(rounded)))
    }
}
