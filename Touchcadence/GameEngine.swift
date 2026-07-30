import Foundation
import SwiftUI
import QuartzCore

/// Drives one live session: the clock, the target, the taps and the score.
@MainActor
final class GameEngine: ObservableObject {

    struct FloatingHit: Identifiable {
        let id = UUID()
        var text: String
        var point: CGPoint
        var born: Double
        var isMiss: Bool
    }

    struct Ripple: Identifiable {
        let id = UUID()
        var point: CGPoint
        var born: Double
        var isMiss: Bool
    }

    // MARK: - Published

    @Published private(set) var targetPoint: CGPoint = .zero
    @Published private(set) var remaining: Double = 0
    @Published private(set) var score: Int = 0
    @Published private(set) var combo: Int = 0
    @Published private(set) var multiplier: Double = 1
    @Published private(set) var accuracy: Double = 0
    @Published private(set) var lastReaction: Double = 0
    @Published private(set) var hits: Int = 0
    @Published private(set) var misses: Int = 0
    @Published private(set) var floaters: [FloatingHit] = []
    @Published private(set) var ripples: [Ripple] = []
    @Published private(set) var isPaused = false
    @Published private(set) var isFinished = false
    @Published private(set) var targetProgress: Double = 0   // 0...1 of the target lifetime
    @Published private(set) var now: Double = CACurrentMediaTime()

    // MARK: - Config

    let training: Training
    let motion: MotionEngine
    private let settings: AppSettings
    /// Field size handed down from the parent GeometryReader — never a Canvas closure size.
    private(set) var fieldSize: CGSize = CGSize(width: 320, height: 420)

    private var engineScore: ScoreEngine
    private var timer: Timer?
    private var startTime: Double = 0
    private var pausedAt: Double?
    private var pausedTotal: Double = 0
    private var targetSpawn: Double = 0
    private var seed: Int = 1
    private var lastHitTime: Double?
    /// Snapshot of the touch that is still down. SwiftUI re-delivers gesture callbacks on every
    /// view update, so a touch is registered once on the way down and scored once on release.
    private var pendingTouch: (time: Double, point: CGPoint, target: CGPoint, radius: CGFloat)?

    var radius: CGFloat {
        let base = training.targetSize.baseRadius * training.difficulty.sizeMultiplier
        let userScale = training.isCustom ? 1.0 : settings.targetSize.baseRadius / TargetSize.medium.baseRadius
        let scaled = base * userScale
        let cap = Double(min(fieldSize.width, fieldSize.height)) * 0.16
        return CGFloat(max(14, min(scaled, cap)))
    }

    var speed: Double { training.difficulty.speedMultiplier * settings.speed }

    var duration: Double { Double(training.duration) }

    init(training: Training, motion: MotionEngine, settings: AppSettings) {
        self.training = training
        self.motion = motion
        self.settings = settings
        self.engineScore = ScoreEngine(difficulty: training.difficulty)
        self.remaining = Double(training.duration)
    }

    // MARK: - Lifecycle

    func setField(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        fieldSize = size
        if targetPoint == .zero { refreshTargetPoint() }
    }

