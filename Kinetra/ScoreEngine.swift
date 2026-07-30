import Foundation

/// One tap event fed into the score engine.
struct PlayEvent {
    /// True when the tap landed on the active target.
    var isHit: Bool
    /// Seconds between the target appearing and the tap. Ignored for misses.
    var reaction: Double
    /// Seconds since the previous hit. `nil` for the first hit.
    var interval: Double?
}

/// The running tally for a single session. Pure Foundation so it can be replayed headlessly.
struct ScoreEngine {

    let difficulty: Difficulty

    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    private(set) var combo: Int = 0
    private(set) var bestCombo: Int = 0
    private(set) var score: Double = 0
    private(set) var reactionTotal: Double = 0
    private(set) var intervals: [Double] = []
    private(set) var lastRhythmFactor: Double = 1.0
    /// Points awarded for the most recent hit (0 for a miss).
    private(set) var lastGain: Double = 0

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
    }

    // MARK: - Derived measures

    /// multiplier = min(5, 1 + combo / 20)
    var multiplier: Double { min(5.0, 1.0 + Double(combo) / 20.0) }

    /// accuracy = hits / (hits + misses)
    var accuracy: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }

    /// averageReaction = total reaction / hits
    var averageReaction: Double {
        guard hits > 0 else { return 0 }
        return reactionTotal / Double(hits)
    }

    var meanInterval: Double {
        guard !intervals.isEmpty else { return 0 }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    /// Population standard deviation of the intervals between hits, in hundredths of a second.
    var intervalDeviation: Double {
        guard intervals.count > 1 else { return 0 }
        let m = meanInterval
        let variance = intervals.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(intervals.count)
        return sqrt(variance) * 100.0
    }

    /// stability = 100 - sigma(intervals between hits), clamped to 0...100.
    var stability: Double {
        guard hits > 1 else { return 0 }
        return max(0, min(100, 100 - intervalDeviation))
    }

    /// 0...1 measure of how even the beat was.
    var rhythm: Double {
        guard hits > 1 else { return 0 }
        let m = meanInterval
        guard m > 0 else { return 0 }
        let spread = intervalDeviation / 100.0
        return max(0, min(1, 1 - spread / m))
    }

    // MARK: - Formulas

    /// reactionCoefficient = max(0.5, 1.8 - reactionTime)
    static func reactionCoefficient(_ reaction: Double) -> Double {
        max(0.5, 1.8 - reaction)
    }

    /// Rhythm weight for the next hit: 1.0 until a beat exists, then 0.8...1.2.
    func rhythmFactor(nextInterval: Double?) -> Double {
        guard let interval = nextInterval, !intervals.isEmpty else { return 1.0 }
        let m = meanInterval
        guard m > 0 else { return 1.0 }
        let error = min(1.0, abs(interval - m) / m)
        return 1.2 - 0.4 * error
    }

    // MARK: - Recording

    mutating func record(_ event: PlayEvent) {
        if event.isHit {
            let rf = rhythmFactor(nextInterval: event.interval)
            combo += 1
            bestCombo = max(bestCombo, combo)
            hits += 1
            reactionTotal += max(0, event.reaction)
            if let interval = event.interval { intervals.append(interval) }
            let points = 100.0 * multiplier * difficulty.factor * rf
            let gain = points * ScoreEngine.reactionCoefficient(max(0, event.reaction))
            score += gain
            lastGain = gain
            lastRhythmFactor = rf
        } else {
            combo = 0
            misses += 1
            lastGain = 0
        }
    }

    // MARK: - Result

    /// Composite 0...1 index the rank is read from.
    var performanceIndex: Double {
        guard hits > 0 else { return 0 }
        let reactionScore = max(0, min(1, (1.0 - averageReaction) / 0.85))
        let comboScore = max(0, min(1, Double(bestCombo) / 30.0))
        let stabilityScore = stability / 100.0
        return accuracy * 0.50 + reactionScore * 0.25 + comboScore * 0.15 + stabilityScore * 0.10
    }

    var rank: Rank {
        guard hits > 0, score > 0 else { return .d }
        let i = performanceIndex
        switch i {
        case ..<0.30: return .d
        case ..<0.45: return .c
        case ..<0.60: return .b
        case ..<0.72: return .a
        case ..<0.84: return .s
        case ..<0.93: return .ss
        default: return .sss
        }
    }

    var finalScore: Int { max(0, Int(score.rounded())) }

    /// experience = score / 20
    var experienceGain: Int { finalScore / 20 }

    func makeResult(training: Training, date: Date = Date()) -> SessionResult {
        SessionResult(trainingID: training.id,
                      trainingName: training.name,
                      score: finalScore,
                      accuracy: accuracy,
                      averageReaction: averageReaction,
                      combo: bestCombo,
                      stability: stability,
                      rhythm: rhythm,
                      rank: rank,
                      date: date)
    }
}

