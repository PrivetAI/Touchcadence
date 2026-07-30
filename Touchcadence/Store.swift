import Foundation
import SwiftUI

/// Central MVVM store: SQLite for content and history, UserDefaults for preferences.
@MainActor
final class TrainingStore: ObservableObject {

    // MARK: - Published state

    @Published private(set) var trainings: [Training] = []
    @Published private(set) var results: [SessionResult] = []
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var favorites: Set<UUID> = []
    @Published private(set) var programs: [PersonalProgram] = []
    @Published private(set) var bestScores: [UUID: Int] = [:]
    @Published private(set) var bestRanks: [UUID: Rank] = [:]
    @Published private(set) var profile: PlayerProfile = .starter
    @Published private(set) var weeklyStages: Set<Int> = []
    @Published private(set) var dailyDone: Bool = false
    @Published private(set) var ready = false
    @Published private(set) var storageNote: String = ""

    @Published var settings: AppSettings = SettingsStore.load() {
        didSet { if settings != oldValue { SettingsStore.save(settings) } }
    }

    let motion: MotionEngine
    private let palettes: [Theme: Palette]
    private var db: SQLiteDatabase?

    // MARK: - Init

    init() {
        let params = Catalog.movementParameters()
        motion = params.isEmpty ? .fallback : MotionEngine(parameters: params)
        palettes = Palette.map(from: Catalog.palettes())
    }

    var palette: Palette { palettes[settings.theme] ?? Palette.builtInDark }

    func palette(for theme: Theme) -> Palette { palettes[theme] ?? Palette.builtInDark }

    // MARK: - Bootstrap

    func bootstrap() async {
        guard !ready else { return }
        let builtIn = Catalog.builtInTrainings()
        do {
            let path = TrainingStore.databasePath()
            let database = try SQLiteDatabase(path: path)
            try TrainingStore.createSchema(database)
            try TrainingStore.seed(database, trainings: builtIn)
            db = database
            reloadAll()
            storageNote = "SQLite at \(URL(fileURLWithPath: path).lastPathComponent)"
        } catch {
            // Fall back to the bundled catalogue in memory so the app remains usable.
            db = nil
            trainings = builtIn
            achievements = AchievementCatalog.all.map {
                Achievement(id: UUID(), key: $0.key, name: $0.name, detail: $0.detail,
                            unlocked: false, unlockedAt: nil)
            }
            storageNote = "In-memory fallback: \(error.localizedDescription)"
        }
        ready = true
    }

