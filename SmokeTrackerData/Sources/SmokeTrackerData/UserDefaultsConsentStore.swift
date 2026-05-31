import Foundation
import SmokeTrackerCore

/// İzin durumunu UserDefaults'ta saklar. Varsayılan: izin yok (false).
public final class UserDefaultsConsentStore: ConsentProviding {
    private let defaults: UserDefaults
    private let key = "training_data_consent"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var trainingDataConsent: Bool {
        get { defaults.bool(forKey: key) }   // anahtar yoksa false
        set { defaults.set(newValue, forKey: key) }
    }
}
