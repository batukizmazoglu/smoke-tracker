import Foundation
import SmokeTrackerCore

/// `TrainingSession`'ı WCSession dosya transferi için kodlar/çözer.
/// (Ham veri büyük olabildiğinden `transferUserInfo` yerine dosya kullanılır.)
public enum TrainingSessionCodec {
    public static func encode(_ session: TrainingSession) throws -> Data {
        try JSONEncoder().encode(session)
    }

    public static func decode(_ data: Data) throws -> TrainingSession {
        try JSONDecoder().decode(TrainingSession.self, from: data)
    }
}
