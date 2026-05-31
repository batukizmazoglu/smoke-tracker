import SwiftUI

@main
struct SmokeTrackerWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchTodayView(model: model)
        }
    }
}
