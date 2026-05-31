import Foundation

/// Watch app'i ile complication uzantısının paylaştığı App Group
/// konteynerindeki olay dosyasının konumunu sağlar. App Group sağlanmamışsa
/// (imzasız geliştirme veya test) Documents'a güvenli biçimde düşer.
public enum SharedContainer {
    /// Watch app'i ve complication'ın paylaştığı App Group kimliği.
    public static let watchAppGroup = "group.com.oero.smoketracker"

    public static func watchEventsURL(appGroup: String = watchAppGroup) -> URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.documentsDirectory
        return base.appendingPathComponent("watch-events.json")
    }

    public static func pendingCandidatesURL(appGroup: String = watchAppGroup) -> URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? URL.documentsDirectory
        return base.appendingPathComponent("pending-candidates.json")
    }
}
