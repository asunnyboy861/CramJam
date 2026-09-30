import AVFoundation
import Foundation

struct SentenceData {
    var text: String
    var start: Double
    var end: Double
    var confidence: Double
}

final class AudioBufferConverter {
    let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter

    init?(from input: AVAudioFormat, to output: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: input, to: output) else { return nil }
        self.converter = converter
        self.outputFormat = output
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let ratio = outputFormat.sampleRate / max(buffer.format.sampleRate, 1)
        let capacity = AVAudioFrameCount(Double(max(buffer.frameLength, 1)) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        if status == .error { return nil }
        if outBuffer.frameLength == 0 { return nil }
        return outBuffer
    }
}

final class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var liveCaption = ""
    @Published var statusText = ""

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var fileConverter: AudioBufferConverter?
    private var speechConverter: AudioBufferConverter?
    private var modernRef: AnyObject?
    private var legacy: LegacyTranscriber?
    private var finals: [SentenceData] = []
    private var totalFrames: Double = 0
    private(set) var audioURL: URL?
    private let lock = NSLock()
    private let tapQueue = DispatchQueue(label: "com.zzoutuo.cramjam.audio")

    static func recordingsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(forFileName name: String) -> URL {
        recordingsDirectory().appendingPathComponent(name)
    }

    @available(iOS 26.0, *)
    private var modern: ModernTranscriber? {
        get { modernRef as? ModernTranscriber }
        set { modernRef = newValue }
    }

    func start(language: String) async {
        guard !isRecording else { return }
        finals = []
        totalFrames = 0
        elapsed = 0
        liveCaption = ""
        statusText = ""

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            statusText = "Audio session failed: \(error.localizedDescription)"
            return
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            statusText = "Microphone permission is required to record."
            return
        }

        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechAuth == .authorized else {
            statusText = "Speech recognition permission is required for captions."
            return
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            statusText = "No microphone input available."
            return
        }

        let fileName = "lecture-\(Int(Date().timeIntervalSince1970)).m4a"
        let url = Self.recordingsDirectory().appendingPathComponent(fileName)
        guard let file = try? AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        ) else {
            statusText = "Could not create the recording file."
            return
        }
        audioFile = file
        audioURL = url
        fileConverter = AudioBufferConverter(from: inputFormat, to: file.processingFormat)

        var usedModern = false
        if #available(iOS 26, *), SpeechTranscriber.isAvailable {
            if let locale = await ModernTranscriber.supportedLocale(for: language) {
                let transcriber = ModernTranscriber(locale: locale)
                if let bestFormat = await transcriber.bestFormat(),
                   let converter = AudioBufferConverter(from: inputFormat, to: bestFormat) {
                    wireCallbacksModern(transcriber)
                    do {
                        try await transcriber.start()
                        modern = transcriber
                        speechConverter = converter
                        usedModern = true
                    } catch {
                        modern = nil
                        speechConverter = nil
                    }
                }
            }
        }
        if !usedModern {
            let legacyTranscriber = LegacyTranscriber()
            wireCallbacks(legacy: legacyTranscriber)
            legacyTranscriber.setup(language: language)
            legacyTranscriber.start()
            legacy = legacyTranscriber
            if speechConverter == nil {
                if let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) {
                    speechConverter = AudioBufferConverter(from: inputFormat, to: target)
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let copy = buffer.copy() as? AVAudioPCMBuffer
            self.tapQueue.async {
                guard let copy else { return }
                self.handle(buffer: copy)
            }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            statusText = "Could not start recording: \(error.localizedDescription)"
            inputNode.removeTap(onBus: 0)
            return
        }
        isRecording = true
    }

    @available(iOS 26.0, *)
    private func wireCallbacksModern(_ modern: ModernTranscriber) {
        modern.onVolatile = { [weak self] text in
            DispatchQueue.main.async { self?.liveCaption = text }
        }
        modern.onFinal = { [weak self] sentence in
            self?.appendFinal(sentence)
        }
    }

    private func wireCallbacks(legacy: LegacyTranscriber) {
        legacy.onVolatile = { [weak self] text in
            DispatchQueue.main.async { self?.liveCaption = text }
        }
        legacy.onFinal = { [weak self] sentence in
            self?.appendFinal(sentence)
        }
    }

    private func appendFinal(_ sentence: SentenceData) {
        lock.lock()
        finals.append(sentence)
        lock.unlock()
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        if let fileConverter, let out = fileConverter.convert(buffer) {
            try? audioFile?.write(from: out)
            totalFrames += Double(out.frameLength)
            let seconds = totalFrames / max(fileConverter.outputFormat.sampleRate, 1)
            DispatchQueue.main.async { self.elapsed = seconds }
        }
        if let speechConverter, let out = speechConverter.convert(buffer) {
            if #available(iOS 26.0, *) {
                modern?.append(out)
            }
            legacy?.append(out)
        }
    }

    func stop() async -> (sentences: [SentenceData], url: URL?) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        if #available(iOS 26, *), let modern {
            await modern.finish()
        }
        legacy?.finishCollection()
        try? await Task.sleep(nanoseconds: 600_000_000)
        let collected = lock.withLock { finals }
        liveCaption = ""
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (collected, audioURL)
    }
}

