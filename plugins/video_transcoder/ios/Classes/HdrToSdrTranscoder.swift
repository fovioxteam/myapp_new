import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
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
    private var isCancelled = false
    private var progressTimer: Timer?

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

        if !isHdr && fileSize <= maxOriginalSizeBytes {
            DispatchQueue.main.async {
                self.progressHandler?(1.0)
                completion(.success(path: inputUrl.path, wasTranscoded: false))
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.performTranscode(asset: asset, inputUrl: inputUrl, outputUrl: outputUrl, completion: completion)
        }
    }

    private func performTranscode(
        asset: AVURLAsset,
        inputUrl: URL,
        outputUrl: URL,
        completion: @escaping (TranscodeOutcome) -> Void
    ) {
        do {
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                throw NSError(domain: "HdrToSdrTranscoder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track"])
            }

            let audioTrack = asset.tracks(withMediaType: .audio).first

            let (outWidth, outHeight) = TargetSize.calculate(
                naturalSize: videoTrack.naturalSize,
                preferredTransform: videoTrack.preferredTransform
            )

            let sourceFps = videoTrack.nominalFrameRate
            let targetFps = min(max(sourceFps, 1.0), 30.0)

            let videoBitrate = Bitrate.calculate(width: outWidth, height: outHeight)

            let reader = try AVAssetReader(asset: asset)

            let videoOutputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoOutputSettings)
            videoReaderOutput.alwaysCopiesSampleData = false
            reader.add(videoReaderOutput)

            var audioReaderOutput: AVAssetReaderTrackOutput?
            if let audioTrack = audioTrack {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                ]
                let out = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioSettings)
                reader.add(out)
                audioReaderOutput = out
            }

            try? FileManager.default.removeItem(at: outputUrl)
            let writer = try AVAssetWriter(outputURL: outputUrl, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: outWidth,
                AVVideoHeightKey: outHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: videoBitrate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: Int(targetFps * 2),
                    AVVideoExpectedSourceFrameRateKey: Int(targetFps),
                    AVVideoAllowFrameReorderingKey: true,
                ],
            ]
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput.expectsMediaDataInRealTime = false

            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: outWidth,
                kCVPixelBufferHeightKey as String: outHeight,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )

            writer.add(videoWriterInput)

            var audioWriterInput: AVAssetWriterInput?
            if audioReaderOutput != nil {
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128000,
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                input.expectsMediaDataInRealTime = false
                writer.add(input)
                audioWriterInput = input
            }

            guard reader.startReading() else {
                throw reader.error ?? NSError(domain: "HdrToSdrTranscoder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reader failed"])
            }
            guard writer.startWriting() else {
                throw writer.error ?? NSError(domain: "HdrToSdrTranscoder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Writer failed"])
            }
            writer.startSession(atSourceTime: .zero)

            let ciContext = CIContext(options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            ])

            let videoQueue = DispatchQueue(label: "video.transcode.queue")
            let audioQueue = DispatchQueue(label: "audio.transcode.queue")

            let group = DispatchGroup()
            group.enter()
            group.enter()

            let totalDuration = CMTimeGetSeconds(asset.duration)
            if totalDuration > 0 {
                DispatchQueue.main.async {
                    self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                        guard let self = self else { return }
                        let current = CMTimeGetSeconds(writer.currentTime)
                        let progress = min(max(current / totalDuration, 0.0), 1.0)
                        self.progressHandler?(progress)
                    }
                }
            }

            videoWriterInput.requestMediaDataWhenReady(on: videoQueue) {
                while videoWriterInput.isReadyForMoreMediaData {
                    guard let sample = videoReaderOutput.copyNextSampleBuffer() else {
                        videoWriterInput.markAsFinished()
                        group.leave()
                        return
                    }

                    autoreleasepool {
                        if let pixelBuffer = self.convertSample(sample: sample, width: outWidth, height: outHeight, ciContext: ciContext) {
                            let time = CMSampleBufferGetPresentationTimeStamp(sample)
                            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: time)
                        }
                    }
                }
            }

            if let audioInput = audioWriterInput, let audioOut = audioReaderOutput {
                audioInput.requestMediaDataWhenReady(on: audioQueue) {
                    while audioInput.isReadyForMoreMediaData {
                        guard let sample = audioOut.copyNextSampleBuffer() else {
                            audioInput.markAsFinished()
                            group.leave()
                            return
                        }
                        audioInput.append(sample)
                    }
                }
            } else {
                group.leave()
            }

            group.notify(queue: .global(qos: .userInitiated)) {
                self.stopTimer()

                if self.isCancelled {
                    writer.cancelWriting()
                    completion(.failure(TranscodeError(code: "CANCELLED", message: "Cancelled")))
                    return
                }

                if reader.status == .failed {
                    writer.cancelWriting()
                    completion(.failure(TranscodeError(code: "READER_FAILED", message: reader.error?.localizedDescription ?? "Reader failed")))
                    return
                }

                writer.finishWriting {
                    if writer.status == .completed {
                        DispatchQueue.main.async {
                            self.progressHandler?(1.0)
                            completion(.success(path: outputUrl.path, wasTranscoded: true))
                        }
                    } else {
                        completion(.failure(TranscodeError(code: "WRITER_FAILED", message: writer.error?.localizedDescription ?? "Writer failed")))
                    }
                }
            }
        } catch {
            completion(.failure(TranscodeError(code: "TRANSCODE_FAILED", message: error.localizedDescription)))
        }
    }

    private func convertSample(sample: CMSampleBuffer, width: Int, height: Int, ciContext: CIContext) -> CVPixelBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sample) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        let toneMapped = ciImage.applyingFilter("CIToneCurve", parameters: [
            "inputPoint0": CIVector(x: 0.0, y: 0.0),
            "inputPoint1": CIVector(x: 0.25, y: 0.25),
            "inputPoint2": CIVector(x: 0.5, y: 0.55),
            "inputPoint3": CIVector(x: 0.75, y: 0.85),
            "inputPoint4": CIVector(x: 1.0, y: 1.0),
        ])

        let scale = min(CGFloat(width) / ciImage.extent.width, CGFloat(height) / ciImage.extent.height)
        let scaled = toneMapped.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]

        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)

        guard let outputBuffer = pixelBuffer else { return nil }

        ciContext.render(scaled, to: outputBuffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))

        return outputBuffer
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

