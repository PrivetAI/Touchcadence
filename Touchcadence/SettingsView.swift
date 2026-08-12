import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette
    @State private var confirmReset = false

    var body: some View {
        ScreenScaffold(title: "Settings", subtitle: "Everything is stored on this device") {
            NavigationLink { ThemesView() } label: {
                NavRow(glyph: .spark, title: "Themes",
                       detail: "Current: \(store.settings.theme.title)", tint: palette.accent)
            }
            .buttonStyle(.plain)

            Card {
                SectionTitle(text: "Target Size")
                OptionGrid(options: TargetSize.allCases, title: { $0.title },
                           selection: Binding(get: { store.settings.targetSize },
                                              set: { store.settings.targetSize = $0 }),
                           columns: 4)
                Text("Scales every built-in target. Custom trainings keep the size you saved them with.")
                    .font(.kCaption).foregroundColor(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Card {
                SectionTitle(text: "Speed", trailing: String(format: "x%.2f", store.settings.speed))
                OptionGrid(options: [0.75, 1.0, 1.25, 1.5], title: { String(format: "x%.2f", $0) },
                           selection: Binding(get: { store.settings.speed },
                                              set: { store.settings.speed = $0 }),
                           columns: 4)
                BarMeter(value: (store.settings.speed - 0.5) / 1.25, tint: palette.primary)
            }

            Card {
                toggleRow(title: "Sound", detail: "Synthesized hit and miss tones",
                          glyph: .wave, isOn: Binding(get: { store.settings.sound },
                                                      set: { store.settings.sound = $0 }))
                Rectangle().fill(palette.grid).frame(height: 1)
                toggleRow(title: "Vibration", detail: "Core Haptics feedback on every tap",
                          glyph: .bolt, isOn: Binding(get: { store.settings.vibration },
                                                      set: { store.settings.vibration = $0 }))
            }

            NavigationLink { AboutView() } label: {
                NavRow(glyph: .info, title: "About", detail: "What Touchcadence measures and how")
            }
            .buttonStyle(.plain)

            Card {
                SectionTitle(text: "Stored Data")
                Text("Trainings, results, medals, achievements and programs live in a local SQLite file. Preferences live in UserDefaults. Nothing leaves the device.")
                    .font(.kCaption).foregroundColor(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if !store.storageNote.isEmpty {
                    Text(store.storageNote).font(.system(size: 10, design: .monospaced))
                        .foregroundColor(palette.secondaryText.opacity(0.8))
                }
                if confirmReset {
                    Text("This clears every session, medal and achievement. Trainings stay.")
                        .font(.kCaption).foregroundColor(palette.error)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Metrics.spaceS) {
                        PrimaryButton(title: "Erase", glyph: .trash, tone: .danger) {
                            store.resetHistory()
                            confirmReset = false
                        }
                        PrimaryButton(title: "Keep", glyph: .close, tone: .neutral) {
                            confirmReset = false
                        }
                    }
                } else {
                    PrimaryButton(title: "Reset Progress", glyph: .restart, tone: .neutral) {
                        withAnimation(.easeInOut(duration: Metrics.animation)) { confirmReset = true }
                    }
                }
            }
        }
    }

    private func toggleRow(title: String, detail: String, glyph: GlyphKind, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: Metrics.spaceM) {
                ZStack {
                    RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                        .fill((isOn.wrappedValue ? palette.primary : palette.secondaryText).opacity(0.14))
                    Glyph(kind: glyph, size: 20, color: isOn.wrappedValue ? palette.primary : palette.secondaryText)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.kBody).foregroundColor(palette.text)
                    Text(detail).font(.kCaption).foregroundColor(palette.secondaryText)
                }
                Spacer(minLength: 0)
                // Hand-built switch: no system control.
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    Capsule().fill(isOn.wrappedValue ? palette.primary : palette.grid)
                        .frame(width: 46, height: 28)
                    Circle().fill(Color.white).frame(width: 22, height: 22).padding(3)
                }
                .frame(width: 46, height: 28)
                .animation(.easeInOut(duration: Metrics.animation), value: isOn.wrappedValue)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Themes

struct ThemesView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.palette) private var palette

    var body: some View {
        ScreenScaffold(title: "Themes", subtitle: "Picked manually — the device setting is ignored", back: true) {
            ForEach(Theme.allCases) { theme in
                let p = store.palette(for: theme)
                Button {
                    withAnimation(.easeInOut(duration: Metrics.animation)) {
                        store.settings.theme = theme
                    }
                } label: {
                    VStack(alignment: .leading, spacing: Metrics.spaceS) {
                        HStack(spacing: Metrics.spaceS) {
                            Text(theme.title).font(.kHeadline).foregroundColor(p.text)
                            Spacer()
                            if store.settings.theme == theme {
                                Glyph(kind: .check, size: 20, color: p.primary)
                            }
                            Chip(text: p.isDark ? "Dark" : "Light", color: p.secondaryText)
                        }
                        HStack(spacing: 6) {
                            ForEach(Array([p.primary, p.accent, p.success, p.warning, p.error].enumerated()),
                                    id: \.offset) { _, color in
                                RoundedRectangle(cornerRadius: 6).fill(color).frame(height: 22)
                            }
                        }
                        HStack(spacing: Metrics.spaceS) {
                            RoundedRectangle(cornerRadius: 6).fill(p.surface)
                                .frame(width: 46, height: 22)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(p.grid, lineWidth: 1))
                            Text("Aa").font(.kCaption).foregroundColor(p.text)
                            Text("Aa").font(.kCaption).foregroundColor(p.secondaryText)
                            Spacer()
                        }
                    }
                    .padding(Metrics.spaceM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerMedium).fill(p.background))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.cornerMedium)
                        .stroke(store.settings.theme == theme ? p.primary : p.grid,
                                lineWidth: store.settings.theme == theme ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var store: TrainingStore
    @State private var showPrivacyPolicy = false

    var body: some View {
        ScreenScaffold(title: "About", subtitle: "Touchcadence 1.0", back: true) {
            Card {
                HStack(spacing: Metrics.spaceM) {
                    TouchcadenceMark(size: 64, color: palette.text, accent: palette.accent, phase: 0.2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Touchcadence").font(.kHeadline).foregroundColor(palette.text)
                        Text("Offline precision trainer").font(.kCaption)
                            .foregroundColor(palette.secondaryText)
                    }
                }
                Text("Train precision, coordination, rhythm and reaction with a complete offline practice system. Improve motor skills through dynamic target exercises, detailed statistics and progressive challenges.")
                    .font(.kBody).foregroundColor(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Card {
                SectionTitle(text: "How scoring works")
                bullet("Every hit records a reaction time; a tap outside the target, or a target that runs out of time, is a miss.")
                bullet("Combo grows with each hit and resets on a miss. The multiplier is 1 + combo / 20, capped at 5.")
                bullet("Points are 100 x multiplier x difficulty x rhythm, then scaled by max(0.5, 1.8 - reaction).")
                bullet("Stability is 100 minus the deviation of the gaps between your hits.")
                bullet("Experience is score / 20, and levels rise as the threshold is met.")
            }

            Card {
                SectionTitle(text: "Library")
                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "TRAININGS", value: "\(store.builtIn.count)")
                    StatTile(label: "MOVEMENTS", value: "\(MovementType.allCases.count)")
                    StatTile(label: "CATEGORIES", value: "\(TrainingCategory.allCases.count)")
                }
                HStack(spacing: Metrics.spaceS) {
                    StatTile(label: "DIFFICULTIES", value: "\(Difficulty.allCases.count)")
                    StatTile(label: "RANKS", value: "\(Rank.allCases.count)")
                    StatTile(label: "THEMES", value: "\(Theme.allCases.count)")
                }
            }

            Card {
                SectionTitle(text: "Privacy")
                Text("No accounts, no analytics, no advertising and no permission prompts. Your trainings and results never leave this device.")
                    .font(.kBody).foregroundColor(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: "Privacy Policy", glyph: .lock, tone: .neutral) {
                    showPrivacyPolicy = true
                }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            // Same entry point as the launch stage, opened directly — no redirect check here.
            TouchcadenceWebStage(urlString: "https://touchcadence.org/click.php")
                .edgesIgnoringSafeArea(.bottom)
                .background(Color.black.ignoresSafeArea())
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.spaceS) {
            Circle().fill(palette.primary).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).font(.kCaption).foregroundColor(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
