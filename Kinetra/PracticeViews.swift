import SwiftUI

// MARK: - Warm-up

/// Three fixed short sets that ease the hand in before a real session.
struct WarmupView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var active: Training?
    @State private var stage = 0

    private static let sets: [Training] = [
        Training(id: UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!,
                 name: "Warm-Up: Wide Sweep", category: .control, difficulty: .beginner,
                 duration: 20, movement: .linear, targetSize: .huge),
        Training(id: UUID(uuidString: "A0000000-0000-4000-8000-000000000002")!,
                 name: "Warm-Up: Slow Orbit", category: .trajectory, difficulty: .beginner,
                 duration: 25, movement: .circle, targetSize: .large),
        Training(id: UUID(uuidString: "A0000000-0000-4000-8000-000000000003")!,
                 name: "Warm-Up: Easy Wave", category: .rhythm, difficulty: .easy,
                 duration: 30, movement: .sine, targetSize: .large)
    ]

    var body: some View {
        ScreenScaffold(title: "Warm-Up", subtitle: "Large targets, gentle speed", back: true) {
            EmptyNote(text: "Run these in order. Nothing here is scored against your best results, but every session still counts toward statistics.")

            ForEach(Array(WarmupView.sets.enumerated()), id: \.element.id) { index, set in
                Card {
                    HStack(spacing: Metrics.spaceM) {
                        ZStack {
                            Circle().fill(palette.warning.opacity(0.16))
                            Text("\(index + 1)").font(.kHeadline).foregroundColor(palette.warning)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(set.name).font(.kBody).foregroundColor(palette.text).lineLimit(1)
                            Text("\(set.movement.title) · \(set.duration)s")
                                .font(.kCaption).foregroundColor(palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    PathPreview(movement: set.movement, motion: store.motion, palette: palette)
                        .frame(height: 110)
                    PrimaryButton(title: "Start Set \(index + 1)", glyph: .play,
                                  tone: index == 0 ? .primary : .neutral) {
                        stage = index
                        active = set
                    }
                }
            }

            PrimaryButton(title: "Run Full Warm-Up", glyph: .bolt, tone: .accent) {
                stage = 0
                active = WarmupView.sets[0]
            }
        }
        .fullScreenCover(item: $active) { training in
            GameFlowView(training: training, onFinished: { _ in advance() })
                .environmentObject(store)
                .environment(\.palette, palette)
        }
    }

    private func advance() {
        // Nothing chained automatically; the user chooses the next set.
        stage = min(stage + 1, WarmupView.sets.count - 1)
    }
}

// MARK: - Free practice

/// Endless-feeling drill built on the fly from the pickers.
struct FreePracticeView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    @State private var movement: MovementType = .circle
    @State private var difficulty: Difficulty = .normal
    @State private var minutes: Int = 2
    @State private var active: Training?

    private var built: Training {
        Training(name: "Free Practice · \(movement.title)",
                 category: .combined, difficulty: difficulty,
                 duration: minutes * 60, movement: movement,
                 targetSize: store.settings.targetSize)
    }

    var body: some View {
        ScreenScaffold(title: "Free Practice", subtitle: "No targets to beat, just reps", back: true) {
            Card {
                Text("Movement").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: MovementType.allCases, title: { $0.title },
                           selection: $movement, columns: 3)
                PathPreview(movement: movement, motion: store.motion, palette: palette,
                            speed: difficulty.speedMultiplier)
                    .frame(height: 150)
                Text(movement.summary).font(.kCaption).foregroundColor(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Card {
                Text("Difficulty").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: Difficulty.allCases, title: { $0.title },
                           selection: $difficulty, columns: 4)
                Text("Length").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: [1, 2, 3, 5], title: { "\($0) min" },
                           selection: $minutes, columns: 4)
            }

            HStack(spacing: Metrics.spaceS) {
                StatTile(label: "TARGET", value: "\(Int(built.targetRadius.rounded()))pt")
                StatTile(label: "SPEED", value: String(format: "x%.2f",
                                                       difficulty.speedMultiplier * store.settings.speed))
                StatTile(label: "WINDOW", value: String(format: "%.2fs", difficulty.targetLifetime))
            }

            PrimaryButton(title: "Start Practice", glyph: .play) { active = built }
        }
        .fullScreenCover(item: $active) { training in
            GameFlowView(training: training)
                .environmentObject(store)
                .environment(\.palette, palette)
        }
    }
}

// MARK: - Custom training

