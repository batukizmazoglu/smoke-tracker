import Foundation
import SwiftData
import SmokeTrackerCore

/// ModelContainer üreten fabrika.
public enum EventStoreFactory {
    /// Testler ve geçici kullanım için bellek-içi konteyner.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SmokingEventRecord.self, configurations: config)
    }

    /// Uygulama için diske kalıcı konteyner.
    public static func makePersistentContainer() throws -> ModelContainer {
        try ModelContainer(for: SmokingEventRecord.self)
    }
}

/// SwiftData tabanlı EventStoring gerçeklemesi (iPhone tarafı ana depo).
///
/// NOT: `ModelContext` Sendable değildir; bu nesne tek bir iş parçacığından/
/// aktörden (uygulamada MainActor) kullanılmalıdır. Bu yüzden bu tip
/// `@MainActor` ile işaretlenmez (nonisolated `EventStoring` gereksinimlerini
/// karşılayabilmek için) ama eşzamanlı erişimden kaçınmak çağıranın görevidir.
public final class SwiftDataEventStore: EventStoring {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func allEvents() -> [SmokingEvent] {
        let descriptor = FetchDescriptor<SmokingEventRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard let source = EventSource(rawValue: record.sourceRaw) else { return nil }
            return SmokingEvent(id: record.id, timestamp: record.timestamp, source: source)
        }
    }

    public func add(_ event: SmokingEvent) {
        // İki katmanlı tekilleştirme: açık `contains` kontrolü (save-time
        // birleştirme davranışına güvenmemek için) + modeldeki
        // @Attribute(.unique) güvenlik ağı. Aynı id = aynı mantıksal olay,
        // dolayısıyla tekrarın elenmesi veri kaybı değil doğru davranıştır.
        guard !contains(id: event.id) else { return }
        let record = SmokingEventRecord(
            id: event.id,
            timestamp: event.timestamp,
            sourceRaw: event.source.rawValue
        )
        context.insert(record)
        try? context.save()
    }

    public func contains(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<SmokingEventRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }
}
