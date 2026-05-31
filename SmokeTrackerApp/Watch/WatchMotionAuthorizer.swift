import CoreMotion
import SmokeTrackerCore

/// CMSensorRecorder'ın Motion & Fitness yetki durumunu platform-bağımsız
/// `MotionPermissionStatus`'a çevirir (UI ve karar mantığı için).
enum WatchMotionAuthorizer {
    static var status: MotionPermissionStatus {
        switch CMSensorRecorder.authorizationStatus() {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
