import AVFoundation
import Foundation
import Observation
import Speech

/// In-app speech-to-text. ON-DEVICE ONLY: if the device can't recognise speech locally we refuse
/// rather than send audio to a server (PLAN.md §6.4).
@MainActor
@Observable
final class VoiceListener {
    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var isFinal = false
    var error: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        reset()
        guard await Self.requestSpeechPermission() == .authorized else {
            error = "Speech recognition permission denied. Enable it in Settings."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            error = "Microphone permission denied. Enable it in Settings."
            return
        }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            error = "On-device speech recognition isn't available on this device, so voice is disabled."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request

            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0),
                             block: Self.makeTap(request))
            engine.prepare()
            try engine.start()

            task = recognizer.recognitionTask(with: request, resultHandler: Self.makeHandler { [weak self] text, final, failed in
                Task { @MainActor in self?.update(text: text, final: final, failed: failed) }
            })
            isListening = true
        } catch {
            self.error = "Couldn't start the microphone: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cancel() {
        task?.cancel()
        task = nil
        stop()
    }

    private func reset() {
        transcript = ""
        isFinal = false
        error = nil
    }

    private func update(text: String?, final: Bool, failed: Bool) {
        if let text { transcript = text }
        if final || failed {
            isFinal = true
            task = nil
            stop()
        }
    }

    // Closures below run on audio / recognition threads, so they are built outside MainActor isolation.

    private nonisolated static func makeTap(_ request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    private nonisolated static func makeHandler(
        _ deliver: @escaping @Sendable (String?, Bool, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            deliver(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil)
        }
    }

    private nonisolated static func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
