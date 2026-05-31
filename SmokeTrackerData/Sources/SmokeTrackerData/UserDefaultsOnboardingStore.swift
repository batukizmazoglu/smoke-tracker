import Foundation
import SmokeTrackerCore

/// Onboarding-tamamlanma durumunu UserDefaults'ta saklar. Varsayılan: false.
public final class UserDefaultsOnboardingStore: OnboardingStateStoring {
    private let defaults: UserDefaults
    private let key = "has_completed_onboarding"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: key) }   // anahtar yoksa false
        set { defaults.set(newValue, forKey: key) }
    }
}
