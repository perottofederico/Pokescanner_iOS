import CoreMedia
import CoreVideo
import Foundation
import os
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let logger = Logger(subsystem: "com.pokecapture.demo", category: "Broadcast")
    private var videoFrames = 0
    private var lastHeartbeatTime: TimeInterval?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        videoFrames = 0
        lastHeartbeatTime = nil
        logger.notice("Broadcast started; video buffers will be discarded, not saved or uploaded.")
        BroadcastSignal.started.post()
    }

    override func broadcastPaused() {
        logger.notice("Broadcast paused.")
        BroadcastSignal.paused.post()
    }

    override func broadcastResumed() {
        lastHeartbeatTime = nil
        logger.notice("Broadcast resumed.")
        BroadcastSignal.resumed.post()
    }

    override func broadcastFinished() {
        logger.notice("Broadcast finished after \(self.videoFrames, privacy: .public) video frames.")
        BroadcastSignal.stopped.post()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
              CMSampleBufferIsValid(sampleBuffer),
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        videoFrames += 1
        let currentTime = ProcessInfo.processInfo.systemUptime
        if let lastHeartbeatTime, currentTime - lastHeartbeatTime < 1 {
            return
        }

        lastHeartbeatTime = currentTime
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        logger.info("Video received: \(self.videoFrames, privacy: .public) frames, \(width, privacy: .public)x\(height, privacy: .public).")
        BroadcastSignal.video.post()
    }
}