import Speech

@available(iOS 26.0, *)
final class ModernTranscriber: @unchecked Sendable {
    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    var onVolatile: ((String) -> Void)?
    var onFinal: ((SentenceData) -> Void)?

    init(locale: Locale) {
        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        analyzer = SpeechAnalyzer(modules: [transcriber])
    }

    static func supportedLocale(for identifier: String) async -> Locale? {
        let target = Locale(identifier: identifier)
        let supported = await SpeechTranscriber.supportedLocales
        if supported.contains(target) { return target }
        return await SpeechTranscriber.supportedLocale(equivalentTo: target)
    }

    func bestFormat() async -> AVAudioFormat? {
        await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    }

    func start() async throws {
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.continuation = continuation
        resultsTask = Task { [weak self] in
            guard let self else { return }
            var lastFinalEnd: Double = -1
            do {
                for try await result in self.transcriber.results {
                    let text = String(result.text.characters)
                    let isFinal = result.resultsFinalizationTime.isValid
                    if !isFinal {
                        self.onVolatile?(text)
                    } else if !text.isEmpty, result.range.start.seconds >= lastFinalEnd - 0.3 {
                        lastFinalEnd = result.range.end.seconds
                        self.onFinal?(SentenceData(
                            text: text,
                            start: result.range.start.seconds,
                            end: result.range.end.seconds,
                            confidence: 1.0
                        ))
                        self.onVolatile?("")
                    }
                }
            } catch {
                self.onVolatile?("")
            }
        }
        try await analyzer.start(inputSequence: stream)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        continuation?.yield(AnalyzerInput(buffer: buffer))
    }

    func finish() async {
        continuation?.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
    }
}

final class LegacyTranscriber: NSObject {
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var baseOffset: TimeInterval = 0
    private var appendedFrames: Double = 0
    var onVolatile: ((String) -> Void)?
    var onFinal: ((SentenceData) -> Void)?

    func setup(language: String) {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) ?? SFSpeechRecognizer()
    }

    func start() {
        guard let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                if result.isFinal {
                    self.commit(transcription: result.bestTranscription, final: true)
                } else {
                    self.onVolatile?(result.bestTranscription.formattedString)
                }
            } else if error != nil {
                self.onVolatile?("")
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        appendedFrames += Double(buffer.frameLength)
        let audioElapsed = appendedFrames / max(buffer.format.sampleRate, 1)
        if request != nil, audioElapsed - baseOffset > 580 {
            baseOffset = audioElapsed
            request?.endAudio()
            task = nil
            start()
        }
        request?.append(buffer)
    }

    func finishCollection() {
        request?.endAudio()
    }

    private func commit(transcription: SFTranscription, final: Bool) {
        let segments = transcription.segments
        guard !segments.isEmpty else { return }
        var group: [SFTranscriptionSegment] = []
        func flush() {
            guard !group.isEmpty else { return }
            let words = group.map { $0.substring }
            let text = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                let first = group[0]
                let last = group[group.count - 1]
                let start = baseOffset + first.timestamp
                let end = baseOffset + last.timestamp + last.duration
                let confidenceSum = group.reduce(0.0) { $0 + Double($1.confidence) }
                let confidence = confidenceSum / Double(group.count)
                onFinal?(SentenceData(text: text, start: start, end: end, confidence: confidence))
            }
            group = []
        }
        for segment in segments {
            group.append(segment)
            let last = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            if last.hasSuffix(".") || last.hasSuffix("!") || last.hasSuffix("?") {
                flush()
            }
        }
        flush()
        if final {
            onVolatile?("")
        }
    }
}
