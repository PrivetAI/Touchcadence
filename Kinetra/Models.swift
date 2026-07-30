import Foundation

// MARK: - Difficulty

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case beginner, easy, normal, advanced, expert, master, impossible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        case .master: return "Master"
        case .impossible: return "Impossible"
        }
    }

    /// Ordered index, 0 for the easiest level.
    var order: Int { Difficulty.allCases.firstIndex(of: self) ?? 0 }

    /// Multiplier applied to the base target radius. Strictly decreasing.
    var sizeMultiplier: Double {
        switch self {
        case .beginner: return 1.30
        case .easy: return 1.15
        case .normal: return 1.00
        case .advanced: return 0.88
        case .expert: return 0.76
        case .master: return 0.66
        case .impossible: return 0.56
        }
    }

    /// Multiplier applied to the trajectory speed. Strictly increasing.
    var speedMultiplier: Double {
        switch self {
        case .beginner: return 0.60
        case .easy: return 0.80
        case .normal: return 1.00
        case .advanced: return 1.25
        case .expert: return 1.55
        case .master: return 1.90
        case .impossible: return 2.30
        }
    }

    /// Score weight used by the point formula.
    var factor: Double {
        switch self {
        case .beginner: return 0.80
        case .easy: return 0.95
        case .normal: return 1.15
        case .advanced: return 1.40
        case .expert: return 1.70
        case .master: return 2.10
        case .impossible: return 2.60
        }
    }

    /// Seconds a single target stays alive before it counts as a miss. Strictly decreasing.
    var targetLifetime: Double {
        switch self {
        case .beginner: return 2.60
        case .easy: return 2.30
        case .normal: return 2.00
        case .advanced: return 1.75
        case .expert: return 1.50
        case .master: return 1.25
        case .impossible: return 1.00
        }
    }
}

// MARK: - Movement

enum MovementType: String, Codable, CaseIterable, Identifiable {
    case linear, circle, sine, zigzag, random, accelerate, decelerate, dash
    case pendulum, spiral, ellipse, eight, teleport, reverse, combined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .linear: return "Linear"
        case .circle: return "Circle"
        case .sine: return "Sine Wave"
        case .zigzag: return "Zigzag"
        case .random: return "Random Drift"
        case .accelerate: return "Accelerating"
        case .decelerate: return "Decelerating"
        case .dash: return "Dash"
        case .pendulum: return "Pendulum"
        case .spiral: return "Spiral"
        case .ellipse: return "Ellipse"
        case .eight: return "Figure Eight"
        case .teleport: return "Teleport"
        case .reverse: return "Reversing"
        case .combined: return "Combined"
        }
    }

    var summary: String {
        switch self {
        case .linear: return "Straight sweeps at a constant pace."
        case .circle: return "A steady orbit around the field center."
        case .sine: return "Horizontal travel with a vertical wave."
        case .zigzag: return "Sharp vertical turns at every crest."
        case .random: return "Unpredictable waypoints, smoothly joined."
        case .accelerate: return "Slow entry, fast exit on every pass."
        case .decelerate: return "Fast entry that settles into a crawl."
        case .dash: return "Bursts of motion split by short holds."
        case .pendulum: return "A swinging arc that slows at the edges."
        case .spiral: return "An outward spiral from the center."
        case .ellipse: return "A wide, flattened orbit."
        case .eight: return "A crossing figure-eight loop."
        case .teleport: return "Instant relocation on a fixed beat."
        case .reverse: return "An orbit that flips direction without warning."
        case .combined: return "Several trajectories chained together."
        }
    }
}

// MARK: - Category

enum TrainingCategory: String, Codable, CaseIterable, Identifiable {
    case speed, reaction, precision, rhythm, control, trajectory, endurance, combined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speed: return "Speed"
        case .reaction: return "Reaction"
        case .precision: return "Precision"
        case .rhythm: return "Rhythm"
        case .control: return "Control"
        case .trajectory: return "Trajectory"
        case .endurance: return "Endurance"
        case .combined: return "Combined"
        }
    }

    var summary: String {
        switch self {
        case .speed: return "Short targets, high turnover."
        case .reaction: return "Answer the moment the target lands."
        case .precision: return "Small targets, no room for slips."
        case .rhythm: return "Keep an even beat between hits."
        case .control: return "Follow long, sustained motion."
        case .trajectory: return "Read the path before you commit."
        case .endurance: return "Long sets that punish fading focus."
        case .combined: return "Every measure at once."
        }
    }
}

