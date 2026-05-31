import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct UserDefaultsOnboardingStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "onboarding-test-\(UUID().uuidString)")!
    }

    @Test func defaultsToNotCompleted() {
        let store = UserDefaultsOnboardingStore(defaults: makeDefaults())
        #expect(store.hasCompletedOnboarding == false)
    }

    @Test func persistsCompletionAcrossInstances() {
        let defaults = makeDefaults()
        let store = UserDefaultsOnboardingStore(defaults: defaults)
        store.hasCompletedOnboarding = true
        #expect(store.hasCompletedOnboarding == true)

        let reopened = UserDefaultsOnboardingStore(defaults: defaults)
        #expect(reopened.hasCompletedOnboarding == true)
    }
}
