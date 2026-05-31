import SwiftUI

@main
struct SmokeTrackerApp: App {
    @State private var model = PhoneModel()

    var body: some Scene {
        WindowGroup {
            TodayView(model: model)
        }
    }
}
