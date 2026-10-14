import CoreFoundation
import Foundation

enum BroadcastSignal: String, CaseIterable {
    case started
    case video
    case paused
    case resumed
    case stopped
    case recordsChanged
    case storageUnavailable
    case recognitionFailed

    var notificationName: CFNotificationName {
        CFNotificationName(rawValue: "com.pokecapture.demo.telemetry.\(rawValue)" as CFString)
    }

    func post() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }

    init?(notificationName: CFNotificationName) {
        guard let signal = Self.allCases.first(where: {
            CFEqual($0.notificationName.rawValue, notificationName.rawValue)
        }) else {
            return nil
        }
        self = signal
    }
}
