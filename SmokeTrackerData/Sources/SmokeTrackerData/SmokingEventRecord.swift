import Foundation
import SwiftData

/// SmokingEvent'in SwiftData kalıcı temsili.
@Model
public final class SmokingEventRecord {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var sourceRaw: String

    public init(id: UUID, timestamp: Date, sourceRaw: String) {
        self.id = id
        self.timestamp = timestamp
        self.sourceRaw = sourceRaw
    }
}
