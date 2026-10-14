import CoreGraphics
import Foundation

struct CPReading {
    let value: Int?
    let diagnostics: [String]
}

enum CPReader {
    static func read(_ lines: [OCRLine], stage: String = "Full frame") -> CPReading {
        let top = lines.filter { $0.rect.minY < 0.30 }.sorted {
            $0.rect.minY == $1.rect.minY ? $0.rect.minX < $1.rect.minX : $0.rect.minY < $1.rect.minY
        }
        var diagnostics = top.prefix(10).map { line in
            String(format: "%@ top OCR: '%@' confidence=%.2f x=%.3f y=%.3f w=%.3f h=%.3f",
                   stage, String(line.text.prefix(90)), line.confidence,
                   Double(line.rect.minX), Double(line.rect.minY), Double(line.rect.width), Double(line.rect.height))
        }
        var candidates = Set<Int>()
        for line in top where line.confidence >= 0.30 {
            let uppercased = line.text.uppercased()
            if let range = uppercased.range(
                of: #"(?:^|\s)(?:CP|PC|PL)\s*[:.]?\s*(\d[\d\s,.]{0,8})\s*$"#, options: .regularExpression),
               let value = number(String(uppercased[range]).filter { $0.isNumber || $0.isWhitespace || $0 == "," || $0 == "." }) {
                candidates.insert(value)
                diagnostics.append("\(stage): inline CP candidate \(value).")
            }
        }
        let labels = top.filter {
            $0.confidence >= 0.20 && $0.text.uppercased().range(of: #"^(?:CP|PC|PL)[\s:.]*$"#, options: .regularExpression) != nil
        }
        for label in labels {
            for digits in top where digits.confidence >= 0.40 {
                let aligned = abs(digits.rect.midY - label.rect.midY) <= max(digits.rect.height, label.rect.height) * 0.9
                let gap = digits.rect.minX - label.rect.maxX
                guard aligned, gap >= -0.015, gap <= 0.16, let value = number(digits.text) else { continue }
                candidates.insert(value)
                diagnostics.append("\(stage): paired '\(label.text)' with '\(digits.text)' → CP \(value).")
            }
        }
        let value = candidates.count == 1 ? candidates.first : nil
        diagnostics.append(value.map { "\(stage): CP accepted \($0)." }
            ?? "\(stage): CP missing; \(candidates.count) label-linked candidates (zero or ambiguous).")
        return CPReading(value: value, diagnostics: diagnostics)
    }

    private static func number(_ text: String) -> Int? {
        guard text.range(of: #"^[0-9\s,.]+$"#, options: .regularExpression) != nil else { return nil }
        let digits = text.filter { $0.isNumber }
        guard digits.count <= 5, let value = Int(digits), (1...20000).contains(value) else { return nil }
        return value
    }
}
