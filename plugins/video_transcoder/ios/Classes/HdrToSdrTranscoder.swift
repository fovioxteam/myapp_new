import AVFoundation
import UIKit

struct TranscodeError {
    let code: String
    let message: String
}

enum TranscodeOutcome {
    case success(path: String, wasTranscoded: Bool)
    case failure(TranscodeError)
}

class HdrToSdrTranscoder {
    var progressHandler: ((Double) -> Void)?
    private var progressTimer: Timer?
    private var exportSession: AVAssetExportSession?

    func transcode(
        inputUrl: URL,
        outputUrl: URL,
        maxOriginalSizeBytes: Int64,
        completion: @escaping (TranscodeOutcome) -> Void
    ) {
        let asset = AVURLAsset(url: inputUrl, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true,
        ])

        let isHdr = HdrDetector.isHdr(asset: asset)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: inputUrl.path)[.size] as? Int64) ?? 0

        // SDR + уже маленький → не транскодируем
        if !isHdr && fileSize <= maxOriginalSizeBytes {
            DispatchQueue.main.async {
                self.progressHandler?(1.0)
                completion(.success(path: inputUrl.path, wasTranscoded: false))
            }
            return
        }

        // Удаляем output, если остался
        try? FileManager.default.removeItem(at: outputUrl)

        // ============================================================
        // ✅ AVAssetExportSession — системный tone mapping
        // AVAssetExportPreset1920x1080 сам делает HDR → SDR BT709
        // ============================================================
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPreset1920x1080
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

        // Прогресс через polling
        DispatchQueue.main.async {
            self.progressTimer = Timer.scheduledTimer(
                withTimeInterval: 0.2,
                repeats: true
            ) { [weak self] _ in
                guard let self = self, let s = self.exportSession else { return }
                let progress = Double(s.progress)
                self.progressHandler?(progress)
            }
        }

        session.exportAsynchronously {
            DispatchQueue.main.async {
                self.progressTimer?.invalidate()
                self.progressTimer = nil
                self.exportSession = nil

                switch session.status {
                case .completed:
                    self.progressHandler?(1.0)
                    completion(.success(
                        path: outputUrl.path,
                        wasTranscoded: true
                    ))

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
}

// ============================================================
// HDR DETECTION
// ============================================================

enum HdrDetector {
    static func isHdr(asset: AVAsset) -> Bool {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return false
        }

        for formatDescription in videoTrack.formatDescriptions {
            let desc = formatDescription as! CMFormatDescription

            // Transfer function: HLG или PQ
            if let transferFunction = CMFormatDescriptionGetExtension(
                desc,
                extensionKey: kCMFormatDescriptionExtension_TransferFunction
            ) as? String {
                if transferFunction == "ITU_R_2100_HLG" ||
                   transferFunction == "SMPTE_ST_2084_PQ" {
                    return true
                }
            }

            // BT2020 primaries
            if let primaries = CMFormatDescriptionGetExtension(
                desc,
                extensionKey: kCMFormatDescriptionExtension_ColorPrimaries
            ) as? String {
                if primaries == "ITU_R_2020" {
                    return true
                }
            }
        }

        // Dolby Vision
        for track in asset.tracks {
            for formatDescription in track.formatDescriptions {
                let desc = formatDescription as! CMFormatDescription
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