import Foundation

/// Motion & Fitness yetkisinin platform-bağımsız durumu. CoreMotion'a bağımlı
/// olmadan UI ve karar mantığı test edilebilsin diye saf bir enum.
public enum MotionPermissionStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// Seans modunun, Motion izin durumuna göre uygunluğunu belirleyen saf
/// fonksiyonlar. Zarif düşüş (graceful degradation): izin reddedilse bile
/// tek-dokunuş +1 her zaman çalışmaya devam eder; yalnızca seans kapanır.
public enum SessionAvailability {
    /// Seans başlatılabilir mi? `notDetermined` izin penceresini açacağı için
    /// engellenmez; yalnızca açıkça reddedilmiş/kısıtlı durumlar engeller.
    public static func canStartSession(motion: MotionPermissionStatus) -> Bool {
        switch motion {
        case .authorized, .notDetermined: return true
        case .denied, .restricted: return false
        }
    }

    /// Kullanıcıya proaktif "izin ver" istemi gösterilmeli mi?
    public static func shouldPromptForMotion(_ status: MotionPermissionStatus) -> Bool {
        status == .notDetermined
    }

    /// İzin kalıcı olarak kapalı mı? (Ayarlar'a yönlendirme metni için.)
    public static func isBlocked(_ status: MotionPermissionStatus) -> Bool {
        status == .denied || status == .restricted
    }
}
