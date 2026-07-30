import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var activeSession: Training?

    var body: some View {
        ScreenScaffold(title: "Kinetra", subtitle: "Offline precision trainer") {
            profileCard

            SectionTitle(text: "Start", trailing: "\(store.builtIn.count) trainings")

            NavigationLink { LibraryView() } label: {
                NavRow(glyph: .grid, title: "Training Library",
                       detail: "\(store.builtIn.count) built-in exercises")
            }
            .buttonStyle(.plain)

            NavigationLink { WarmupView() } label: {
                NavRow(glyph: .bolt, title: "Warm-Up",
                       detail: "Three short sets to get moving", tint: palette.warning)
            }
            .buttonStyle(.plain)

            NavigationLink { FreePracticeView() } label: {
                NavRow(glyph: .wave, title: "Free Practice",
                       detail: "Pick a path and drill it", tint: palette.accent)
            }
            .buttonStyle(.plain)

            NavigationLink { CustomTrainingView() } label: {
                NavRow(glyph: .plus, title: "Custom Training",
                       detail: "\(store.customTrainings.count) of your own", tint: palette.success)
            }
            .buttonStyle(.plain)

            if let daily = store.dailyTraining {
                SectionTitle(text: "Today", trailing: store.dailyDone ? "Done" : "Open")
                Card {
                    HStack(spacing: Metrics.spaceM) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                                .fill(palette.accent.opacity(0.16))
                            Glyph(kind: store.dailyDone ? .check : .challenge, size: 22, color: palette.accent)
                        }
                        .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(daily.name).font(.kBody).foregroundColor(palette.text).lineLimit(1)
                            Text("Daily challenge · \(daily.difficulty.title)")
                                .font(.kCaption).foregroundColor(palette.secondaryText)
                        }
                        Spacer(minLength: 4)
                    }
                    PrimaryButton(title: store.dailyDone ? "Play Again" : "Start Daily", glyph: .play) {
                        activeSession = daily
                    }
                }
            }

            if !store.recommendations.isEmpty {
                SectionTitle(text: "Recommended", trailing: weakestLabel)
                ForEach(store.recommendations) { training in
                    NavigationLink { TrainingDetailView(training: training) } label: {
                        TrainingRow(training: training,
                                    best: store.bestScores[training.id],
                                    rank: store.bestRanks[training.id],
                                    favorite: store.favorites.contains(training.id))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let recent = store.results.first {
                SectionTitle(text: "Last Session")
                Card {
                    HStack(spacing: Metrics.spaceM) {
                        RankBadge(rank: recent.rank, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recent.trainingName).font(.kBody).foregroundColor(palette.text).lineLimit(1)
                            Text("\(recent.score) pts · \(Int((recent.accuracy * 100).rounded()))% accuracy")
                                .font(.kCaption).foregroundColor(palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .fullScreenCover(item: $activeSession) { training in
            GameFlowView(training: training, challenge: isDaily(training) ? .daily : nil)
                .environmentObject(store)
                .environment(\.palette, palette)
        }
    }

    private func isDaily(_ training: Training) -> Bool {
        store.dailyTraining?.id == training.id
    }

    private var weakestLabel: String {
        guard let analysis = store.analysis else { return "Start anywhere" }
        return "Focus: \(analysis.weakest.title)"
    }

    private var profileCard: some View {
        Card {
            HStack(alignment: .center, spacing: Metrics.spaceM) {
                ZStack {
                    Circle().fill(palette.primary.opacity(0.16))
                    VStack(spacing: 0) {
                        Text("\(store.profile.level)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(palette.primary)
                        Text("LVL").font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(palette.secondaryText)
                    }
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Level \(store.profile.level)")
                        .font(.kHeadline).foregroundColor(palette.text)
                    BarMeter(value: store.profile.progress, tint: palette.accent)
                    Text("\(store.profile.experience) / \(store.profile.nextThreshold) XP")
                        .font(.kCaption).foregroundColor(palette.secondaryText)
                }
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    RankBadge(rank: store.profile.bestRank, size: 42)
                    Text("BEST").font(.system(size: 9, design: .rounded))
                        .foregroundColor(palette.secondaryText)
                }
            }
            HStack(spacing: Metrics.spaceS) {
                StatTile(label: "SESSIONS", value: "\(store.profile.totalSessions)")
                StatTile(label: "TOTAL SCORE", value: "\(store.profile.totalScore)")
                StatTile(label: "MINUTES", value: "\(store.totalTrainingSeconds / 60)")
            }
        }
    }
}
