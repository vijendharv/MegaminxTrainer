import SwiftUI

@main struct MegaminxTrainerApp: App {
    @StateObject private var model = TrainerModel()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(model).tint(.mint) }
    }
}
