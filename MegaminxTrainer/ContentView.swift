import Combine
import SwiftUI
import UIKit

struct CaseDiagram: View {
    @EnvironmentObject private var model: TrainerModel
    let id: Int
    var body: some View {
        if let path = Bundle.main.path(forResource: String(id), ofType: "png", inDirectory: model.kind.diagramDirectory),
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable().scaledToFit()
                .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("\(model.kind.title) diagram for case \(id)")
        } else { Image(systemName: "pentagon").resizable().scaledToFit().accessibilityLabel("Diagram unavailable") }
    }
}
/// Shared empty state using APIs available on iOS and iPadOS 16.
struct TrainerEmptyState: View {
    let title: String
    let systemImage: String
    var description: Text? = nil

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title).font(.title2.bold())
            if let description {
                description.font(.body).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .accessibilityElement(children: .combine)
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: TrainerModel
    @Binding var tab: Int
    var body: some View {
        TabView(selection: $tab) {
            TrainingHomeView()
                .tabItem { Label("Train", systemImage: "timer") }.tag(0)
            NavigationStack { CaseLibrary(isReference: true) }
                .tabItem { Label("Algorithms", systemImage: "book") }.tag(1)
            NavigationStack { HistoryView() }
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .onChange(of: tab) { _ in model.cancelTiming() }
    }
}
struct TrainingHomeView: View {
    @EnvironmentObject private var model: TrainerModel
    @State private var showingPractice = false

    var body: some View {
        NavigationStack {
            CaseLibrary { recap in
                model.begin(recap: recap)
                showingPractice = true
            }
            .navigationDestination(isPresented: $showingPractice) { PracticeView() }
        }
    }
}

struct CaseLibrary: View {
    @EnvironmentObject private var model: TrainerModel
    @State private var search = ""
    @State private var detailCase: TrainerCase?
    let isReference: Bool
    let train: (Bool) -> Void

    init(isReference: Bool = false, train: @escaping (Bool) -> Void = { _ in }) {
        self.isReference = isReference
        self.train = train
    }

    private var filtered: [TrainerCase] {
        model.cases.filter { item in
            search.isEmpty || item.name.localizedCaseInsensitiveContains(search)
                || model.kind.groupName(item.group).localizedCaseInsensitiveContains(search)
                || item.groupDescription.localizedCaseInsensitiveContains(search)
                || item.algorithms.contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isReference ? "\(model.kind.title) Algorithms" : model.kind == .oll ? "ONE FACE.\nA LITTLE FASTER." : "EVERY PIECE.\nIN ITS PLACE.").font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    Text("Megaminx \(model.kind.title) • \(model.cases.count) cases").foregroundStyle(.secondary)
                    Text(isReference ? "Tap a diagram to study algorithms and alternatives. Use Information for learning paths and recognition tips." : model.kind.instructions + " Select cases below, then start Train or Recap.").font(.subheadline)
                }.padding(.top)
                if model.cases.isEmpty { TrainerEmptyState("Case data unavailable", systemImage: "exclamationmark.triangle") }
                ForEach(Array(Set(filtered.map(\.group))).sorted(), id: \.self) { group in
                    let items = filtered.filter { $0.group == group }
                    VStack(alignment: .leading, spacing: 12) {
                        if isReference {
                            groupHeading(group, items: items)
                        } else {
                            Button { model.toggle(Set(items.map(\.id))) } label: {
                                HStack {
                                    groupHeading(group, items: items)
                                    Spacer()
                                    Image(systemName: Set(items.map(\.id)).isSubset(of: model.selected) ? "checkmark.circle.fill" : "circle")
                                }.frame(minHeight: 44)
                            }.buttonStyle(.plain)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 12)], spacing: 12) {
                            ForEach(items) { item in
                                VStack(spacing: 0) {
                                    Button { detailCase = item } label: {
                                        VStack(spacing: 10) {
                                            CaseDiagram(id: item.id).frame(height: 95)
                                            HStack {
                                                Text(item.name).font(.headline)
                                                Spacer()
                                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                            }
                                        }.padding(12)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(model.kind.title) case \(item.name), view algorithms")
                                    if !isReference {
                                        Divider().padding(.horizontal, 12)
                                        Button { model.toggle([item.id]) } label: {
                                            Label(model.selected.contains(item.id) ? "Selected" : "Select",
                                                  systemImage: model.selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.subheadline).foregroundStyle(.mint)
                                                .frame(maxWidth: .infinity, minHeight: 44)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Select case \(item.name) for practice")
                                        .accessibilityValue(model.selected.contains(item.id) ? "Selected" : "Not selected")
                                    }
                                }
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(!isReference && model.selected.contains(item.id) ? Color.mint : .clear, lineWidth: 2))
                            }
                        }
                    }
                }
            }.padding().frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isReference ? "\(model.kind.title) Algorithms" : "\(model.kind.title) Trainer").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Find a case, group or algorithm")
        .toolbar {
            if isReference {
                NavigationLink { InformationView() } label: {
                    Label("Information", systemImage: "info.circle")
                }
            } else {
                Menu("Selection") {
                    Button("Select all") { model.selected = Set(model.cases.map(\.id)); model.save() }
                    Button("Clear selection") { model.selected = []; model.save() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isReference {
                VStack(spacing: 10) {
                    Text("\(model.selected.count) cases selected").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button { train(true) } label: { Label("Recap", systemImage: "arrow.triangle.2.circlepath") }.buttonStyle(.bordered)
                        Button { train(false) } label: { Label("Train", systemImage: "play.fill") }.buttonStyle(.borderedProminent)
                    }.controlSize(.large).disabled(model.selected.isEmpty)
                }.frame(maxWidth: .infinity).padding().background(.regularMaterial)
            }
        }
        .sheet(item: $detailCase) { item in
            CaseDetailView(item: item).environmentObject(model)
        }
    }

    private func groupHeading(_ group: Int, items: [TrainerCase]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.kind.groupName(group)).font(.headline)
            Text(items.first?.groupDescription ?? "").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct PracticeView: View {
    @EnvironmentObject private var model: TrainerModel
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if model.complete {
                    TrainerEmptyState("Recap complete", systemImage: "checkmark.seal.fill", description: Text("You finished \(model.practiced) timed solves. Choose cases or start another round."))
                    Button("Repeat recap") { model.begin(recap: true) }.buttonStyle(.borderedProminent)
                } else if let item = model.current {
                    HStack {
                        Label(model.recap ? "RECAP" : "FREE PRACTICE", systemImage: "pentagon.fill").font(.caption.bold()).foregroundStyle(.mint)
                        Spacer()
                        Text(model.recap ? "\(model.recapPosition) / \(model.total)" : "Case \(item.name)").font(.subheadline)
                    }
                    Text("Build the case").font(.title2.bold())
                    Text("Apply this setup to a solved Megaminx. When revealing algorithms, match the grip in the diagram.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text(item.setup.isEmpty ? "Already solved — no setup moves." : item.setup).font(.system(.title3, design: .monospaced)).multilineTextAlignment(.center).textSelection(.enabled)
                        .padding(20).frame(maxWidth: .infinity).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    Button { model.tapTimer() } label: {
                        VStack(spacing: 12) {
                            Text(timeString(model.elapsed)).font(.system(size: 76, weight: .light, design: .rounded)).monospacedDigit().minimumScaleFactor(0.4).lineLimit(1)
                            Text(model.running ? "TAP TO STOP" : model.elapsed > 0 ? "SOLVE SAVED" : "TAP TO START").font(.caption.bold()).tracking(2)
                        }.foregroundStyle(model.running ? Color.mint : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 185).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(model.elapsed > 0 && !model.running)
                        .accessibilityLabel(model.running ? "Stop timer" : "Start timer")
                    if !model.running {
                        HStack {
                            Button { model.reveal.toggle() } label: { Label(model.reveal ? "Hide solution" : "Reveal solution", systemImage: "eye") }
                            Spacer()
                            Button { model.next() } label: { Label(model.elapsed > 0 ? "Next case" : "Skip", systemImage: "arrow.right") }.buttonStyle(.borderedProminent)
                        }.controlSize(.large)
                        if model.reveal {
                            CaseDiagram(id: item.id).frame(height: 180)
                            Text("\(model.kind.title) Case \(item.name)").font(.headline)
                            CaseAlgorithms(item: item).id(item.id)
                        }
                    }
                } else {
                    TrainerEmptyState("Ready when you are", systemImage: "timer", description: Text("Select cases in Train, then tap Train or Recap."))
                    Button("Train selected cases") { model.begin(recap: false) }.buttonStyle(.borderedProminent).disabled(model.selected.isEmpty)
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(Color(.systemGroupedBackground))
            .navigationTitle("\(model.kind.title) Practice")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(timer) { _ in model.tick() }
            .onChange(of: scenePhase) { phase in if phase != .active { model.cancelTiming() } }
            .onChange(of: model.running) { running in UIApplication.shared.isIdleTimerDisabled = running }
            .onDisappear { model.cancelTiming(); UIApplication.shared.isIdleTimerDisabled = false }
    }
}
struct HistoryView: View {
    @EnvironmentObject private var model: TrainerModel
    @State private var confirmClear = false
    var body: some View {
        List {
            Section("\(model.kind.title) practice") {
                LabeledContent("Solves", value: String(model.solves.count))
                LabeledContent("Best", value: timeString(model.best))
                LabeledContent("Mean", value: timeString(model.mean))
                LabeledContent("Average of 5", value: timeString(model.ao5))
            }
            Section("Recent solves · swipe to delete") {
                if model.solves.isEmpty { Text("Your timed solves will appear here.").foregroundStyle(.secondary) }
                ForEach(model.solves) { solve in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Case \(model.cases.first { $0.id == solve.caseID }?.name ?? String(solve.caseID))")
                            Text(solve.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(timeString(solve.seconds)).font(.title3.monospacedDigit())
                    }
                }.onDelete { indices in model.solves.remove(atOffsets: indices); model.save() }
            }
        }.navigationTitle("\(model.kind.title) Progress")
            .toolbar { Button("Clear", role: .destructive) { confirmClear = true }.disabled(model.solves.isEmpty) }
            .confirmationDialog("Delete all solve times?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete all times", role: .destructive) { model.solves = []; model.save() }
            }
    }
}
struct SettingsView: View {
    @EnvironmentObject private var model: TrainerModel
    var body: some View {
        Form {
            Section("\(model.kind.title) Practice") {
                Toggle("Balance case frequency", isOn: $model.weighted).onChange(of: model.weighted) { _ in model.save() }
                Text("Cases seen less often are more likely to appear in Train mode. Recap visits each selected case once.").font(.caption).foregroundStyle(.secondary)
            }
            Section("How to train") {
                Text("1. Start with a solved Megaminx.\n2. Apply the setup with the last layer on top.\n3. Tap the timer, solve the last-layer case, then tap to stop.\n4. Tap Next case and reset the puzzle before the next setup.")
                Text("Turns are 72°. U2 means two turns; a prime (′) reverses the direction. Timing cancels if you leave Practice or the app becomes inactive.").font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Privacy") { Text("OLL and PLL keep separate selections, practice history, and preferences on this device. No account, analytics, or network connection is required.") }
        }.navigationTitle("Settings")
    }
}

struct CaseDetailView: View {
    @EnvironmentObject private var model: TrainerModel
    @Environment(\.dismiss) private var dismiss
    let item: TrainerCase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CaseDiagram(id: item.id).frame(height: 220).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.kind.groupName(item.group)).font(.headline)
                        Text(item.groupDescription).foregroundStyle(.secondary)
                    }
                    Button { model.toggle([item.id]) } label: {
                        Label(model.selected.contains(item.id) ? "Selected for practice" : "Select for practice",
                              systemImage: model.selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }.buttonStyle(.bordered)
                    CaseAlgorithms(item: item)
                    DisclosureGroup("Setup moves") {
                        CopyableAlgorithm(title: "Apply to a solved Megaminx", sequence: item.setup)
                            .padding(.top, 12)
                    }
                }
                .padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(model.kind.title) · \(item.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct CaseAlgorithms: View {
    let item: TrainerCase

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Algorithms").font(.title2.bold())
            if item.setup.isEmpty {
                Text("Already solved — no algorithm needed.").foregroundStyle(.secondary)
            } else {
                Text("Match the diagram’s grip. Include leading puzzle rotations when shown.")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(Array(item.algorithms.enumerated()), id: \.offset) { index, sequence in
                    CopyableAlgorithm(title: index == 0 ? "Algorithm 1" : "Alternative \(index + 1)", sequence: sequence)
                }
                DisclosureGroup("Inverse setup · exact reset") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use the same grip as the setup to return to the exact starting state.")
                            .font(.caption).foregroundStyle(.secondary)
                        CopyableAlgorithm(title: "Undo setup", sequence: item.solution)
                    }.padding(.top, 12)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CopyableAlgorithm: View {
    let title: String
    let sequence: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                if !sequence.isEmpty {
                    Button {
                        UIPasteboard.general.string = sequence
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline).frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("\(copied ? "Copied" : "Copy") \(title)")
                }
            }
            Text(sequence.isEmpty ? "No moves needed." : sequence)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct InformationView: View {
    @EnvironmentObject private var model: TrainerModel
    private var groups: [Int] { Array(Set(model.cases.map(\.group))).sorted() }
    private var recognition: [(String, String)] {
        model.kind == .oll ? [
            ("Corner orientation (OCLL)", "Groups 2–5"),
            ("Edge orientation (EOLL)", "Group 1"),
            ("Line edges · 3 oriented corners", "Groups 6–11"),
            ("Line edges · 2 oriented corners", "Groups 12–17"),
            ("Line edges · fewer than 2 oriented corners", "Groups 18–21"),
            ("L-shaped edges · 3 oriented corners", "Groups 22–27"),
            ("L-shaped edges · 2 oriented corners", "Groups 28–33"),
            ("L-shaped edges · fewer than 2 oriented corners", "Groups 34–37")
        ] : [
            ("Corner permutation (CPLL)", "Groups A, E, K, H"),
            ("Edge permutation (EPLL)", "Groups U, Z, Q, H"),
            ("Block larger than 2×1", "Groups D, F, J, M, V, W, Y"),
            ("R block · joined bar and headlights", "Groups B, P, R"),
            ("Multiple 2×1 bars", "Groups C, N, S, T, Y"),
            ("One 2×1 bar", "Groups G, I"),
            ("No blocks", "Groups L, X")
        ]
    }

    var body: some View {
        List {
            Section("\(model.kind.title) learning path") {
                Text(model.kind.detail).font(.headline)
                if model.kind == .oll {
                    Text("You can learn OLL in any order. For an easier start, try groups 1, 6–9, 22, 24, 28–31, and 35.")
                    Text("Cases with only one oriented edge are omitted. Aim to orient at least three edges during the last slot.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Build a four-look last-layer foundation, then learn these PLL groups in order:")
                    Text("U → Z → Q → T → Y → N → B → D → F → W → M → V → J → P → R → G → C → S → I → L → X")
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text("Recognition and algorithm difficulty vary substantially between PLL groups.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(recognition, id: \.0) { feature, groupNames in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(feature)
                        Text(groupNames).font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            } header: {
                Text("Recognize the case")
            } footer: {
                Text("Check the features from top to bottom. A case can share features with several groups.")
            }
            Section("Group directory") {
                ForEach(groups, id: \.self) { group in
                    NavigationLink {
                        GroupAlgorithmsView(group: group)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.kind.groupName(group)).font(.headline)
                            Text(model.cases.first { $0.group == group }?.groupDescription ?? "")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            }
            Section("Reading algorithms") {
                Text("Each face turn is 72°. A prime (′ or ') reverses a turn; 2 means two turns, and 3 means three turns.")
                Text("Parentheses group moves. A trailing ×3 or x3 repeats the group three times. Leading x and y moves rotate the puzzle; keep them when copying an algorithm.")
                Text("Algorithms preserve the sheet’s notation, including BR, DR, bR, and dR. Match the diagram’s viewing angle before starting.")
                Text("In practice, the inverse setup is also available to undo the setup from the same grip.")
            }
        }
        .navigationTitle("\(model.kind.title) Information")
    }
}

struct GroupAlgorithmsView: View {
    @EnvironmentObject private var model: TrainerModel
    let group: Int
    @State private var detailCase: TrainerCase?

    var body: some View {
        List(model.cases.filter { $0.group == group }) { item in
            Button { detailCase = item } label: {
                HStack(spacing: 16) {
                    CaseDiagram(id: item.id).frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.headline)
                        Text(item.setup.isEmpty ? "Solved / skip" : "\(item.algorithms.count) algorithms")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Case \(item.name), view algorithms")
        }
        .navigationTitle(model.kind.groupName(group))
        .sheet(item: $detailCase) { item in
            CaseDetailView(item: item).environmentObject(model)
        }
    }
}
