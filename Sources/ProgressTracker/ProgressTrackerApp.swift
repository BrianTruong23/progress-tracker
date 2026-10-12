import SwiftUI

@main
struct ProgressTrackerApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 780, minHeight: 560)
        }
        .defaultSize(width: 940, height: 680)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
