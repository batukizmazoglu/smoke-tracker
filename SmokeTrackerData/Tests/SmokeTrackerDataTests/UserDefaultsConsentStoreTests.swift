import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct UserDefaultsConsentStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "consent-test-\(UUID().uuidString)")!
    }

    @Test func defaultsToNoConsent() {
        let store = UserDefaultsConsentStore(defaults: makeDefaults())
        #expect(store.trainingDataConsent == false)
    }

    @Test func persistsConsentAcrossInstances() {
        let defaults = makeDefaults()
        let store = UserDefaultsConsentStore(defaults: defaults)
        store.trainingDataConsent = true
        #expect(store.trainingDataConsent == true)

        let reopened = UserDefaultsConsentStore(defaults: defaults)
        #expect(reopened.trainingDataConsent == true)
    }
}
