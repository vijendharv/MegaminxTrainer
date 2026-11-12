import Combine
import SwiftUI
import UIKit

struct CaseDiagram: View {
    let id: Int
    var body: some View {
        if let path = Bundle.main.path(forResource: String(id), ofType: "png", inDirectory: "Cases"),
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable().scaledToFit()
                .padding(8).background(.white, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Orientation diagram for case \(id)")
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
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { CaseLibrary { recap in model.begin(recap: recap); tab = 1 } }
                .tabItem { Label("Cases", systemImage: "square.grid.2x2") }.tag(0)
            NavigationStack { PracticeView() }
                .tabItem { Label("Practice", systemImage: "timer") }.tag(1)
            NavigationStack { HistoryView() }
                .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .onChange(of: tab) { _ in model.cancelTiming() }
    }
}
struct CaseLibrary: View {
    @EnvironmentObject private var model: TrainerModel
    @State private var search = ""
    let train: (Bool) -> Void
    private var filtered: [OLLCase] {
        model.cases.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || "Group \($0.group)".localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ONE FACE.\nA LITTLE FASTER.").font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    Text("Megaminx OLL • \(model.cases.count) cases").foregroundStyle(.secondary)
                    Text("Choose the cases you want to master. Set up a solved Megaminx, then practice the last layer.").font(.subheadline)
                }.padding(.top)
                if model.cases.isEmpty { TrainerEmptyState("Case data unavailable", systemImage: "exclamationmark.triangle") }
                ForEach(Array(Set(filtered.map(\.group))).sorted(), id: \.self) { group in
                    let items = filtered.filter { $0.group == group }
                    VStack(alignment: .leading, spacing: 12) {
                        Button { model.toggle(Set(items.map(\.id))) } label: {
                            HStack {
                                Text("Group \(group)").font(.headline)
                                Spacer()
                                Image(systemName: Set(items.map(\.id)).isSubset(of: model.selected) ? "checkmark.circle.fill" : "circle")
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 12)], spacing: 12) {
                            ForEach(items) { item in
                                Button { model.toggle([item.id]) } label: {
                                    VStack(spacing: 10) {
                                        CaseDiagram(id: item.id).frame(height: 95)
                                        HStack {
                                            Text(item.name).font(.headline)
                                            Spacer()
                                            Image(systemName: model.selected.contains(item.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(.mint)
                                        }
                                    }.padding(12).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(model.selected.contains(item.id) ? Color.mint : .clear, lineWidth: 2))
                                }.buttonStyle(.plain).accessibilityLabel("Case \(item.name)")
                                    .accessibilityValue(model.selected.contains(item.id) ? "Selected" : "Not selected")
                            }
                        }
                    }
                }
            }.padding().frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Megaminx Lab").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Find a case or group")
        .toolbar {
            Menu("Selection") {
                Button("Select all") { model.selected = Set(model.cases.map(\.id)); model.save() }
                Button("Clear selection") { model.selected = []; model.save() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Text("\(model.selected.count) cases selected").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button { train(true) } label: { Label("Recap", systemImage: "arrow.triangle.2.circlepath") }.buttonStyle(.bordered)
                    Button { train(false) } label: { Label("Train", systemImage: "play.fill") }.buttonStyle(.borderedProminent)
                }.controlSize(.large).disabled(model.selected.isEmpty)
            }.frame(maxWidth: .infinity).padding().background(.regularMaterial)
        }
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
                    Text("Apply this setup to a solved Megaminx. Keep the same grip for the solution.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Text(item.setup).font(.system(.title3, design: .monospaced)).multilineTextAlignment(.center).textSelection(.enabled)
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
                            Text("Case \(item.name)").font(.headline)
                            Text(item.solution).font(.system(.body, design: .monospaced)).multilineTextAlignment(.center).textSelection(.enabled)
                            Text("Solution is the inverse of the setup sequence.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    TrainerEmptyState("Ready when you are", systemImage: "timer", description: Text("Select cases in the Cases tab, then tap Train or Recap."))
                    Button("Train selected cases") { model.begin(recap: false) }.buttonStyle(.borderedProminent).disabled(model.selected.isEmpty)
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(Color(.systemGroupedBackground))
            .navigationTitle("Practice")
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
            Section("Your practice") {
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
        }.navigationTitle("Progress")
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
            Section("Practice") {
                Toggle("Balance case frequency", isOn: $model.weighted).onChange(of: model.weighted) { _ in model.save() }
                Text("Cases seen less often are more likely to appear in Train mode. Recap visits each selected case once.").font(.caption).foregroundStyle(.secondary)
            }
            Section("How to train") {
                Text("1. Start with a solved Megaminx.\n2. Apply the setup with the last layer on top.\n3. Tap the timer, solve the orientation, then tap to stop.\n4. Tap Next case and reset the puzzle before the next setup.")
                Text("Turns are 72°. U2 means two turns; a prime (′) reverses the direction. Timing cancels if you leave Practice or the app becomes inactive.").font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Credits & sources") {
                Link("Reinier Schippers · original OLL trainer", destination: URL(string: "https://reinierschippers.nl/oll_trainer-master/")!)
                Text("Case names, setup sequences and diagrams follow the reference trainer, which credits James’s Megaminx OLL document and Roman Strakhov’s trainer. This is an independent prototype.").font(.footnote)
                Text("Diagram reuse permissions must be confirmed before public distribution.").font(.footnote)
            }
            Section("Privacy") { Text("Practice history and preferences stay on this device. No account, analytics, or network connection is required.") }
        }.navigationTitle("Settings")
    }
}
