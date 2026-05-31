import Foundation

/// Arka plan tespitinin son işlediği zamanı (imleç) UserDefaults'ta saklar.
public final class DetectionCursorStore {
    private let defaults: UserDefaults
    private let key = "detection_cursor"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var cursor: Date? {
        get {
            let t = defaults.double(forKey: key)   // anahtar yoksa 0
            return t == 0 ? nil : Date(timeIntervalSince1970: t)
        }
        set {
            defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: key)
        }
    }
}
