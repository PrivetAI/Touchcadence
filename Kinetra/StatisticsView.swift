import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    var body: some View {
        ScreenScaffold(title: "Statistics", subtitle: "\(store.results.count) stored sessions") {
            Card {
                HStack(spacing: Metrics.spaceM) {
                    RingGauge(value: store.analysis?.accuracy ?? 0, caption: "accuracy",
                              tint: palette.success, diameter: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rolling form").font(.kHeadline).foregroundColor(palette.text)
                        Text(store.results.isEmpty
                             ? "Finish a session to start the record."
                             : "Averaged over your last \(min(20, store.results.count)) sessions.")
                            .font(.kCaption).foregroundColor(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "SESSIONS", value: "\(store.profile.totalSessions)")
                    StatTile(label: "BEST RANK", value: store.profile.bestRank.title, tint: palette.accent)
                    StatTile(label: "LEVEL", value: "\(store.profile.level)", tint: palette.primary)
                }
            }

            NavigationLink { HistoryView() } label: {
                NavRow(glyph: .clock, title: "History", detail: "\(store.results.count) sessions on record")
            }
            .buttonStyle(.plain)

            NavigationLink { ChartsView() } label: {
                NavRow(glyph: .stats, title: "Charts", detail: "Score, accuracy and reaction curves",
                       tint: palette.accent)
            }
            .buttonStyle(.plain)

            NavigationLink { AnalysisView() } label: {
                NavRow(glyph: .gauge, title: "Analysis", detail: "Where your weakest measure is",
                       tint: palette.warning)
            }
            .buttonStyle(.plain)

            NavigationLink { AchievementsView() } label: {
                NavRow(glyph: .medal, title: "Achievements",
                       detail: "\(store.achievements.filter { $0.unlocked }.count) of \(store.achievements.count) unlocked",
                       tint: palette.success)
            }
            .buttonStyle(.plain)

            if store.results.count > 1 {
                SectionTitle(text: "Recent Scores")
                Card {
                    LineChartCanvas(values: store.results.prefix(20).reversed().map { Double($0.score) })
                }
            } else {
                EmptyNote(text: "Charts fill in once you have a couple of finished sessions.")
            }
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var rankFilter: Rank? = nil

    private var shown: [SessionResult] {
        guard let rankFilter else { return store.results }
        return store.results.filter { $0.rank == rankFilter }
    }

    var body: some View {
        ScreenScaffold(title: "History", subtitle: "\(shown.count) sessions", back: true) {
            HStack(spacing: 6) {
                ForEach(Rank.allCases) { rank in
                    Button {
                        rankFilter = rankFilter == rank ? nil : rank
                    } label: {
                        Text(rank.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(rankFilter == rank ? (palette.isDark ? .black : .white)
                                             : palette.rankColor(rank))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                                .fill(rankFilter == rank ? palette.rankColor(rank) : palette.elevated))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if shown.isEmpty {
                EmptyNote(text: store.results.isEmpty
                          ? "No sessions recorded yet. Every finished run lands here."
                          : "No session with that rank yet.")
            }

            ForEach(shown) { result in
                ResultRow(result: result, showName: true)
            }
        }
    }
}

// MARK: - Charts

struct ChartsView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    private var recent: [SessionResult] { Array(store.results.prefix(20).reversed()) }

    var body: some View {
        ScreenScaffold(title: "Charts", subtitle: "Drawn by hand, no charting framework", back: true) {
            if recent.count < 2 {
                EmptyNote(text: "Two finished sessions are enough to draw the first curve.")
            }

            Card {
                SectionTitle(text: "Score", trailing: "last \(recent.count)")
                LineChartCanvas(values: recent.map { Double($0.score) }, tint: palette.primary)
            }

            Card {
                SectionTitle(text: "Accuracy", trailing: "percent")
                LineChartCanvas(values: recent.map { $0.accuracy * 100 }, tint: palette.success,
                                valueLabel: { "\(Int($0.rounded()))%" })
            }

            Card {
                SectionTitle(text: "Average Reaction", trailing: "milliseconds")
                LineChartCanvas(values: recent.map { $0.averageReaction * 1000 }, tint: palette.accent,
                                valueLabel: { "\(Int($0.rounded()))ms" })
            }

            Card {
                SectionTitle(text: "Sessions by Category")
                BarChartCanvas(items: TrainingCategory.allCases.map { category in
                    (label: shortLabel(category),
                     value: Double(sessionCount(category)),
                     color: palette.categoryColor(category))
                })
            }

            Card {
                SectionTitle(text: "Best Score by Difficulty")
                BarChartCanvas(items: Difficulty.allCases.map { difficulty in
                    (label: String(difficulty.title.prefix(3)),
                     value: bestScore(difficulty),
                     color: palette.primary.opacity(0.4 + Double(difficulty.order) * 0.09))
                })
            }
        }
    }

    private func shortLabel(_ c: TrainingCategory) -> String { String(c.title.prefix(4)) }

    private func sessionCount(_ c: TrainingCategory) -> Int {
        store.results.filter { store.training(id: $0.trainingID)?.category == c }.count
    }

    private func bestScore(_ d: Difficulty) -> Double {
        let scores = store.results.compactMap { r -> Int? in
            store.training(id: r.trainingID)?.difficulty == d ? r.score : nil
        }
        return Double(scores.max() ?? 0)
    }
}

// MARK: - Analysis

struct AnalysisView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    var body: some View {
        ScreenScaffold(title: "Analysis", subtitle: "Your weakest measure decides what to train", back: true) {
            if let analysis = store.analysis {
                Card {
                    SectionTitle(text: "Measure Profile")
                    RadarChartCanvas(axes: [
                        (label: "ACC", value: analysis.scores[.accuracy] ?? 0),
                        (label: "REACT", value: analysis.scores[.reaction] ?? 0),
                        (label: "RHYTHM", value: analysis.scores[.rhythm] ?? 0),
                        (label: "STABIL", value: analysis.scores[.stability] ?? 0),
                        (label: "COMBO", value: analysis.scores[.combo] ?? 0)
                    ], size: 250)
                }

                ForEach(WeakestMeasure.allCases, id: \.self) { measure in
                    Card(padding: Metrics.spaceM) {
                        HStack {
                            Text(measure.title).font(.kBody).foregroundColor(palette.text)
                            Spacer()
                            Text("\(Int(((analysis.scores[measure] ?? 0) * 100).rounded()))")
                                .font(.kBody).foregroundColor(
                                    measure == analysis.weakest ? palette.error : palette.success)
                        }
                        BarMeter(value: analysis.scores[measure] ?? 0,
                                 tint: measure == analysis.weakest ? palette.error : palette.primary)
                        if measure == analysis.weakest {
                            Text(measure.advice).font(.kCaption).foregroundColor(palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Card {
                    SectionTitle(text: "Raw Averages")
                    HStack(spacing: Metrics.spaceS) {
                        StatTile(label: "ACCURACY", value: "\(Int((analysis.accuracy * 100).rounded()))%")
                        StatTile(label: "REACTION", value: String(format: "%.2fs", analysis.reaction))
                    }
                    HStack(spacing: Metrics.spaceS) {
                        StatTile(label: "STABILITY", value: String(format: "%.0f", analysis.stability))
                        StatTile(label: "AVG COMBO", value: String(format: "%.1f", analysis.combo))
                    }
                }

                if !store.recommendations.isEmpty {
                    SectionTitle(text: "Recommended", trailing: analysis.weakest.category.title)
                    ForEach(store.recommendations) { training in
                        NavigationLink { TrainingDetailView(training: training) } label: {
                            TrainingRow(training: training, best: store.bestScores[training.id],
                                        rank: store.bestRanks[training.id],
                                        favorite: store.favorites.contains(training.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                EmptyNote(text: "Finish one session and the analysis will tell you exactly which measure is holding you back.")
            }
        }
    }
}

// MARK: - Achievements

struct AchievementsView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    var body: some View {
        let unlocked = store.achievements.filter { $0.unlocked }.count
        return ScreenScaffold(title: "Achievements", subtitle: "\(unlocked) of \(store.achievements.count) unlocked", back: true) {
            Card {
                HStack(spacing: Metrics.spaceM) {
                    RingGauge(value: store.achievements.isEmpty ? 0
                              : Double(unlocked) / Double(store.achievements.count),
                              caption: "unlocked", tint: palette.success, diameter: 92)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Medals").font(.kHeadline).foregroundColor(palette.text)
                        Text("Unlocked automatically as your sessions qualify. Everything is stored locally.")
                            .font(.kCaption).foregroundColor(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ForEach(store.achievements) { achievement in
                HStack(spacing: Metrics.spaceM) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                            .fill((achievement.unlocked ? palette.success : palette.secondaryText).opacity(0.14))
                        Glyph(kind: achievement.unlocked ? .medal : .lock, size: 22,
                              color: achievement.unlocked ? palette.success : palette.secondaryText)
                    }
                    .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.name).font(.kBody)
                            .foregroundColor(achievement.unlocked ? palette.text : palette.secondaryText)
                        Text(achievement.detail).font(.kCaption).foregroundColor(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if achievement.unlocked {
                        Glyph(kind: .check, size: 18, color: palette.success)
                    }
                }
                .padding(Metrics.spaceM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerMedium).stroke(palette.grid, lineWidth: 1))
            }
        }
    }
}
