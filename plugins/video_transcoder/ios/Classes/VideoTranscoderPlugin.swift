import Flutter
import UIKit
import AVFoundation

public class VideoTranscoderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var transcoder: HdrToSdrTranscoder?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "video_transcoder/methods", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "video_transcoder/events", binaryMessenger: registrar.messenger())
        
        let instance = VideoTranscoderPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "transcode":
            guard let args = call.arguments as? [String: Any],
                  let inputPath = args["inputPath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing path arguments", details: nil))
                return
            }

            let maxSizeBytes = (args["maxOriginalSizeBytes"] as? NSNumber)?.int64Value ?? 15_728_640
            let inputUrl = URL(fileURLWithPath: inputPath)
            let outputUrl = URL(fileURLWithPath: outputPath)

            transcoder = HdrToSdrTranscoder()
            transcoder?.progressHandler = { [weak self] progress in
                self?.eventSink?(progress)
            }

            transcoder?.transcode(
                inputUrl: inputUrl,
                outputUrl: outputUrl,
                maxOriginalSizeBytes: maxSizeBytes
            ) { outcome in
                switch outcome {
                case .success(let path, let wasTranscoded):
                    result([
                        "path": path,
                        "wasTranscoded": wasTranscoded
                    ])
                case .failure(let error):
                    result(FlutterError(code: error.code, message: error.message, details: nil))
                }
            }

        case "cancel":
            transcoder?.cancel()
            transcoder = nil
            result(nil)

        case "getVideoThumbnail":
            guard let args = call.arguments as? [String: Any],
                  let inputPath = args["inputPath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing path arguments", details: nil))
                return
            }

            let timeMs = args["timeMs"] as? Int ?? 500
            let asset = AVURLAsset(url: URL(fileURLWithPath: inputPath))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 720, height: 1280)

            let time = CMTime(value: Int64(timeMs), timescale: 1000)

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
                    let image = UIImage(cgImage: imageRef)
                    
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        try data.write(to: URL(fileURLWithPath: outputPath))
                        DispatchQueue.main.async {
                            result(outputPath)
                        }
                    } else {
                        DispatchQueue.main.async {
                            result(nil)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(nil)
                    }
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}