    func start() {
        guard timer == nil else { return }
        startTime = CACurrentMediaTime()
        pausedTotal = 0
        pausedAt = nil
        spawnTarget(at: startTime)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause() {
        guard !isPaused, !isFinished else { return }
        isPaused = true
        pausedAt = CACurrentMediaTime()
    }

    func resume() {
        guard isPaused else { return }
        if let pausedAt {
            let delta = CACurrentMediaTime() - pausedAt
            pausedTotal += delta
            targetSpawn += delta
            if let last = lastHitTime { lastHitTime = last + delta }
        }
        pausedAt = nil
        isPaused = false
    }

    private var clock: Double { CACurrentMediaTime() - startTime - pausedTotal }

    // MARK: - Loop

    private func tick() {
        guard !isFinished else { return }
        now = CACurrentMediaTime()
        guard !isPaused else { return }

        let elapsed = clock
        remaining = max(0, duration - elapsed)

        // Safety net: if a gesture is cancelled without an end callback, score the touch anyway.
        if let touch = pendingTouch, now - touch.time > 1.5 {
            pendingTouch = nil
            resolve(touch)
        }

        let age = now - targetSpawn
        let lifetime = training.difficulty.targetLifetime
        targetProgress = min(1, age / lifetime)
        if age >= lifetime {
            registerExpiry()
        }
        refreshTargetPoint()

        floaters.removeAll { now - $0.born > 0.9 }
        ripples.removeAll { now - $0.born > 0.45 }

        if remaining <= 0 { finish() }
    }

    private func refreshTargetPoint() {
        let age = max(0, CACurrentMediaTime() - targetSpawn)
        targetPoint = motion.position(movement: training.movement, t: age, speed: speed,
                                      seed: seed, field: fieldSize, radius: radius)
    }

    private func spawnTarget(at time: Double) {
        targetSpawn = time
        seed = Int.random(in: 1...100_000)
        targetProgress = 0
        refreshTargetPoint()
    }

    // MARK: - Input

    /// Records the touch going down. Repeated delivery of the same touch is ignored.
    func touchBegan(at point: CGPoint) {
        guard !isPaused, !isFinished, pendingTouch == nil else { return }
        pendingTouch = (CACurrentMediaTime(), point, targetPoint, radius)
    }

    /// Scores the touch on release, judged against where the target was when the finger landed.
    func touchEnded() {
        guard let touch = pendingTouch else { return }
        pendingTouch = nil
        guard !isFinished else { return }
        resolve(touch)
    }

    private func resolve(_ touch: (time: Double, point: CGPoint, target: CGPoint, radius: CGFloat)) {
        let t = touch.time
        let point = touch.point
        let dx = point.x - touch.target.x
        let dy = point.y - touch.target.y
        let hit = sqrt(dx * dx + dy * dy) <= touch.radius + 6

        let stamp = CACurrentMediaTime()
        if hit {
            let reaction = max(0.05, t - targetSpawn)
            let interval = lastHitTime.map { t - $0 }
            engineScore.record(PlayEvent(isHit: true, reaction: reaction, interval: interval))
            lastHitTime = t
            lastReaction = reaction
            floaters.append(FloatingHit(text: "+\(Int(engineScore.lastGain.rounded()))",
                                       point: touch.target, born: stamp, isMiss: false))
            ripples.append(Ripple(point: touch.target, born: stamp, isMiss: false))
            FeedbackEngine.shared.play(.hit, sound: settings.sound, vibration: settings.vibration)
            spawnTarget(at: stamp)
        } else {
            engineScore.record(PlayEvent(isHit: false, reaction: 0, interval: nil))
            floaters.append(FloatingHit(text: "MISS", point: point, born: stamp, isMiss: true))
            ripples.append(Ripple(point: point, born: stamp, isMiss: true))
            FeedbackEngine.shared.play(.miss, sound: settings.sound, vibration: settings.vibration)
        }
        syncPublished()
    }

    /// A target that ran out of time counts as a miss and breaks the combo.
    private func registerExpiry() {
        engineScore.record(PlayEvent(isHit: false, reaction: 0, interval: nil))
        floaters.append(FloatingHit(text: "LOST", point: targetPoint, born: CACurrentMediaTime(), isMiss: true))
        spawnTarget(at: CACurrentMediaTime())
        syncPublished()
    }

    private func syncPublished() {
        score = engineScore.finalScore
        combo = engineScore.combo
        multiplier = engineScore.multiplier
        accuracy = engineScore.accuracy
        hits = engineScore.hits
        misses = engineScore.misses
    }

    // MARK: - Finish

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        stop()
        syncPublished()
        FeedbackEngine.shared.play(.finish, sound: settings.sound, vibration: settings.vibration)
    }

    func finishNow() { finish() }

    var stability: Double { engineScore.stability }
    var rhythm: Double { engineScore.rhythm }
    var bestCombo: Int { engineScore.bestCombo }
    var averageReaction: Double { engineScore.averageReaction }
    var rank: Rank { engineScore.rank }
    var experienceGain: Int { engineScore.experienceGain }

    func makeResult() -> SessionResult { engineScore.makeResult(training: training) }
}
