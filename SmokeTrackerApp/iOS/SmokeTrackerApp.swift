import SwiftUI

@main
struct SmokeTrackerApp: App {
    @State private var model = PhoneModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if model.hasCompletedOnboarding {
                TodayView(model: model)
            } else {
                OnboardingView(model: model)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }
}
