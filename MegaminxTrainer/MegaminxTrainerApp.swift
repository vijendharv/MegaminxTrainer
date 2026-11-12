import SwiftUI
import UIKit

@main struct MegaminxTrainerApp: App {
    var body: some Scene {
        WindowGroup { TrainerRootView().tint(.mint) }
    }
}

struct TrainerRootView: View {
    @StateObject private var oll = TrainerModel(kind: .oll)
    @StateObject private var pll = TrainerModel(kind: .pll)
    @State private var tab = 0
    @AppStorage("megaminx.activeTrainer") private var activeTrainer = TrainerKind.oll.rawValue

    private var kind: TrainerKind { TrainerKind(rawValue: activeTrainer) ?? .oll }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Picker("Trainer", selection: $activeTrainer) {
                    ForEach(TrainerKind.allCases) { trainer in
                        Text(trainer.title).tag(trainer.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Trainer type")
                Text(kind.detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))

            ContentView(tab: $tab)
                .environmentObject(kind == .oll ? oll : pll)
                .id(kind)
        }
        .onChange(of: activeTrainer) { _ in
            oll.cancelTiming()
            pll.cancelTiming()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
