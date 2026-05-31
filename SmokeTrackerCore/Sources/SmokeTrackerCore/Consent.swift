import Foundation

/// Eğitim verisi toplama izninin durumunu sağlayan/saklayan soyutlama.
/// Gizlilik-önce: varsayılan izin YOKTUR (false).
public protocol ConsentProviding: AnyObject {
    var trainingDataConsent: Bool { get set }
}
