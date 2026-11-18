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
    private var isCancelled = false
    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?

    public init() {}

    public func transcode(
        inputUrl: URL,
        outputUrl: URL,
        maxOriginalSizeBytes: Int64 = 15 * 1024 * 1024,
        completion: @escaping (TranscodeOutcome) -> Void
    ) {
        self.isCancelled = false
        let asset = AVURLAsset(url: inputUrl, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])

        let isHdr = HdrDetector.isHdr(asset: asset)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: inputUrl.path)[.size] as? Int64) ?? 0

        // Если видео не HDR и уже меньше 15 МБ — отдаем оригинал без лишней работы
        if !isHdr && fileSize <= maxOriginalSizeBytes {
            DispatchQueue.main.async {
                self.progressHandler?(1.0)
                completion(.success(path: inputUrl.path, wasTranscoded: false))
            }
            return
        }

        try? FileManager.default.removeItem(at: outputUrl)

        // Исправлено имя пресета под стандартный Swift API
        let preset = AVAssetExportPreset1280x720
        
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            DispatchQueue.main.async {
                completion(.failure(TranscodeError(code: "INIT_FAILED", message: "Could not create AVAssetExportSession")))
            }
            return
        }

        self.exportSession = session
        session.outputURL = outputUrl
        session.outputFileType = AVFileType.mp4 // Явное указание типа файла
        session.shouldOptimizeForNetworkUse = true

        // Отслеживание прогресса экспорта
        DispatchQueue.main.async {
            self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let session = self.exportSession else { return }
                let progress = Double(session.progress)
                self.progressHandler?(max(0.0, min(progress, 1.0)))
            }
        }

        session.exportAsynchronously {
            DispatchQueue.main.async {
                self.progressTimer?.invalidate()
                self.progressTimer = nil

                if self.isCancelled {
                    completion(.failure(TranscodeError(code: "CANCELLED", message: "Export cancelled")))
                    return
                }

                switch session.status {
                case .completed:
                    self.progressHandler?(1.0)
                    completion(.success(path: outputUrl.path, wasTranscoded: true))
                case .failed:
                    let err = session.error?.localizedDescription ?? "Export failed"
                    completion(.failure(TranscodeError(code: "EXPORT_FAILED", message: err)))
                case .cancelled:
                    completion(.failure(TranscodeError(code: "CANCELLED", message: "Export cancelled")))
                default:
                    completion(.failure(TranscodeError(code: "EXPORT_FAILED", message: "Unknown export status")))
                }
            }
        }
    }

    public func cancel() {
        self.isCancelled = true
        progressTimer?.invalidate()
        progressTimer = nil
        exportSession?.cancelExport()
    }
}

// ============================================================
// HDR DETECTOR
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