import Flutter
import AVFoundation
import UIKit

public class VideoTranscoderPlugin: NSObject, FlutterPlugin {
    private static let methodChannelName = "com.foviox.app/transcoder"
    private static let progressChannelName = "com.foviox.app/transcoder/progress"

    private var progressSink: FlutterEventSink?
    private var transcoder: HdrToSdrTranscoder?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VideoTranscoderPlugin()

        // Method channel
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // Progress event channel
        let progressChannel = FlutterEventChannel(
            name: progressChannelName,
            binaryMessenger: registrar.messenger()
        )
        progressChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "transcodeVideoPro":
            handleTranscode(call: call, result: result)

        case "getVideoThumbnail":
            handleGetThumbnail(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ============================================================
    // TRANSCODE (HDR -> SDR)
    // ============================================================
    private func handleTranscode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing inputPath or outputPath", details: nil))
            return
        }

        let maxSize = args["maxOriginalSizeBytes"] as? Int64 ?? (15 * 1024 * 1024)

        let inputUrl = URL(fileURLWithPath: inputPath)
        let outputUrl = URL(fileURLWithPath: outputPath)

        guard FileManager.default.fileExists(atPath: inputPath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Input file does not exist", details: nil))
            return
        }

        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(at: outputUrl)
        }

        let transcoder = HdrToSdrTranscoder()

        transcoder.progressHandler = { [weak self] progress in
            self?.progressSink?(progress)
        }

        self.transcoder = transcoder

        transcoder.transcode(
            inputUrl: inputUrl,
            outputUrl: outputUrl,
            maxOriginalSizeBytes: maxSize
        ) { outcome in
            DispatchQueue.main.async {
                self.transcoder = nil
                self.progressSink?(1.0)

                switch outcome {
                case .success(let path, let wasTranscoded):
                    result(["path": path, "wasTranscoded": wasTranscoded])
                case .failure(let error):
                    result(FlutterError(code: error.code, message: error.message, details: nil))
                }
            }
        }
    }

    // ============================================================
    // GET VIDEO THUMBNAIL (from original, fast)
    // ============================================================
    private func handleGetThumbnail(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing inputPath or outputPath", details: nil))
            return
        }

        let timeMs = args["timeMs"] as? Int ?? 500

        guard FileManager.default.fileExists(atPath: inputPath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Input file does not exist", details: nil))
            return
        }

        let inputUrl = URL(fileURLWithPath: inputPath)
        let outputUrl = URL(fileURLWithPath: outputPath)

        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(at: outputUrl)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: inputUrl)

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1080, height: 1080)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

            let time = CMTime(value: CMTimeValue(timeMs), timescale: 1000)

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)

                guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "JPEG_FAILED", message: "Failed to encode JPEG", details: nil))
                    }
                    return
                }

                do {
                    try jpegData.write(to: outputUrl)
                    DispatchQueue.main.async {
                        result(outputPath)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "WRITE_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "THUMBNAIL_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
}

extension VideoTranscoderPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.progressSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.progressSink = nil
        return nil
    }
}