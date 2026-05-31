import Foundation
import SmokeTrackerCore

/// Onay bekleyen adayları tek bir JSON dosyasında (dizi) saklar. Stateless:
/// her çağrı diski yeniden okur; böylece arka plan görevi ve onay işleyicisi
/// ayrı uyanmalarda tutarlı çalışır. Best-effort (yazma hatasını yutmaz ama
/// fırlatmaz).
///
/// NOT: Stateless olduğu için aynı dosyaya eşzamanlı yazan birden fazla
/// süreç/uzantı yarış durumu (race) yaratabilir; tek bir süreçten/aktörden
/// (uygulamada MainActor) kullanılmalıdır.
public final class PendingCandidateStore: PendingCandidateStoring {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func save(_ candidate: PendingCandidate) {
        var all = load()
        all.removeAll { $0.id == candidate.id }
        all.append(candidate)
        persist(all)
    }

    public func all() -> [PendingCandidate] {
        load()
    }

    public func remove(id: UUID) {
        var all = load()
        all.removeAll { $0.id == id }
        persist(all)
    }

    private func load() -> [PendingCandidate] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([PendingCandidate].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persist(_ items: [PendingCandidate]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[PendingCandidateStore] persist başarısız: \(error)")
            #endif
        }
    }
}