// MARK: - Rank

enum Rank: String, Codable, CaseIterable, Comparable, Identifiable {
    case d, c, b, a, s, ss, sss

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var order: Int { Rank.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.order < rhs.order }
}

// MARK: - Theme

enum Theme: String, Codable, CaseIterable, Identifiable {
    case dark, light, neon, cyber, minimal, retro, amoled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .neon: return "Neon"
        case .cyber: return "Cyber"
        case .minimal: return "Minimal"
        case .retro: return "Retro"
        case .amoled: return "AMOLED"
        }
    }
}

// MARK: - Target size

enum TargetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large, huge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .huge: return "Extra Large"
        }
    }

    /// Base radius in points before difficulty scaling.
    var baseRadius: Double {
        switch self {
        case .small: return 22
        case .medium: return 30
        case .large: return 38
        case .huge: return 46
        }
    }
}

// MARK: - Training

struct Training: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var category: TrainingCategory
    var difficulty: Difficulty
    /// Duration in seconds.
    var duration: Int
    var movement: MovementType
    var targetSize: TargetSize
    var isCustom: Bool
    /// Free-text reminder the player attaches to their own trainings.
    var note: String?

    init(id: UUID = UUID(),
         name: String,
         category: TrainingCategory,
         difficulty: Difficulty,
         duration: Int,
         movement: MovementType,
         targetSize: TargetSize = .medium,
         isCustom: Bool = false,
         note: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.duration = duration
        self.movement = movement
        self.targetSize = targetSize
        self.isCustom = isCustom
        self.note = note
    }

    /// Parameter tuple used for the uniqueness check.
    var signature: String {
        "\(category.rawValue)|\(movement.rawValue)|\(difficulty.rawValue)|\(duration)|\(targetSize.rawValue)"
    }

    /// Effective radius in points for this training.
    var targetRadius: Double { targetSize.baseRadius * difficulty.sizeMultiplier }
}

// MARK: - Session result

struct SessionResult: Codable, Identifiable, Hashable {
    var id: UUID
    var trainingID: UUID
    var trainingName: String
    var score: Int
    var accuracy: Double
    var averageReaction: Double
    var combo: Int
    var stability: Double
    var rhythm: Double
    var rank: Rank
    var date: Date

    init(id: UUID = UUID(),
         trainingID: UUID,
         trainingName: String,
         score: Int,
         accuracy: Double,
         averageReaction: Double,
         combo: Int,
         stability: Double,
         rhythm: Double,
         rank: Rank,
         date: Date = Date()) {
        self.id = id
        self.trainingID = trainingID
        self.trainingName = trainingName
        self.score = score
        self.accuracy = accuracy
        self.averageReaction = averageReaction
        self.combo = combo
        self.stability = stability
        self.rhythm = rhythm
        self.rank = rank
        self.date = date
    }
}

// MARK: - Player profile

struct PlayerProfile: Codable, Equatable {
    var level: Int
    var experience: Int
    var bestRank: Rank
    var totalSessions: Int
    var totalScore: Int

    static let starter = PlayerProfile(level: 1, experience: 0, bestRank: .d, totalSessions: 0, totalScore: 0)

    /// Experience needed to reach the next level.
    static func threshold(for level: Int) -> Int { 200 + (level - 1) * 120 }

    var nextThreshold: Int { PlayerProfile.threshold(for: level) }

    var progress: Double {
        let t = Double(nextThreshold)
        guard t > 0 else { return 0 }
        return min(1, max(0, Double(experience) / t))
    }

    /// Adds experience and rolls levels while the threshold is met.
    mutating func gain(experience amount: Int) {
        experience += max(0, amount)
        while experience >= PlayerProfile.threshold(for: level) {
            experience -= PlayerProfile.threshold(for: level)
            level += 1
        }
    }
}

// MARK: - Achievement

struct Achievement: Codable, Identifiable, Hashable {
    var id: UUID
    var key: String
    var name: String
    var detail: String
    var unlocked: Bool
    var unlockedAt: Date?
}

// MARK: - Settings

struct AppSettings: Codable, Equatable {
    var theme: Theme
    var targetSize: TargetSize
    var speed: Double
    var vibration: Bool
    var sound: Bool

    static let standard = AppSettings(theme: .dark, targetSize: .medium, speed: 1.0, vibration: true, sound: true)
}

// MARK: - Personal program

struct PersonalProgram: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var trainingIDs: [UUID]
    var created: Date
}
