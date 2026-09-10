import AVFoundation
import UIKit

public struct TranscodeError: Error {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public enum TranscodeOutcome {
    case success(path: String, wasTranscoded: Bool)
    case failure(TranscodeError)
}

public class HdrToSdrTranscoder {
    public var progressHandler: ((Double) -> Void)?
    private var progressTimer: Timer?
    private var exportSession: AVAssetExportSession?

    public init() {}

    public func transcode(
        inputUrl: URL,
        outputUrl: URL,
        maxOriginalSizeBytes: Int64,
        completion: @escaping (TranscodeOutcome) -> Void
    ) {
        stopTimer()

        let asset = AVURLAsset(url: inputUrl, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])

        let isHdr = HdrDetector.isHdr(asset: asset)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: inputUrl.path)[.size] as? Int64) ?? 0

        // Если файл SDR и меньше порога — пропускаем транскодинг
        if !isHdr && fileSize <= maxOriginalSizeBytes {
            DispatchQueue.main.async {
                self.progressHandler?(1.0)
                completion(.success(path: inputUrl.path, wasTranscoded: false))
            }
            return
        }

        try? FileManager.default.removeItem(at: outputUrl)

        // ============================================================
        // ✅ Сжатие до 720p (1280x720 / 720x1280) + Tone Mapping HDR->SDR
        // ============================================================
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPreset1280x720
        ) else {
            completion(.failure(TranscodeError(
                code: "EXPORT_INIT_FAILED",
                message: "Failed to init export session. Video format not supported."
            )))
            return
        }

        self.exportSession = session
        session.outputURL = outputUrl
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        // Опрос прогресса через таймер
        DispatchQueue.main.async { [weak self] in
            self?.progressTimer = Timer.scheduledTimer(
                withTimeInterval: 0.15,
                repeats: true
            ) { [weak self] _ in
                guard let self = self, let s = self.exportSession else { return }
                let progress = Double(s.progress)
                self.progressHandler?(progress)
            }
        }

        session.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stopTimer()
                self.exportSession = nil

                switch session.status {
                case .completed:
                    self.progressHandler?(1.0)
                    completion(.success(path: outputUrl.path, wasTranscoded: true))

                case .failed:
                    completion(.failure(TranscodeError(
                        code: "EXPORT_FAILED",
                        message: session.error?.localizedDescription ?? "Export failed"
                    )))

                case .cancelled:
                    completion(.failure(TranscodeError(
                        code: "CANCELLED",
                        message: "Export cancelled"
                    )))

                default:
                    completion(.failure(TranscodeError(
                        code: "UNKNOWN",
                        message: "Unknown export status: \(session.status.rawValue)"
                    )))
                }
            }
        }
    }

    public func cancel() {
        exportSession?.cancelExport()
        stopTimer()
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// ============================================================
// HDR DETECTION
// ============================================================

public enum HdrDetector {
    public static func isHdr(asset: AVAsset) -> Bool {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return false
        }

        for item in videoTrack.formatDescriptions {
            let desc = item as! CMFormatDescription

            if let transferFunction = CMFormatDescriptionGetExtension(
                desc,
                extensionKey: kCMFormatDescriptionExtension_TransferFunction
            ) as? String {
                if transferFunction == (kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String) ||
                   transferFunction == (kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String) {
                    return true
                }
            }

            if let primaries = CMFormatDescriptionGetExtension(
                desc,
                extensionKey: kCMFormatDescriptionExtension_ColorPrimaries
            ) as? String {
                if primaries == (kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String) {
                    return true
                }
            }
        }

        for track in asset.tracks {
            for item in track.formatDescriptions {
                let desc = item as! CMFormatDescription
                if let extensions = CMFormatDescriptionGetExtensions(desc) as? [String: Any] {
                    if extensions["DolbyVisionConfiguration"] != nil {
                        return true
                    }
                }
            }
        }

        return false
    }
}