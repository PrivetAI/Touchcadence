import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    var body: some View {
        ScreenScaffold(title: "Challenges", subtitle: "Fixed picks, reset by the calendar") {
            NavigationLink { DailyChallengeView() } label: {
                NavRow(glyph: .challenge, title: "Daily Challenge",
                       detail: store.dailyDone ? "Completed today" : "One training, chosen by the date",
                       tint: store.dailyDone ? palette.success : palette.accent)
            }
            .buttonStyle(.plain)

            NavigationLink { WeeklyChallengeView() } label: {
                NavRow(glyph: .medal, title: "Weekly Challenge",
                       detail: "\(store.weeklyStages.count) of 7 stages cleared",
                       tint: palette.warning)
            }
            .buttonStyle(.plain)

            Card {
                SectionTitle(text: "How picks are made")
                Text("The daily pick is the training at index hash(date) modulo the library size, so every device lands on the same drill for the same day. The weekly run is seven different trainings drawn from the week number.")
                    .font(.kCaption).foregroundColor(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let daily = store.dailyTraining {
                SectionTitle(text: "Today's Pick")
                TrainingRow(training: daily, best: store.bestScores[daily.id],
                            rank: store.bestRanks[daily.id],
                            favorite: store.favorites.contains(daily.id))
            }
        }
    }
}

// MARK: - Daily

struct DailyChallengeView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var playing = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f
    }()

    var body: some View {
        ScreenScaffold(title: "Daily Challenge",
                       subtitle: DailyChallengeView.dateFormatter.string(from: Date()), back: true) {
            if let training = store.dailyTraining {
                Card {
                    HStack(spacing: Metrics.spaceM) {
                        ZStack {
                            Circle().fill((store.dailyDone ? palette.success : palette.accent).opacity(0.16))
                            Glyph(kind: store.dailyDone ? .check : .challenge, size: 24,
                                  color: store.dailyDone ? palette.success : palette.accent)
                        }
                        .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(training.name).font(.kHeadline).foregroundColor(palette.text)
                                .lineLimit(2)
                            Text("\(training.category.title) · \(training.difficulty.title) · \(training.duration)s")
                                .font(.kCaption).foregroundColor(palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    PathPreview(movement: training.movement, motion: store.motion, palette: palette,
                                speed: training.difficulty.speedMultiplier)
                        .frame(height: 150)
                    Text(training.movement.summary).font(.kCaption).foregroundColor(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "STATUS", value: store.dailyDone ? "Cleared" : "Open",
                             tint: store.dailyDone ? palette.success : palette.warning)
                    StatTile(label: "BEST", value: "\(store.bestScores[training.id] ?? 0)")
                    StatTile(label: "INDEX", value: "#\(dailyIndex + 1)")
                }

                PrimaryButton(title: store.dailyDone ? "Play Again" : "Start Challenge", glyph: .play) {
                    playing = true
                }

                NavigationLink { TrainingDetailView(training: training) } label: {
                    NavRow(glyph: .info, title: "Training Details",
                           detail: "Path preview, history and personal best")
                }
                .buttonStyle(.plain)

                let runs = store.recentResults(for: training)
                if !runs.isEmpty {
                    SectionTitle(text: "Your Runs", trailing: "\(runs.count)")
                    ForEach(runs.prefix(5)) { ResultRow(result: $0) }
                }
            } else {
                EmptyNote(text: "The training library is still loading.")
            }
        }
        .fullScreenCover(isPresented: $playing) {
            if let training = store.dailyTraining {
                GameFlowView(training: training, challenge: .daily)
                    .environmentObject(store)
                    .environment(\.palette, palette)
            }
        }
    }

    private var dailyIndex: Int {
        ChallengePicker.dailyIndex(date: Date(), count: max(1, store.builtIn.count))
    }
}

// MARK: - Weekly

struct WeeklyChallengeView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var active: Training?
    @State private var activeStage: Int = 0

    var body: some View {
        let stages = store.weeklyTrainings
        return ScreenScaffold(title: "Weekly Challenge",
                              subtitle: "\(store.weeklyStages.count) of \(stages.count) stages cleared", back: true) {
            Card {
                HStack(spacing: Metrics.spaceM) {
                    RingGauge(value: stages.isEmpty ? 0 : Double(store.weeklyStages.count) / Double(stages.count),
                              caption: "complete", tint: palette.warning, diameter: 92)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Seven in a row").font(.kHeadline).foregroundColor(palette.text)
                        Text("Clear each stage to open the next. Progress resets when the week rolls over.")
                            .font(.kCaption).foregroundColor(palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if stages.isEmpty {
                EmptyNote(text: "The training library is still loading.")
            }

            ForEach(Array(stages.enumerated()), id: \.offset) { index, training in
                let cleared = store.weeklyStages.contains(index)
                let unlocked = index == 0 || store.weeklyStages.contains(index - 1)
                Card {
                    HStack(spacing: Metrics.spaceM) {
                        ZStack {
                            Circle().fill(stageTint(cleared: cleared, unlocked: unlocked).opacity(0.16))
                            if cleared {
                                Glyph(kind: .check, size: 20, color: palette.success)
                            } else if unlocked {
                                Text("\(index + 1)").font(.kHeadline).foregroundColor(palette.primary)
                            } else {
                                Glyph(kind: .lock, size: 18, color: palette.secondaryText)
                            }
                        }
                        .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(training.name).font(.kBody).foregroundColor(palette.text).lineLimit(1)
                            Text("\(training.movement.title) · \(training.difficulty.title) · \(training.duration)s")
                                .font(.kCaption).foregroundColor(palette.secondaryText).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    if unlocked {
                        PrimaryButton(title: cleared ? "Replay Stage \(index + 1)" : "Start Stage \(index + 1)",
                                      glyph: .play, tone: cleared ? .neutral : .primary) {
                            activeStage = index
                            active = training
                        }
                    } else {
                        Text("Clear stage \(index) first.")
                            .font(.kCaption).foregroundColor(palette.secondaryText)
                    }
                }
            }
        }
        .fullScreenCover(item: $active) { training in
            GameFlowView(training: training, challenge: .weekly(stage: activeStage))
                .environmentObject(store)
                .environment(\.palette, palette)
        }
    }

    private func stageTint(cleared: Bool, unlocked: Bool) -> Color {
        if cleared { return palette.success }
        return unlocked ? palette.primary : palette.secondaryText
    }
}