enum HdrDetector {
    static func isHdr(asset: AVAsset) -> Bool {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return false }

        for formatDescription in videoTrack.formatDescriptions {
            let desc = formatDescription as! CMFormatDescription

            if let transferFunction = CMFormatDescriptionGetExtension(desc, extensionKey: kCMFormatDescriptionExtension_TransferFunction) as? String {
                if transferFunction == "ITU_R_2100_HLG" || transferFunction == "SMPTE_ST_2084_PQ" {
                    return true
                }
            }

            if let primaries = CMFormatDescriptionGetExtension(desc, extensionKey: kCMFormatDescriptionExtension_ColorPrimaries) as? String {
                if primaries == "ITU_R_2020" {
                    return true
                }
            }
        }

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

enum TargetSize {
    static func calculate(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> (width: Int, height: Int) {
        let transformed = naturalSize.applying(preferredTransform)
        let absWidth = abs(transformed.width)
        let absHeight = abs(transformed.height)

        let shortSide = min(absWidth, absHeight)
        let maxShortSide: CGFloat = 1080

        if shortSide <= maxShortSide {
            return (width: Int(absWidth.rounded()), height: Int(absHeight.rounded()))
        }

        let scale = maxShortSide / shortSide
        let newWidth = (absWidth * scale).rounded()
        let newHeight = (absHeight * scale).rounded()

        let evenWidth = Int(newWidth) - (Int(newWidth) % 2)
        let evenHeight = Int(newHeight) - (Int(newHeight) % 2)

        return (width: evenWidth, height: evenHeight)
    }
}

enum Bitrate {
    static func calculate(width: Int, height: Int) -> Int {
        let pixels = width * height
        let basePixels = 1920 * 1080
        let baseBitrate = 6_000_000

        let bitrate = Int(Double(baseBitrate) * Double(pixels) / Double(basePixels))

        return min(max(bitrate, 1_500_000), 8_000_000)
    }
}
