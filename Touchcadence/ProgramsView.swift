import SwiftUI

struct ProgramsView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    var body: some View {
        ScreenScaffold(title: "Programs", subtitle: "Saved sets and favorites") {
            NavigationLink { FavoritesView() } label: {
                NavRow(glyph: .starFilled, title: "Favorites",
                       detail: "\(store.favoriteTrainings.count) starred trainings", tint: palette.warning)
            }
            .buttonStyle(.plain)

            NavigationLink { PersonalProgramsView() } label: {
                NavRow(glyph: .layers, title: "Personal Programs",
                       detail: "\(store.programs.count) saved programs", tint: palette.primary)
            }
            .buttonStyle(.plain)

            NavigationLink { CustomTrainingView() } label: {
                NavRow(glyph: .plus, title: "Custom Training",
                       detail: "\(store.customTrainings.count) of your own", tint: palette.success)
            }
            .buttonStyle(.plain)

            if !store.favoriteTrainings.isEmpty {
                SectionTitle(text: "Starred", trailing: "\(store.favoriteTrainings.count)")
                ForEach(store.favoriteTrainings.prefix(5)) { training in
                    NavigationLink { TrainingDetailView(training: training) } label: {
                        TrainingRow(training: training, best: store.bestScores[training.id],
                                    rank: store.bestRanks[training.id], favorite: true)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                EmptyNote(text: "Star a training from its detail screen and it shows up here.")
            }
        }
    }
}

// MARK: - Favorites

struct FavoritesView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    var body: some View {
        ScreenScaffold(title: "Favorites", subtitle: "\(store.favoriteTrainings.count) starred", back: true) {
            if store.favoriteTrainings.isEmpty {
                EmptyNote(text: "Nothing starred yet. Open any training and tap Add to Favorites.")
            }
            ForEach(store.favoriteTrainings) { training in
                NavigationLink { TrainingDetailView(training: training) } label: {
                    TrainingRow(training: training, best: store.bestScores[training.id],
                                rank: store.bestRanks[training.id], favorite: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Personal programs

struct PersonalProgramsView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var building = false

    var body: some View {
        ScreenScaffold(title: "Personal Programs", subtitle: "\(store.programs.count) saved", back: true) {
            PrimaryButton(title: "New Program", glyph: .plus) { building = true }

            if store.programs.isEmpty {
                EmptyNote(text: "A program is an ordered list of trainings you run back to back.")
            }

            ForEach(store.programs) { program in
                Card {
                    HStack(spacing: Metrics.spaceM) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                                .fill(palette.primary.opacity(0.16))
                            Glyph(kind: .layers, size: 22, color: palette.primary)
                        }
                        .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(program.name).font(.kBody).foregroundColor(palette.text).lineLimit(1)
                            Text("\(program.trainingIDs.count) trainings")
                                .font(.kCaption).foregroundColor(palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        GlyphButton(kind: .trash, size: 18, box: 38, color: palette.error) {
                            store.deleteProgram(program)
                        }
                    }
                    ForEach(program.trainingIDs, id: \.self) { id in
                        if let training = store.training(id: id) {
                            NavigationLink { TrainingDetailView(training: training) } label: {
                                HStack(spacing: Metrics.spaceS) {
                                    Glyph(kind: .forward, size: 14, color: palette.secondaryText)
                                    Text(training.name).font(.kCaption).foregroundColor(palette.text)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text("\(training.duration)s").font(.kCaption)
                                        .foregroundColor(palette.secondaryText)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $building) {
            ProgramBuilderView()
                .environmentObject(store)
                .environment(\.palette, palette)
        }
    }
}

// MARK: - Builder

struct ProgramBuilderView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var picked: [UUID] = []
    @State private var category: TrainingCategory = .speed
    @FocusState private var nameFocused: Bool

    private var pool: [Training] { store.trainings.filter { $0.category == category } }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("New Program").font(.kTitle).foregroundColor(palette.text)
                    Spacer()
                    GlyphButton(kind: .close, size: 18, box: 40) { dismiss() }
                }
                .padding(Metrics.spaceM)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Metrics.spaceM) {
                        Card {
                            Text("Program name").font(.kCaption).foregroundColor(palette.secondaryText)
                            TextField("", text: $name)
                                .placeholder(when: name.isEmpty) {
                                    Text("Morning circuit").font(.kBody)
                                        .foregroundColor(palette.secondaryText.opacity(0.6))
                                }
                                .font(.kBody).foregroundColor(palette.text)
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .padding(Metrics.spaceM)
                                .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                                    .fill(palette.elevated))
                                .contentShape(Rectangle())
                                .onTapGesture { nameFocused = true }
                        }

                        Card {
                            Text("Browse by category").font(.kCaption).foregroundColor(palette.secondaryText)
                            OptionGrid(options: TrainingCategory.allCases, title: { $0.title },
                                       selection: $category, columns: 4)
                        }

                        SectionTitle(text: "Selected", trailing: "\(picked.count)")
                        if picked.isEmpty {
                            EmptyNote(text: "Tap trainings below to add them in order.")
                        } else {
                            ForEach(Array(picked.enumerated()), id: \.offset) { index, id in
                                if let training = store.training(id: id) {
                                    HStack(spacing: Metrics.spaceS) {
                                        Text("\(index + 1)").font(.kCaption).foregroundColor(palette.primary)
                                            .frame(width: 18)
                                        Text(training.name).font(.kCaption).foregroundColor(palette.text)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        GlyphButton(kind: .minus, size: 16, box: 34,
                                                    color: palette.error, background: false) {
                                            picked.remove(at: index)
                                        }
                                    }
                                    .padding(.horizontal, Metrics.spaceM)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                                        .fill(palette.surface))
                                }
                            }
                        }

                        SectionTitle(text: category.title, trailing: "\(pool.count)")
                        ForEach(pool) { training in
                            Button {
                                picked.append(training.id)
                            } label: {
                                HStack(spacing: Metrics.spaceS) {
                                    Glyph(kind: .plus, size: 16, color: palette.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(training.name).font(.kCaption).foregroundColor(palette.text)
                                            .lineLimit(1)
                                        Text("\(training.difficulty.title) · \(training.duration)s")
                                            .font(.system(size: 10, design: .rounded))
                                            .foregroundColor(palette.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(Metrics.spaceM)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                                    .fill(palette.surface))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metrics.spaceM)
                    .padding(.bottom, 100)
                }

                PrimaryButton(title: "Save Program", glyph: .check) {
                    nameFocused = false
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.addProgram(name: trimmed.isEmpty ? "Program \(store.programs.count + 1)" : trimmed,
                                     trainingIDs: picked)
                    dismiss()
                }
                .padding(Metrics.spaceM)
                .disabled(picked.isEmpty)
                .opacity(picked.isEmpty ? 0.5 : 1)
            }
        }
    }
}
