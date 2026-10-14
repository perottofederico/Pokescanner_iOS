import Foundation

enum IVRating: String {
    case grey, blue, green, orange, purple

    static func band(for percentage: Int?) -> IVRating {
        guard let percentage else { return .grey }
        switch percentage {
        case ...60: return .grey
        case 61...80: return .blue
        case 81...95: return .green
        case 96...99: return .orange
        default: return .purple
        }
    }
}