// MARK: - Recommendations

enum WeakestMeasure: String, CaseIterable {
    case accuracy, reaction, rhythm, stability, combo

    var title: String {
        switch self {
        case .accuracy: return "Accuracy"
        case .reaction: return "Reaction"
        case .rhythm: return "Rhythm"
        case .stability: return "Stability"
        case .combo: return "Combo"
        }
    }

    var advice: String {
        switch self {
        case .accuracy: return "Slow down and commit only when the target is fully under your finger."
        case .reaction: return "Rest your finger near the field center and answer the first frame you see it."
        case .rhythm: return "Aim for one steady beat per hit instead of bursts of taps."
        case .stability: return "Keep the gap between hits even, even when the path speeds up."
        case .combo: return "Protect the streak: a single stray tap resets the multiplier."
        }
    }

    /// The category best suited to training this measure.
    var category: TrainingCategory {
        switch self {
        case .accuracy: return .precision
        case .reaction: return .reaction
        case .rhythm: return .rhythm
        case .stability: return .control
        case .combo: return .endurance
        }
    }
}

struct Analysis {
    var accuracy: Double
    var reaction: Double
    var rhythm: Double
    var stability: Double
    var combo: Double

    /// Normalized 0...1 scores for each measure.
    var scores: [WeakestMeasure: Double] {
        [.accuracy: max(0, min(1, accuracy)),
         .reaction: max(0, min(1, (1.0 - reaction) / 0.85)),
         .rhythm: max(0, min(1, rhythm)),
         .stability: max(0, min(1, stability / 100)),
         .combo: max(0, min(1, combo / 30))]
    }

    var weakest: WeakestMeasure {
        let s = scores
        return WeakestMeasure.allCases.min { (s[$0] ?? 0) < (s[$1] ?? 0) } ?? .accuracy
    }

    static func from(results: [SessionResult]) -> Analysis? {
        guard !results.isEmpty else { return nil }
        let n = Double(results.count)
        return Analysis(accuracy: results.reduce(0) { $0 + $1.accuracy } / n,
                        reaction: results.reduce(0) { $0 + $1.averageReaction } / n,
                        rhythm: results.reduce(0) { $0 + $1.rhythm } / n,
                        stability: results.reduce(0) { $0 + $1.stability } / n,
                        combo: results.reduce(0) { $0 + Double($1.combo) } / n)
    }
}

// MARK: - Challenges

struct ChallengePicker {
    /// Stable day key, e.g. 20260730.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2000) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    static func weekKey(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return (c.yearForWeekOfYear ?? 2000) * 100 + (c.weekOfYear ?? 1)
    }

    /// A deterministic non-negative hash of an integer key.
    static func mix(_ key: Int) -> Int {
        var x = UInt64(bitPattern: Int64(key)) &* 0x9E3779B97F4A7C15
        x ^= x >> 29; x = x &* 0xBF58476D1CE4E5B9
        x ^= x >> 32
        return Int(x % 1_000_000_007)
    }

    /// daily = hash(date) % trainingCount
    static func dailyIndex(date: Date, count: Int, calendar: Calendar = .current) -> Int {
        guard count > 0 else { return 0 }
        return mix(dayKey(date, calendar: calendar)) % count
    }

    /// weekly = seven different trainings in a row
    static func weeklyIndices(date: Date, count: Int, calendar: Calendar = .current) -> [Int] {
        guard count > 0 else { return [] }
        let base = mix(weekKey(date, calendar: calendar))
        var picked: [Int] = []
        var step = 0
        while picked.count < min(7, count) && step < 200 {
            let idx = mix(base &+ step &* 7919) % count
            if !picked.contains(idx) { picked.append(idx) }
            step += 1
        }
        return picked
    }
}
