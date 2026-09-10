import Flutter
import AVFoundation

public class VideoTranscoderPlugin: NSObject, FlutterPlugin {
    private static let methodChannelName = "com.foviox.app/transcoder"
    private static let progressChannelName = "com.foviox.app/transcoder/progress"

    private var progressSink: FlutterEventSink?
    private var transcoder: HdrToSdrTranscoder?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VideoTranscoderPlugin()

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

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