    private static func databasePath() -> String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("touchcadence.sqlite").path
    }

    // MARK: - Schema

    private static func createSchema(_ db: SQLiteDatabase) throws {
        try db.execute("""
        CREATE TABLE IF NOT EXISTS trainings (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL,
          difficulty TEXT NOT NULL, duration INTEGER NOT NULL, movement TEXT NOT NULL,
          target_size TEXT NOT NULL, is_custom INTEGER NOT NULL DEFAULT 0,
          sort_index INTEGER NOT NULL DEFAULT 0, note TEXT);

        CREATE TABLE IF NOT EXISTS results (
          id TEXT PRIMARY KEY, training_id TEXT NOT NULL, training_name TEXT NOT NULL,
          score INTEGER NOT NULL, accuracy REAL NOT NULL, avg_reaction REAL NOT NULL,
          combo INTEGER NOT NULL, stability REAL NOT NULL, rhythm REAL NOT NULL,
          rank TEXT NOT NULL, played_at REAL NOT NULL);
        CREATE INDEX IF NOT EXISTS results_played_at ON results(played_at DESC);

        CREATE TABLE IF NOT EXISTS medals (
          training_id TEXT PRIMARY KEY, best_score INTEGER NOT NULL, best_rank TEXT NOT NULL);

        CREATE TABLE IF NOT EXISTS achievements (
          key TEXT PRIMARY KEY, id TEXT NOT NULL, name TEXT NOT NULL, detail TEXT NOT NULL,
          unlocked INTEGER NOT NULL DEFAULT 0, unlocked_at REAL, sort_index INTEGER NOT NULL DEFAULT 0);

        CREATE TABLE IF NOT EXISTS favorites (training_id TEXT PRIMARY KEY);

        CREATE TABLE IF NOT EXISTS programs (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, created REAL NOT NULL);

        CREATE TABLE IF NOT EXISTS program_items (
          program_id TEXT NOT NULL, training_id TEXT NOT NULL, position INTEGER NOT NULL,
          PRIMARY KEY (program_id, position));

        CREATE TABLE IF NOT EXISTS profile (
          id INTEGER PRIMARY KEY, level INTEGER NOT NULL, experience INTEGER NOT NULL,
          best_rank TEXT NOT NULL, total_sessions INTEGER NOT NULL, total_score INTEGER NOT NULL);

        CREATE TABLE IF NOT EXISTS weekly_progress (
          week_key INTEGER NOT NULL, stage INTEGER NOT NULL, PRIMARY KEY (week_key, stage));

        CREATE TABLE IF NOT EXISTS daily_progress (day_key INTEGER PRIMARY KEY);
        """)
    }

    private static func seed(_ db: SQLiteDatabase, trainings: [Training]) throws {
        // Older databases predate the note column; adding it again fails harmlessly.
        db.perform("ALTER TABLE trainings ADD COLUMN note TEXT;")

        let existing = try db.query("SELECT COUNT(*) AS c FROM trainings WHERE is_custom = 0;")
        let count = existing.first?.int("c") ?? 0
        if count != trainings.count {
            try db.run("DELETE FROM trainings WHERE is_custom = 0;")
            for (index, t) in trainings.enumerated() {
                try db.run("""
                INSERT OR REPLACE INTO trainings
                (id, name, category, difficulty, duration, movement, target_size, is_custom, sort_index)
                VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?);
                """, [.text(t.id.uuidString), .text(t.name), .text(t.category.rawValue),
                      .text(t.difficulty.rawValue), .int(t.duration), .text(t.movement.rawValue),
                      .text(t.targetSize.rawValue), .int(index)])
            }
        }

        let ach = try db.query("SELECT COUNT(*) AS c FROM achievements;")
        if (ach.first?.int("c") ?? 0) != AchievementCatalog.all.count {
            for (index, d) in AchievementCatalog.all.enumerated() {
                try db.run("""
                INSERT OR IGNORE INTO achievements (key, id, name, detail, unlocked, unlocked_at, sort_index)
                VALUES (?, ?, ?, ?, 0, NULL, ?);
                """, [.text(d.key), .text(UUID().uuidString), .text(d.name), .text(d.detail), .int(index)])
            }
        }

        let prof = try db.query("SELECT COUNT(*) AS c FROM profile WHERE id = 1;")
        if (prof.first?.int("c") ?? 0) == 0 {
            try db.run("""
            INSERT INTO profile (id, level, experience, best_rank, total_sessions, total_score)
            VALUES (1, 1, 0, 'd', 0, 0);
            """)
        }
    }

    // MARK: - Loading

    private func reloadAll() {
        loadTrainings()
        loadResults()
        loadAchievements()
        loadFavorites()
        loadPrograms()
        loadMedals()
        loadProfile()
        loadChallengeProgress()
    }

    private func loadTrainings() {
        guard let db else { return }
        let rows = (try? db.query("SELECT * FROM trainings ORDER BY is_custom ASC, sort_index ASC;")) ?? []
        trainings = rows.compactMap { row in
            guard let id = row.uuid("id"), let name = row.string("name"),
                  let cat = row.string("category").flatMap(TrainingCategory.init(rawValue:)),
                  let diff = row.string("difficulty").flatMap(Difficulty.init(rawValue:)),
                  let mov = row.string("movement").flatMap(MovementType.init(rawValue:)),
                  let size = row.string("target_size").flatMap(TargetSize.init(rawValue:)),
                  let duration = row.int("duration") else { return nil }
            return Training(id: id, name: name, category: cat, difficulty: diff, duration: duration,
                            movement: mov, targetSize: size, isCustom: row.bool("is_custom") ?? false,
                            note: row.string("note"))
        }
    }

    private func loadResults() {
        guard let db else { return }
        let rows = (try? db.query("SELECT * FROM results ORDER BY played_at DESC LIMIT 500;")) ?? []
        results = rows.compactMap { row in
            guard let id = row.uuid("id"), let tid = row.uuid("training_id"),
                  let name = row.string("training_name"),
                  let rank = row.string("rank").flatMap(Rank.init(rawValue:)),
                  let score = row.int("score"), let played = row.double("played_at") else { return nil }
            return SessionResult(id: id, trainingID: tid, trainingName: name, score: score,
                                 accuracy: row.double("accuracy") ?? 0,
                                 averageReaction: row.double("avg_reaction") ?? 0,
                                 combo: row.int("combo") ?? 0,
                                 stability: row.double("stability") ?? 0,
                                 rhythm: row.double("rhythm") ?? 0,
                                 rank: rank,
                                 date: Date(timeIntervalSince1970: played))
        }
    }

    private func loadAchievements() {
        guard let db else { return }
        let rows = (try? db.query("SELECT * FROM achievements ORDER BY sort_index ASC;")) ?? []
        achievements = rows.compactMap { row in
            guard let key = row.string("key"), let name = row.string("name"),
                  let detail = row.string("detail") else { return nil }
            return Achievement(id: row.uuid("id") ?? UUID(), key: key, name: name, detail: detail,
                               unlocked: row.bool("unlocked") ?? false,
                               unlockedAt: row.double("unlocked_at").map { Date(timeIntervalSince1970: $0) })
        }
    }

    private func loadFavorites() {
        guard let db else { return }
        let rows = (try? db.query("SELECT training_id FROM favorites;")) ?? []
        favorites = Set(rows.compactMap { $0.uuid("training_id") })
    }

    private func loadPrograms() {
        guard let db else { return }
        let rows = (try? db.query("SELECT * FROM programs ORDER BY created DESC;")) ?? []
        programs = rows.compactMap { row in
            guard let id = row.uuid("id"), let name = row.string("name") else { return nil }
            let items = (try? db.query("SELECT training_id FROM program_items WHERE program_id = ? ORDER BY position ASC;",
                                       [.text(id.uuidString)])) ?? []
            return PersonalProgram(id: id, name: name,
                                   trainingIDs: items.compactMap { $0.uuid("training_id") },
                                   created: Date(timeIntervalSince1970: row.double("created") ?? 0))
        }
    }

    private func loadMedals() {
        guard let db else { return }
        let rows = (try? db.query("SELECT * FROM medals;")) ?? []
        var scores: [UUID: Int] = [:]
        var ranks: [UUID: Rank] = [:]
        for row in rows {
            guard let id = row.uuid("training_id") else { continue }
            scores[id] = row.int("best_score") ?? 0
            ranks[id] = row.string("best_rank").flatMap(Rank.init(rawValue:)) ?? .d
        }
        bestScores = scores
        bestRanks = ranks
    }

    private func loadProfile() {
        guard let db else { return }
        let rows = (try? db.query("SELECT * FROM profile WHERE id = 1;")) ?? []
        guard let row = rows.first else { return }
        profile = PlayerProfile(level: row.int("level") ?? 1,
                                experience: row.int("experience") ?? 0,
                                bestRank: row.string("best_rank").flatMap(Rank.init(rawValue:)) ?? .d,
                                totalSessions: row.int("total_sessions") ?? 0,
                                totalScore: row.int("total_score") ?? 0)
    }

    private func loadChallengeProgress() {
        guard let db else { return }
        let week = ChallengePicker.weekKey(Date())
        let rows = (try? db.query("SELECT stage FROM weekly_progress WHERE week_key = ?;", [.int(week)])) ?? []
        weeklyStages = Set(rows.compactMap { $0.int("stage") })
        let day = ChallengePicker.dayKey(Date())
        let d = (try? db.query("SELECT COUNT(*) AS c FROM daily_progress WHERE day_key = ?;", [.int(day)])) ?? []
        dailyDone = (d.first?.int("c") ?? 0) > 0
    }

    // MARK: - Writes

    /// Persists a finished session and rolls every derived record.
    func save(result: SessionResult, training: Training, challenge: ChallengeTag? = nil) {
        results.insert(result, at: 0)
        if results.count > 500 { results.removeLast(results.count - 500) }

        let previousBest = bestScores[training.id] ?? 0
        if result.score > previousBest {
            bestScores[training.id] = result.score
            bestRanks[training.id] = result.rank
        } else if (bestRanks[training.id]?.order ?? 0) < result.rank.order {
            bestRanks[training.id] = result.rank
        }

        profile.totalSessions += 1
        profile.totalScore += result.score
        if result.rank > profile.bestRank { profile.bestRank = result.rank }
        profile.gain(experience: result.score / 20)

        // A challenge stage only counts when the run actually scored.
        let challenge = result.score > 0 ? challenge : nil
        if let challenge {
            switch challenge {
            case .daily: dailyDone = true
            case .weekly(let stage): weeklyStages.insert(stage)
            }
        }

        if let db {
            db.perform("""
            INSERT OR REPLACE INTO results
            (id, training_id, training_name, score, accuracy, avg_reaction, combo, stability, rhythm, rank, played_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """, [.text(result.id.uuidString), .text(result.trainingID.uuidString),
                  .text(result.trainingName), .int(result.score), .double(result.accuracy),
                  .double(result.averageReaction), .int(result.combo), .double(result.stability),
                  .double(result.rhythm), .text(result.rank.rawValue),
                  .double(result.date.timeIntervalSince1970)])

            let best = bestScores[training.id] ?? result.score
            let rank = bestRanks[training.id] ?? result.rank
            db.perform("""
            INSERT OR REPLACE INTO medals (training_id, best_score, best_rank) VALUES (?, ?, ?);
            """, [.text(training.id.uuidString), .int(best), .text(rank.rawValue)])

            db.perform("""
            INSERT OR REPLACE INTO profile (id, level, experience, best_rank, total_sessions, total_score)
            VALUES (1, ?, ?, ?, ?, ?);
            """, [.int(profile.level), .int(profile.experience), .text(profile.bestRank.rawValue),
                  .int(profile.totalSessions), .int(profile.totalScore)])

            if let challenge {
                switch challenge {
                case .daily:
                    db.perform("INSERT OR IGNORE INTO daily_progress (day_key) VALUES (?);",
                                [.int(ChallengePicker.dayKey(Date()))])
                case .weekly(let stage):
                    db.perform("INSERT OR IGNORE INTO weekly_progress (week_key, stage) VALUES (?, ?);",
                                [.int(ChallengePicker.weekKey(Date())), .int(stage)])
                }
            }
        }

        evaluateAchievements(latest: result, training: training, challenge: challenge)
    }

    func toggleFavorite(_ training: Training) {
        if favorites.contains(training.id) {
            favorites.remove(training.id)
            db?.perform("DELETE FROM favorites WHERE training_id = ?;", [.text(training.id.uuidString)])
        } else {
            favorites.insert(training.id)
            db?.perform("INSERT OR IGNORE INTO favorites (training_id) VALUES (?);",
                         [.text(training.id.uuidString)])
        }
    }

    func addCustom(_ training: Training) {
        var t = training
        t.isCustom = true
        trainings.append(t)
        let noteValue: SQLiteDatabase.Value = t.note.map { .text($0) } ?? .null
        db?.perform("""
        INSERT OR REPLACE INTO trainings
        (id, name, category, difficulty, duration, movement, target_size, is_custom, sort_index, note)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?);
        """, [.text(t.id.uuidString), .text(t.name), .text(t.category.rawValue),
              .text(t.difficulty.rawValue), .int(t.duration), .text(t.movement.rawValue),
              .text(t.targetSize.rawValue), .int(trainings.count), noteValue])
        unlock("custom_made")
    }

    func deleteCustom(_ training: Training) {
        trainings.removeAll { $0.id == training.id && $0.isCustom }
        db?.perform("DELETE FROM trainings WHERE id = ? AND is_custom = 1;", [.text(training.id.uuidString)])
    }

    func addProgram(name: String, trainingIDs: [UUID]) {
        let program = PersonalProgram(id: UUID(), name: name, trainingIDs: trainingIDs, created: Date())
        programs.insert(program, at: 0)
        db?.perform("INSERT OR REPLACE INTO programs (id, name, created) VALUES (?, ?, ?);",
                     [.text(program.id.uuidString), .text(name),
                      .double(program.created.timeIntervalSince1970)])
        for (index, id) in trainingIDs.enumerated() {
            db?.perform("INSERT OR REPLACE INTO program_items (program_id, training_id, position) VALUES (?, ?, ?);",
                         [.text(program.id.uuidString), .text(id.uuidString), .int(index)])
        }
        unlock("program_made")
    }

    func deleteProgram(_ program: PersonalProgram) {
        programs.removeAll { $0.id == program.id }
        db?.perform("DELETE FROM program_items WHERE program_id = ?;", [.text(program.id.uuidString)])
        db?.perform("DELETE FROM programs WHERE id = ?;", [.text(program.id.uuidString)])
    }

    func resetHistory() {
        results = []
        bestScores = [:]
        bestRanks = [:]
        weeklyStages = []
        dailyDone = false
        profile = .starter
        achievements = achievements.map {
            Achievement(id: $0.id, key: $0.key, name: $0.name, detail: $0.detail,
                        unlocked: false, unlockedAt: nil)
        }
        db?.perform("DELETE FROM results;")
        db?.perform("DELETE FROM medals;")
        db?.perform("DELETE FROM weekly_progress;")
        db?.perform("DELETE FROM daily_progress;")
        db?.perform("UPDATE achievements SET unlocked = 0, unlocked_at = NULL;")
        db?.perform("""
        INSERT OR REPLACE INTO profile (id, level, experience, best_rank, total_sessions, total_score)
        VALUES (1, 1, 0, 'd', 0, 0);
        """)
    }

    // MARK: - Achievements

    private func unlock(_ key: String) {
        guard let index = achievements.firstIndex(where: { $0.key == key }), !achievements[index].unlocked
        else { return }
        achievements[index].unlocked = true
        achievements[index].unlockedAt = Date()
        db?.perform("UPDATE achievements SET unlocked = 1, unlocked_at = ? WHERE key = ?;",
                     [.double(Date().timeIntervalSince1970), .text(key)])
    }

    private func evaluateAchievements(latest: SessionResult, training: Training, challenge: ChallengeTag?) {
        unlock("first_session")
        if profile.totalSessions >= 10 { unlock("sessions_10") }
        if profile.totalSessions >= 50 { unlock("sessions_50") }
        if latest.combo >= 25 { unlock("combo_25") }
        if latest.combo >= 60 { unlock("combo_60") }
        if latest.accuracy >= 0.9 { unlock("accuracy_90") }
        if latest.accuracy >= 0.999 && latest.combo > 0 { unlock("accuracy_100") }
        if latest.averageReaction > 0 && latest.averageReaction < 0.40 { unlock("reaction_400") }
        if latest.rank >= .a { unlock("rank_a") }
        if latest.rank >= .s { unlock("rank_s") }
        if latest.rank == .sss { unlock("rank_sss") }
        if profile.level >= 5 { unlock("level_5") }
        if profile.level >= 10 { unlock("level_10") }
        if latest.score >= 5000 { unlock("score_5000") }
        if latest.stability >= 90 { unlock("stability_90") }
        if training.difficulty == .impossible && latest.score > 0 { unlock("impossible_clear") }
        if challenge == .daily { unlock("daily_done") }
        if weeklyStages.count >= 7 { unlock("weekly_done") }

        let playedIDs = Set(results.map { $0.trainingID })
        let played = trainings.filter { playedIDs.contains($0.id) }
        if Set(played.map { $0.category }).count >= TrainingCategory.allCases.count { unlock("all_categories") }
        if Set(played.map { $0.movement }).count >= 10 { unlock("movements_10") }
    }

    // MARK: - Derived views

    func training(id: UUID) -> Training? { trainings.first { $0.id == id } }

    var builtIn: [Training] { trainings.filter { !$0.isCustom } }

    var customTrainings: [Training] { trainings.filter { $0.isCustom } }

    var favoriteTrainings: [Training] { trainings.filter { favorites.contains($0.id) } }

    var dailyTraining: Training? {
        let pool = builtIn
        guard !pool.isEmpty else { return nil }
        return pool[ChallengePicker.dailyIndex(date: Date(), count: pool.count)]
    }

    var weeklyTrainings: [Training] {
        let pool = builtIn
        guard !pool.isEmpty else { return [] }
        return ChallengePicker.weeklyIndices(date: Date(), count: pool.count).map { pool[$0] }
    }

    var analysis: Analysis? { Analysis.from(results: Array(results.prefix(20))) }

    /// Recommended trainings for the weakest measure.
    var recommendations: [Training] {
        let measure = analysis?.weakest ?? .accuracy
        let level = min(Difficulty.allCases.count - 1, max(0, profile.level / 2))
        let target = Difficulty.allCases[level]
        let pool = builtIn.filter { $0.category == measure.category }
        let matched = pool.filter { $0.difficulty == target }
        return Array((matched.isEmpty ? pool : matched).prefix(4))
    }

    func recentResults(for training: Training) -> [SessionResult] {
        results.filter { $0.trainingID == training.id }
    }

    var totalTrainingSeconds: Int {
        results.reduce(0) { sum, r in
            sum + (training(id: r.trainingID)?.duration ?? 45)
        }
    }
}

/// Tags a session as part of a challenge so progress can be recorded.
enum ChallengeTag: Equatable {
    case daily
    case weekly(stage: Int)
}

// MARK: - UserDefaults preferences

struct SettingsStore {
    private static let key = "touchcadence.settings.v1"
    private static let screenKey = "touchcadence.lastScreen.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .standard
        }
        return decoded
    }

    static func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static var lastScreen: Int {
        get { UserDefaults.standard.integer(forKey: screenKey) }
        set { UserDefaults.standard.set(newValue, forKey: screenKey) }
    }
}
