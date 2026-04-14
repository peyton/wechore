import AVFoundation
import Foundation
import Speech

public struct VoiceTranscript: Hashable, Sendable {
    public var text: String
    public var confidence: Double?

    public init(text: String, confidence: Double? = nil) {
        self.text = text
        self.confidence = confidence
    }
}

public enum VoiceMessageError: Equatable, LocalizedError {
    case microphoneDenied
    case speechDenied
    case speechUnavailable
    case notRecording
    case emptyTranscript
    case missingAudioFile

    public var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone access is needed to record a voice message."
        case .speechDenied:
            "Speech recognition access is needed to turn voice into chores."
        case .speechUnavailable:
            "Speech recognition is not available right now."
        case .notRecording:
            "No voice message is recording."
        case .emptyTranscript:
            "WeChore could not hear enough to make a transcript."
        case .missingAudioFile:
            "The voice message audio file is missing."
        }
    }
}

public enum VoiceMessageFiles {
    public static let directoryName = "VoiceMessages"

    public static func directoryURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func fileURL(for filename: String) throws -> URL {
        try directoryURL().appendingPathComponent(filename, isDirectory: false)
    }
}

@MainActor
public protocol VoiceMessageRecording: AnyObject {
    func startRecording(to url: URL) async throws
    func stopRecording() async throws -> TimeInterval
    func cancelRecording()
}

@MainActor
public protocol VoiceMessageTranscribing {
    func transcript(for audioURL: URL) async throws -> VoiceTranscript
}

@MainActor
public protocol VoiceMessageStorage {
    func makeRecordingURL() throws -> URL
    func attachment(for url: URL, duration: TimeInterval, transcriptConfidence: Double?) -> VoiceAttachment
    func fileURL(for attachment: VoiceAttachment) throws -> URL
}

@MainActor
public protocol VoiceMessagePlaying: AnyObject {
    @discardableResult
    func play(url: URL) throws -> TimeInterval
}

public struct LocalVoiceMessageStorage: VoiceMessageStorage {
    public init() {}

    public func makeRecordingURL() throws -> URL {
        let filename = "voice-\(UUID().uuidString).m4a"
        return try VoiceMessageFiles.fileURL(for: filename)
    }

    public func attachment(
        for url: URL,
        duration: TimeInterval,
        transcriptConfidence: Double?
    ) -> VoiceAttachment {
        VoiceAttachment(
            localAudioFilename: url.lastPathComponent,
            duration: duration,
            transcriptConfidence: transcriptConfidence
        )
    }

    public func fileURL(for attachment: VoiceAttachment) throws -> URL {
        let url = try VoiceMessageFiles.fileURL(for: attachment.localAudioFilename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VoiceMessageError.missingAudioFile
        }
        return url
    }
}

@MainActor
public final class AppleVoiceMessageRecorder: NSObject, VoiceMessageRecording {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startedAt: Date?

    public override init() {}

    public func startRecording(to url: URL) async throws {
        let allowed = await Self.requestRecordPermission()
        guard allowed else { throw VoiceMessageError.microphoneDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
        recordingURL = url
        startedAt = Date()
    }

    public func stopRecording() async throws -> TimeInterval {
        guard let recorder else { throw VoiceMessageError.notRecording }
        let duration = max(recorder.currentTime, startedAt.map { Date().timeIntervalSince($0) } ?? 0)
        recorder.stop()
        self.recorder = nil
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard recordingURL != nil else { throw VoiceMessageError.missingAudioFile }
        recordingURL = nil
        return duration
    }

    public func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        recordingURL = nil
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}

public struct AppleSpeechVoiceMessageTranscriber: VoiceMessageTranscribing {
    public init() {}

    public func transcript(for audioURL: URL) async throws -> VoiceTranscript {
        let authorizationStatus = await Self.requestSpeechAuthorization()
        guard authorizationStatus == .authorized else { throw VoiceMessageError.speechDenied }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw VoiceMessageError.speechUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        let transcript: VoiceTranscript = try await withCheckedThrowingContinuation { continuation in
            let box = VoiceTranscriptContinuationBox()
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    box.resume {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let confidence = Self.averageConfidence(in: result.bestTranscription.segments)
                box.resume {
                    continuation.resume(returning: VoiceTranscript(text: text, confidence: confidence))
                }
            }
        }

        guard !transcript.text.isEmpty else { throw VoiceMessageError.emptyTranscript }
        return transcript
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func averageConfidence(in segments: [SFTranscriptionSegment]) -> Double? {
        guard !segments.isEmpty else { return nil }
        let total = segments.reduce(0) { $0 + Double($1.confidence) }
        return total / Double(segments.count)
    }
}

@MainActor
public final class AppleVoiceMessagePlayer: NSObject, VoiceMessagePlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    public override init() {}

    @discardableResult
    public func play(url: URL) throws -> TimeInterval {
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        self.player = player
        return player.duration
    }
}

@MainActor
public final class FakeVoiceMessageRecorder: VoiceMessageRecording {
    private var recordingURL: URL?
    private let duration: TimeInterval

    public init(duration: TimeInterval = 2.4) {
        self.duration = duration
    }

    public func startRecording(to url: URL) async throws {
        recordingURL = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("fake-voice-message".utf8).write(to: url)
    }

    public func stopRecording() async throws -> TimeInterval {
        guard recordingURL != nil else { throw VoiceMessageError.notRecording }
        recordingURL = nil
        return duration
    }

    public func cancelRecording() {
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }
}

public struct FakeVoiceMessageTranscriber: VoiceMessageTranscribing {
    private let transcript: String

    public init(transcript: String) {
        self.transcript = transcript
    }

    public func transcript(for audioURL: URL) async throws -> VoiceTranscript {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw VoiceMessageError.missingAudioFile
        }
        return VoiceTranscript(text: transcript, confidence: 1)
    }
}

@MainActor
public final class FakeVoiceMessagePlayer: VoiceMessagePlaying {
    public init() {}

    @discardableResult
    public func play(url: URL) throws -> TimeInterval {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VoiceMessageError.missingAudioFile
        }
        return 2.4
    }
}

private final class VoiceTranscriptContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resume(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        body()
    }
}
