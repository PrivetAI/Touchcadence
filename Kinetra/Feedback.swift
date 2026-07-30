import Foundation
import AVFoundation
import CoreHaptics

/// Sound (AVFoundation) and vibration (CoreHaptics) feedback.
/// Tones are synthesized at runtime, so the app ships no audio files.
final class FeedbackEngine {

    enum Cue {
        case hit, miss, countdown, finish

        var frequency: Double {
            switch self {
            case .hit: return 880
            case .miss: return 180
            case .countdown: return 520
            case .finish: return 660
            }
        }

        var duration: Double {
            switch self {
            case .hit: return 0.06
            case .miss: return 0.13
            case .countdown: return 0.09
            case .finish: return 0.32
            }
        }
    }

    static let shared = FeedbackEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var audioReady = false

    private var hapticEngine: CHHapticEngine?
    private var hapticsReady = false

    private init() {}

    // MARK: - Setup

    func prepare() {
        prepareAudio()
        prepareHaptics()
    }

    private func prepareAudio() {
        guard !audioReady else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        for cue in [Cue.hit, .miss, .countdown, .finish] {
            if let buffer = makeBuffer(cue: cue, format: format) {
                buffers[key(cue)] = buffer
            }
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
            audioReady = true
        } catch {
            audioReady = false
        }
    }

    private func key(_ cue: Cue) -> String {
        switch cue {
        case .hit: return "hit"
        case .miss: return "miss"
        case .countdown: return "countdown"
        case .finish: return "finish"
        }
    }

    private func makeBuffer(cue: Cue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * cue.duration)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let n = Int(frames)
        for i in 0..<n {
            let t = Double(i) / format.sampleRate
            let progress = Double(i) / Double(n)
            // Short percussive envelope, no clicks at either edge.
            let attack = min(1.0, progress / 0.05)
            let decay = pow(1.0 - progress, 2.2)
            var sample = sin(2 * .pi * cue.frequency * t)
            if cue == .finish {
                sample = (sample + 0.6 * sin(2 * .pi * cue.frequency * 1.5 * t)) / 1.6
            }
            if cue == .miss {
                sample = (sample + 0.4 * sin(2 * .pi * cue.frequency * 0.5 * t)) / 1.4
            }
            channel[i] = Float(sample * attack * decay * 0.28)
        }
        return buffer
    }

    private func prepareHaptics() {
        guard !hapticsReady, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in try? self?.hapticEngine?.start() }
            engine.stoppedHandler = { _ in }
            try engine.start()
            hapticEngine = engine
            hapticsReady = true
        } catch {
            hapticsReady = false
        }
    }

    // MARK: - Playback

    func play(_ cue: Cue, sound: Bool, vibration: Bool) {
        if sound {
            if !audioReady { prepareAudio() }
            if audioReady, let buffer = buffers[key(cue)] {
                player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            }
        }
        if vibration { tap(cue) }
    }

    private func tap(_ cue: Cue) {
        guard hapticsReady, let engine = hapticEngine else { return }
        let intensity: Float
        let sharpness: Float
        switch cue {
        case .hit: intensity = 0.7; sharpness = 0.8
        case .miss: intensity = 0.4; sharpness = 0.2
        case .countdown: intensity = 0.5; sharpness = 0.5
        case .finish: intensity = 1.0; sharpness = 0.6
        }
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [
                                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                                  ],
                                  relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are optional; ignore failures.
        }
    }
}
