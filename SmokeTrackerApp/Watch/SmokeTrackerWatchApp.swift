import SwiftUI

@main
struct SmokeTrackerWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchTodayView(model: model)
                .onOpenURL { url in
                    // Complication "smoketracker://log" ile açtıysa +1 işle.
                    if url.scheme == "smoketracker", url.host(percentEncoded: false) == "log" {
                        model.logFromComplication()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}
