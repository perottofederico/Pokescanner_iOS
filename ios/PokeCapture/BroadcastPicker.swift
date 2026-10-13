import Foundation
import ReplayKit
import SwiftUI

enum EmbeddedBroadcast {
    static var identifier: String? {
        guard let pluginsURL = Bundle.main.builtInPlugInsURL,
              let pluginURLs = try? FileManager.default.contentsOfDirectory(
                at: pluginsURL,
                includingPropertiesForKeys: nil
              ) else {
            return nil
        }

        for pluginURL in pluginURLs where pluginURL.pathExtension == "appex" {
            guard let bundle = Bundle(url: pluginURL),
                  let configuration = bundle.infoDictionary?["NSExtension"] as? [String: Any],
                  configuration["NSExtensionPointIdentifier"] as? String == "com.apple.broadcast-services-upload" else {
                continue
            }
            return bundle.bundleIdentifier
        }
        return nil
    }
}

struct BroadcastPicker: UIViewRepresentable {
    let extensionIdentifier: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        picker.preferredExtension = extensionIdentifier
        picker.showsMicrophoneButton = false
        picker.accessibilityLabel = "Open screen broadcast controls"
        return picker
    }

    func updateUIView(_ picker: RPSystemBroadcastPickerView, context: Context) {
        picker.preferredExtension = extensionIdentifier
    }
}
