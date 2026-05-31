import Testing
@testable import SmokeTrackerCore

@Suite struct MotionPermissionTests {
    @Test func canStartWhenAuthorized() {
        #expect(SessionAvailability.canStartSession(motion: .authorized) == true)
    }

    @Test func canStartWhenNotDetermined() {
        // İlk seans başlatma izin penceresini açar; bu yüzden engellenmez.
        #expect(SessionAvailability.canStartSession(motion: .notDetermined) == true)
    }

    @Test func cannotStartWhenDeniedOrRestricted() {
        #expect(SessionAvailability.canStartSession(motion: .denied) == false)
        #expect(SessionAvailability.canStartSession(motion: .restricted) == false)
    }

    @Test func promptsOnlyWhenNotDetermined() {
        #expect(SessionAvailability.shouldPromptForMotion(.notDetermined) == true)
        #expect(SessionAvailability.shouldPromptForMotion(.authorized) == false)
        #expect(SessionAvailability.shouldPromptForMotion(.denied) == false)
        #expect(SessionAvailability.shouldPromptForMotion(.restricted) == false)
    }

    @Test func blockedOnlyWhenDeniedOrRestricted() {
        #expect(SessionAvailability.isBlocked(.denied) == true)
        #expect(SessionAvailability.isBlocked(.restricted) == true)
        #expect(SessionAvailability.isBlocked(.authorized) == false)
        #expect(SessionAvailability.isBlocked(.notDetermined) == false)
    }
}
