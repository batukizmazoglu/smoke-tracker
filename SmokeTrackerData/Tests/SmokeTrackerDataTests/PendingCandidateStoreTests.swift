import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct PendingCandidateStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-\(UUID().uuidString).json")
    }

    private func makeCandidate() -> PendingCandidate {
        let w = CandidateWindow(start: Date(timeIntervalSince1970: 1),
                                end: Date(timeIntervalSince1970: 2),
                                samples: [], confidence: 0.5)
        return PendingCandidate(id: UUID(), detectedAt: Date(timeIntervalSince1970: 3), window: w)
    }

    @Test func savedCandidateIsReturned() {
        let store = PendingCandidateStore(url: tempURL())
        let c = makeCandidate()
        store.save(c)
        #expect(store.all() == [c])
    }

    @Test func removeDeletesOnlyGivenCandidate() {
        let store = PendingCandidateStore(url: tempURL())
        let a = makeCandidate(), b = makeCandidate()
        store.save(a); store.save(b)
        store.remove(id: a.id)
        #expect(store.all().map(\.id) == [b.id])
    }

    @Test func saveDeduplicatesById() {
        let store = PendingCandidateStore(url: tempURL())
        let c = makeCandidate()
        store.save(c); store.save(c)
        #expect(store.all().count == 1)
    }

    @Test func persistsAcrossInstances() {
        let url = tempURL()
        let c = makeCandidate()
        PendingCandidateStore(url: url).save(c)
        #expect(PendingCandidateStore(url: url).all() == [c])
    }
}