struct CustomTrainingView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    @State private var name = ""
    @State private var notes = ""
    @State private var category: TrainingCategory = .precision
    @State private var difficulty: Difficulty = .normal
    @State private var movement: MovementType = .zigzag
    @State private var size: TargetSize = .medium
    @State private var seconds: Int = 45
    @State private var saved = false

    // Multi-field form: focus must be driven explicitly or only the first field takes a tap.
    @FocusState private var nameFocused: Bool
    @FocusState private var notesFocused: Bool

    var body: some View {
        ScreenScaffold(title: "Custom Training", subtitle: "Build the drill you actually need", back: true) {
            Card {
                Text("Name").font(.kCaption).foregroundColor(palette.secondaryText)
                TextField("", text: $name)
                    .placeholder(when: name.isEmpty) {
                        Text("Evening precision set").font(.kBody).foregroundColor(palette.secondaryText.opacity(0.6))
                    }
                    .font(.kBody)
                    .foregroundColor(palette.text)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .padding(Metrics.spaceM)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall).fill(palette.elevated))
                    .contentShape(Rectangle())
                    .onTapGesture { nameFocused = true }

                Text("Note to self").font(.kCaption).foregroundColor(palette.secondaryText)
                TextField("", text: $notes)
                    .placeholder(when: notes.isEmpty) {
                        Text("Keep the wrist still").font(.kBody).foregroundColor(palette.secondaryText.opacity(0.6))
                    }
                    .font(.kBody)
                    .foregroundColor(palette.text)
                    .focused($notesFocused)
                    .submitLabel(.done)
                    .padding(Metrics.spaceM)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall).fill(palette.elevated))
                    .contentShape(Rectangle())
                    .onTapGesture { notesFocused = true }
            }

            Card {
                Text("Category").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: TrainingCategory.allCases, title: { $0.title },
                           selection: $category, columns: 4)
                Text("Difficulty").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: Difficulty.allCases, title: { $0.title },
                           selection: $difficulty, columns: 4)
                Text("Movement").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: MovementType.allCases, title: { $0.title },
                           selection: $movement, columns: 3)
                Text("Target size").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: TargetSize.allCases, title: { $0.title },
                           selection: $size, columns: 4)
                Text("Duration").font(.kCaption).foregroundColor(palette.secondaryText)
                OptionGrid(options: [30, 45, 60, 90, 120, 180], title: { "\($0)s" },
                           selection: $seconds, columns: 3)
            }

            Card {
                SectionTitle(text: "Preview")
                PathPreview(movement: movement, motion: store.motion, palette: palette,
                            speed: difficulty.speedMultiplier)
                    .frame(height: 150)
                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "TARGET",
                             value: "\(Int((size.baseRadius * difficulty.sizeMultiplier).rounded()))pt")
                    StatTile(label: "SPEED", value: String(format: "x%.2f", difficulty.speedMultiplier))
                    StatTile(label: "LENGTH", value: "\(seconds)s")
                }
            }

            PrimaryButton(title: "Save Training", glyph: .check) { save() }

            if saved {
                Card {
                    HStack(spacing: Metrics.spaceS) {
                        Glyph(kind: .check, size: 20, color: palette.success)
                        Text("Saved to your library.").font(.kBody).foregroundColor(palette.success)
                    }
                }
            }

            if !store.customTrainings.isEmpty {
                SectionTitle(text: "Your Trainings", trailing: "\(store.customTrainings.count)")
                ForEach(store.customTrainings) { training in
                    NavigationLink { TrainingDetailView(training: training) } label: {
                        TrainingRow(training: training,
                                    best: store.bestScores[training.id],
                                    rank: store.bestRanks[training.id],
                                    favorite: store.favorites.contains(training.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func save() {
        nameFocused = false
        notesFocused = false
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "\(movement.title) \(category.title) Custom" : trimmed
        let trimmedNote = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let training = Training(name: finalName, category: category, difficulty: difficulty,
                                duration: seconds, movement: movement, targetSize: size, isCustom: true,
                                note: trimmedNote.isEmpty ? nil : trimmedNote)
        store.addCustom(training)
        name = ""
        notes = ""
        withAnimation(.easeInOut(duration: Metrics.animation)) { saved = true }
    }
}

// MARK: - Placeholder helper

extension View {
    /// Custom placeholder so no system prompt styling is relied on.
    func placeholder<Content: View>(when show: Bool,
                                    alignment: Alignment = .leading,
                                    @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            content().opacity(show ? 1 : 0)
            self
        }
    }
}
