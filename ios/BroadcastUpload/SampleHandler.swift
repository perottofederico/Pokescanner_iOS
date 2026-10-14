import CoreMedia
import CoreVideo
import CoreImage
import Foundation
import os
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let logger = Logger(subsystem: "com.pokecapture.demo", category: "Broadcast")
    private var videoFrames = 0
    private var lastHeartbeatTime: TimeInterval?
    private let recognitionQueue = DispatchQueue(label: "com.pokecapture.recognition", qos: .utility)
    private let processingLock = NSLock()
    private var processingFrame = false
    private var acceptingFrames = false
    private var lastRecognitionTime: TimeInterval = 0
    private var engine: RecognitionEngine?
    private var tracker = PokemonTracker()
    private var sharedDirectory: URL?
    private var pendingWrites: [UUID: PokemonRecord] = [:]

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        videoFrames = 0
        lastHeartbeatTime = nil
        logger.notice("Broadcast started; recognition stays on device and screen pixels are not saved.")
        BroadcastSignal.started.post()
        recognitionQueue.sync {
            tracker = PokemonTracker()
            pendingWrites = [:]
            sharedDirectory = RecognitionStorage.sharedDirectory
            do {
                engine = RecognitionEngine(catalog: try PokemonCatalog.load())
            } catch {
                engine = nil
                logger.error("Recognition catalog failed: \(error.localizedDescription, privacy: .public)")
                BroadcastSignal.recognitionFailed.post()
            }
            if sharedDirectory == nil { BroadcastSignal.storageUnavailable.post() }
        }
        processingLock.lock()
        acceptingFrames = true
        lastRecognitionTime = 0
        processingLock.unlock()
    }

    override func broadcastPaused() {
        processingLock.lock()
        acceptingFrames = false
        processingLock.unlock()
        logger.notice("Broadcast paused.")
        BroadcastSignal.paused.post()
    }

    override func broadcastResumed() {
        processingLock.lock()
        acceptingFrames = true
        processingLock.unlock()
        lastHeartbeatTime = nil
        logger.notice("Broadcast resumed.")
        BroadcastSignal.resumed.post()
    }

    override func broadcastFinished() {
        processingLock.lock()
        acceptingFrames = false
        processingLock.unlock()
        recognitionQueue.sync {
            do { try flushPendingWrites() }
            catch {
                logger.error("Final scan write failed: \(error.localizedDescription, privacy: .public)")
                BroadcastSignal.recognitionFailed.post()
            }
        }
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
        if lastHeartbeatTime == nil || currentTime - (lastHeartbeatTime ?? 0) >= 1 {
            lastHeartbeatTime = currentTime
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            logger.info("Video received: \(self.videoFrames, privacy: .public) frames, \(width, privacy: .public)x\(height, privacy: .public).")
            BroadcastSignal.video.post()
        }
        processingLock.lock()
        guard acceptingFrames, !processingFrame, currentTime - lastRecognitionTime >= 1.3 else {
            processingLock.unlock()
            return
        }
        processingFrame = true
        lastRecognitionTime = currentTime
        processingLock.unlock()
        let orientation = (CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString,
                                           attachmentModeOut: nil) as? NSNumber)?.int32Value ?? 1
        recognitionQueue.async { [self] in
            defer {
                processingLock.lock()
                processingFrame = false
                processingLock.unlock()
            }
            autoreleasepool {
                guard let engine, let sharedDirectory else { return }
                do {
                    try flushPendingWrites()
                    let image = CIImage(cvPixelBuffer: imageBuffer).oriented(forExifOrientation: orientation)
                    var observation = try engine.scan(image: image)
                    observation.diagnostics.append("ReplayKit input: \(CVPixelBufferGetWidth(imageBuffer))×\(CVPixelBufferGetHeight(imageBuffer)); EXIF orientation \(orientation).")
                    if let record = tracker.observe(observation) {
                        pendingWrites[record.id] = record
                        try RecognitionStorage.save(record, directory: sharedDirectory)
                        pendingWrites.removeValue(forKey: record.id)
                        BroadcastSignal.recordsChanged.post()
                    }
                } catch {
                    logger.error("Recognition/storage failed: \(error.localizedDescription, privacy: .public)")
                    BroadcastSignal.recognitionFailed.post()
                }
            }
        }
    }

    private func flushPendingWrites() throws {
        guard let sharedDirectory else { return }
        for record in Array(pendingWrites.values) {
            try RecognitionStorage.save(record, directory: sharedDirectory)
            pendingWrites.removeValue(forKey: record.id)
            BroadcastSignal.recordsChanged.post()
        }
    }
}
