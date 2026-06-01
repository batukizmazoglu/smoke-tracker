import SwiftUI
import WatchKit

@main
struct SmokeTrackerWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    static let refreshID = "com.batu.smoketracker.detect"

    var body: some Scene {
        WindowGroup {
            WatchTodayView(model: model)
                .onOpenURL { url in
                    if url.scheme == "smoketracker", url.host(percentEncoded: false) == "log" {
                        model.logFromComplication()
                    }
                }
        }
        .backgroundTask(.appRefresh(Self.refreshID)) {
            await MainActor.run { BackgroundDetectionRunner().run() }
            await MainActor.run { Self.scheduleNextRefresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.refresh()
                Self.scheduleNextRefresh()
            }
        }
    }

    /// Bir sonraki arka plan yenilemesini planlar (~20 dk sonra; sistem kısıtlar).
    static func scheduleNextRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(20 * 60),
            userInfo: nil
        ) { _ in }
    }
}
