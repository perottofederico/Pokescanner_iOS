import SwiftUI
import UIKit

struct IVBadge: View {
    let ivs: PokemonIVs
    var size: CGFloat = 56

    private var color: Color {
        switch IVRating.band(for: ivs.roundedPercentage) {
        case .grey: return .gray
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }

    var body: some View {
        ZStack {
            Circle().strokeBorder(color.opacity(ivs.roundedPercentage == nil ? 0.35 : 1), lineWidth: 3)
            Text(ivs.roundedPercentage.map { "\($0)%" } ?? "—")
                .font(.system(size: size * 0.25, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ivs.roundedPercentage.map { "IV \($0) percent" } ?? "IVs incomplete")
    }
}

struct PokemonThumbnail: View {
    let data: Data?
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.08)
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
                    .font(.system(size: size * 0.30))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(data == nil ? "No saved Pokémon image" : "Cropped Pokémon scan")
    }
}
