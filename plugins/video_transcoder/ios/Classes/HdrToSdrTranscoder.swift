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
    private var assetReader: AVAssetReader?
    private var assetWriter: AVAssetWriter?

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

        // Если видео не HDR и уже меньше 15 МБ — отдаем оригинал
        if !isHdr && fileSize <= maxOriginalSizeBytes {
            DispatchQueue.main.async {
                self.progressHandler?(1.0)
                completion(.success(path: inputUrl.path, wasTranscoded: false))
            }
            return
        }

        try? FileManager.default.removeItem(at: outputUrl)

        DispatchQueue.global(qos: .userInitiated).async {
            self.processVideo(asset: asset, outputUrl: outputUrl, completion: completion)
        }
    }

    private func processVideo(
        asset: AVAsset,
        outputUrl: URL,
        completion: @escaping (TranscodeOutcome) -> Void
    ) {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            DispatchQueue.main.async {
                completion(.failure(TranscodeError(code: "NO_VIDEO", message: "Video track not found")))
            }
            return
        }

        let duration = CMTimeGetSeconds(asset.duration)
        let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let width = abs(naturalSize.width)
        let height = abs(naturalSize.height)

        // Расчет разрешения под 720p с сохранением пропорций (кратно 2)
        let targetDimension: CGFloat = 720.0
        let maxDim = max(width, height)
        let scale = maxDim > targetDimension ? targetDimension / maxDim : 1.0

        var targetWidth = Int((width * scale) / 2) * 2
        var targetHeight = Int((height * scale) / 2) * 2

        if targetWidth <= 0 { targetWidth = 720 }
        if targetHeight <= 0 { targetHeight = 1280 }

        do {
            assetReader = try AVAssetReader(asset: asset)
            assetWriter = try AVAssetWriter(outputURL: outputUrl, fileType: .mp4)

            // 1. Настройка Reader с принудительным SDR Tone Mapping
            let readerVideoOutputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerVideoOutputSettings)
            videoReaderOutput.alwaysCopiesSampleData = false

            if assetReader!.canAdd(videoReaderOutput) {
                assetReader!.add(videoReaderOutput)
            }

            // 2. Настройка Writer (Кодер H.264 с битрейтом 2.5 Mbps -> размер 3–6 МБ)
            let videoWriterInputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: targetWidth,
                AVVideoHeightKey: targetHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2_500_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoExpectedSourceFrameRateKey: 30,
                    AVVideoAllowFrameReorderingKey: true
                ],
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ]
            ]

            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoWriterInputSettings)
            videoWriterInput.expectsMediaDataInRealTime = false
            videoWriterInput.transform = videoTrack.preferredTransform

            if assetWriter!.canAdd(videoWriterInput) {
                assetWriter!.add(videoWriterInput)
            }

            // 3. Обработка Аудио трека (AAC 128 kbps)
            var audioReaderOutput: AVAssetReaderTrackOutput?
            var audioWriterInput: AVAssetWriterInput?

            if let audioTrack = asset.tracks(withMediaType: .audio).first {
                let audioReaderSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM
                ]
                audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioReaderSettings)
                if assetReader!.canAdd(audioReaderOutput!) {
                    assetReader!.add(audioReaderOutput!)
                }

                let audioWriterSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 128000
                ]
                audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioWriterSettings)
                audioWriterInput!.expectsMediaDataInRealTime = false

                if assetWriter!.canAdd(audioWriterInput!) {
                    assetWriter!.add(audioWriterInput!)
                }
            }

            // Запуск сжатия
            assetReader!.startReading()
            assetWriter!.startWriting()
            assetWriter!.startSession(atSourceTime: .zero)

            let group = DispatchGroup()

            // Сжатие Видео кадра за кадром
            group.enter()
            let videoQueue = DispatchQueue(label: "com.foviox.video_queue")
            videoWriterInput.requestMediaDataWhenReady(on: videoQueue) {
                while videoWriterInput.isReadyForMoreMediaData {
                    if self.isCancelled {
                        videoWriterInput.markAsFinished()
                        group.leave()
                        return
                    }

                    if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let currentProgress = CMTimeGetSeconds(time) / duration
                        
                        DispatchQueue.main.async {
                            self.progressHandler?(min(max(currentProgress, 0.0), 1.0))
                        }

                        videoWriterInput.append(sampleBuffer)
                    } else {
                        videoWriterInput.markAsFinished()
                        group.leave()
                        break
                    }
                }
            }

            // Сжатие Аудио
            if let audioInput = audioWriterInput, let audioOutput = audioReaderOutput {
                group.enter()
                let audioQueue = DispatchQueue(label: "com.foviox.audio_queue")
                audioInput.requestMediaDataWhenReady(on: audioQueue) {
                    while audioInput.isReadyForMoreMediaData {
                        if self.isCancelled {
                            audioInput.markAsFinished()
                            group.leave()
                            return
                        }

                        if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                            audioInput.append(sampleBuffer)
                        } else {
                            audioInput.markAsFinished()
                            group.leave()
                            break
                        }
                    }
                }
            }

            // Завершение процесса
            group.notify(queue: .main) {
                if self.isCancelled {
                    self.assetReader?.cancelReading()
                    self.assetWriter?.cancelWriting()
                    completion(.failure(TranscodeError(code: "CANCELLED", message: "Export cancelled")))
                    return
                }

                self.assetWriter?.finishWriting {
                    DispatchQueue.main.async {
                        if self.assetWriter?.status == .completed {
                            self.progressHandler?(1.0)
                            completion(.success(path: outputUrl.path, wasTranscoded: true))
                        } else {
                            let err = self.assetWriter?.error?.localizedDescription ?? "Writer failed"
                            completion(.failure(TranscodeError(code: "EXPORT_FAILED", message: err)))
                        }
                    }
                }
            }

        } catch {
            DispatchQueue.main.async {
                completion(.failure(TranscodeError(code: "INIT_FAILED", message: error.localizedDescription)))
            }
        }
    }

    public func cancel() {
        self.isCancelled = true
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