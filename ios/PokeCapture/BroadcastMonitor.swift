import Combine
import CoreFoundation
import Foundation

final class BroadcastMonitor: ObservableObject {
    @Published private(set) var lastVideoAt: Date?
    @Published private(set) var heartbeatCount = 0
    @Published private(set) var lifecycle = "Waiting for a broadcast"
    @Published private(set) var isPaused = false
    @Published private(set) var recognitionProblem: String?

    init() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        for signal in BroadcastSignal.allCases {
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observer,
                { _, observer, notificationName, _, _ in
                    guard let observer, let notificationName,
                          let signal = BroadcastSignal(notificationName: notificationName) else {
                        return
                    }
                    let monitor = Unmanaged<BroadcastMonitor>.fromOpaque(observer).takeUnretainedValue()
                    DispatchQueue.main.async {
                        monitor.receive(signal)
                    }
                },
                signal.notificationName.rawValue,
                nil,
                .deliverImmediately
            )
        }
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    func hasRecentVideo(at date: Date) -> Bool {
        guard let lastVideoAt, !isPaused else {
            return false
        }
        return date.timeIntervalSince(lastVideoAt) < 3
    }

    private func receive(_ signal: BroadcastSignal) {
        switch signal {
        case .started:
            recognitionProblem = nil
            heartbeatCount = 0
            lastVideoAt = nil
            isPaused = false
            lifecycle = "Extension started; waiting for video"
        case .video:
            lastVideoAt = Date()
            heartbeatCount += 1
            isPaused = false
            lifecycle = "Video received by the extension"
        case .paused:
            lastVideoAt = nil
            isPaused = true
            lifecycle = "Broadcast paused"
        case .resumed:
            lastVideoAt = nil
            isPaused = false
            lifecycle = "Broadcast resumed; waiting for video"
        case .stopped:
            lastVideoAt = nil
            isPaused = false
            lifecycle = "Broadcast stopped"
        case .recordsChanged:
            recognitionProblem = nil
        case .storageUnavailable:
            recognitionProblem = RecognitionError.sharedStorageUnavailable.localizedDescription
        case .recognitionFailed:
            recognitionProblem = "Recognition failed for a frame. Check storage/signing or try a clearer screen."
        }
    }
}
