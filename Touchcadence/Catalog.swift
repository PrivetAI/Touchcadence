import Foundation

/// Loads the bundled JSON resources: built-in exercises, movement parameters and theme palettes.
struct Catalog {

    struct CatalogFile: Codable {
        var version: Int
        var trainings: [Training]
    }

    struct MovementFile: Codable {
        var version: Int
        var movements: [MotionEngine.MovementParameters]
    }

    struct ThemeFile: Codable {
        var version: Int
        var themes: [PaletteData]
    }

    /// Raw palette record as stored in `themes.json`.
    struct PaletteData: Codable {
        var theme: String
        var dark: Bool
        var background: String
        var surface: String
        var elevated: String
        var text: String
        var secondaryText: String
        var primary: String
        var accent: String
        var success: String
        var warning: String
        var error: String
        var field: String
        var grid: String
    }

    static func loadData(_ name: String, bundle: Bundle = .main) -> Data? {
        if let url = bundle.url(forResource: name, withExtension: "json") {
            return try? Data(contentsOf: url)
        }
        return nil
    }

    static func decodeTrainings(_ data: Data) throws -> [Training] {
        try JSONDecoder().decode(CatalogFile.self, from: data).trainings
    }

    static func decodeMovements(_ data: Data) throws -> [MotionEngine.MovementParameters] {
        try JSONDecoder().decode(MovementFile.self, from: data).movements
    }

    static func decodePalettes(_ data: Data) throws -> [PaletteData] {
        try JSONDecoder().decode(ThemeFile.self, from: data).themes
    }

    static func builtInTrainings(bundle: Bundle = .main) -> [Training] {
        guard let data = loadData("catalog", bundle: bundle),
              let list = try? decodeTrainings(data), !list.isEmpty else { return [] }
        return list
    }

    static func movementParameters(bundle: Bundle = .main) -> [MotionEngine.MovementParameters] {
        guard let data = loadData("movements", bundle: bundle),
              let list = try? decodeMovements(data), !list.isEmpty else { return [] }
        return list
    }

    static func palettes(bundle: Bundle = .main) -> [PaletteData] {
        guard let data = loadData("themes", bundle: bundle),
              let list = try? decodePalettes(data), !list.isEmpty else { return [] }
        return list
    }
}

/// Definitions for the achievement set. Seeded into SQLite on first launch.
struct AchievementCatalog {
    struct Definition {
        let key: String
        let name: String
        let detail: String
    }

    static let all: [Definition] = [
        .init(key: "first_session", name: "First Contact", detail: "Finish one training session."),
        .init(key: "sessions_10", name: "Ten Down", detail: "Finish ten training sessions."),
        .init(key: "sessions_50", name: "Regular", detail: "Finish fifty training sessions."),
        .init(key: "combo_25", name: "Unbroken", detail: "Reach a combo of 25 in one session."),
        .init(key: "combo_60", name: "Chain Master", detail: "Reach a combo of 60 in one session."),
        .init(key: "accuracy_90", name: "Clean Hands", detail: "Finish a session at 90% accuracy."),
        .init(key: "accuracy_100", name: "Flawless", detail: "Finish a session without a single miss."),
        .init(key: "reaction_400", name: "Quick Draw", detail: "Average under 0.40s reaction in a session."),
        .init(key: "rank_a", name: "Rank A", detail: "Earn an A rank."),
        .init(key: "rank_s", name: "Rank S", detail: "Earn an S rank."),
        .init(key: "rank_sss", name: "Rank SSS", detail: "Earn the top SSS rank."),
        .init(key: "level_5", name: "Level Five", detail: "Reach player level 5."),
        .init(key: "level_10", name: "Level Ten", detail: "Reach player level 10."),
        .init(key: "score_5000", name: "Five Thousand", detail: "Score 5,000 in a single session."),
        .init(key: "stability_90", name: "Metronome", detail: "Finish a session with stability above 90."),
        .init(key: "all_categories", name: "Generalist", detail: "Train in all eight categories."),
        .init(key: "movements_10", name: "Path Reader", detail: "Clear sessions on ten movement types."),
        .init(key: "daily_done", name: "Daily Habit", detail: "Complete a daily challenge."),
        .init(key: "weekly_done", name: "Weekly Run", detail: "Complete every stage of a weekly challenge."),
        .init(key: "custom_made", name: "Own Design", detail: "Create a custom training."),
        .init(key: "impossible_clear", name: "No Limit", detail: "Finish an Impossible difficulty training."),
        .init(key: "program_made", name: "Programmer", detail: "Build a personal program.")
    ]
}
