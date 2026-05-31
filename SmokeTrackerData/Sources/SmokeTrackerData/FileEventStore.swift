import Foundation
import SmokeTrackerCore

/// JSON dosyasına kalıcı, basit EventStoring gerçeklemesi.
/// Watch tarafında, senkronlanana kadar olayları yerelde tutmak için kullanılır.
///
/// NOT: SwiftDataEventStore gibi, tek bir iş parçacığından/aktörden
/// (uygulamada MainActor) kullanılmalıdır.
public final class FileEventStore: EventStoring {
    private let url: URL
    private var events: [SmokingEvent]

    public init(url: URL) {
        self.url = url
        self.events = Self.load(from: url)
    }

    public func allEvents() -> [SmokingEvent] { events }

    public func add(_ event: SmokingEvent) {
        guard !contains(id: event.id) else { return }
        events.append(event)
        persist()
    }

    public func contains(id: UUID) -> Bool {
        events.contains { $0.id == id }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            // Watch yereli yetkili kaynak değildir (olay zaten iPhone'a
            // transferUserInfo ile gönderilir), ama yazma hatasını sessizce
            // yutmayalım; yalnızca yerel görüntü sürekliliği etkilenir.
            #if DEBUG
            print("[FileEventStore] persist başarısız: \(error)")
            #endif
        }
    }

    private static func load(from url: URL) -> [SmokingEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SmokingEvent].self, from: data) else {
            return []
        }
        return decoded
    }
}
