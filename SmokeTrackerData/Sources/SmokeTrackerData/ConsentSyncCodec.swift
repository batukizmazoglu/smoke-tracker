import Foundation

/// Eğitim-verisi onayını WCSession `applicationContext` sözlüğüne kodlar/çözer.
/// Sözlük "en son durum"u taşır (latest-wins); bozuk/eksik içerikte `decode`
/// nil döner ve çağıran tarafı sessizce yok sayar.
public enum ConsentSyncCodec {
    static let versionKey = "consentVersion"
    static let valueKey = "trainingDataConsent"
    static let version = 1

    public static func encode(trainingDataConsent: Bool) -> [String: Any] {
        [versionKey: version, valueKey: trainingDataConsent]
    }

    public static func decode(_ context: [String: Any]) -> Bool? {
        guard context[versionKey] as? Int == version else { return nil }
        return context[valueKey] as? Bool
    }
}
