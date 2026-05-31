import Foundation

/// İlk açılış onboarding'inin tamamlanıp tamamlanmadığını saklayan soyutlama.
/// Varsayılan: tamamlanmamış (false) — kullanıcı akışı görmeden uygulamaya düşmez.
public protocol OnboardingStateStoring: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
}
