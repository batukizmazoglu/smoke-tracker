import Testing
import Foundation
import SmokeTrackerCore
@testable import SmokeTrackerData

@Suite struct FileTrainingDataArchiveTests {
    private func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("training-test-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeSession(recordedAt: TimeInterval = 1000) -> TrainingSession {
        TrainingSession(
            id: UUID(),
            eventID: UUID(),
            recordedAt: Date(timeIntervalSince1970: recordedAt),
            label: "sigara",
            samples: [MotionSample(timestamp: Date(timeIntervalSince1970: recordedAt), x: 1, y: 2, z: 3)]
        )
    }

    @Test func savedSessionIsReturnedByAllSessions() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        let session = makeSession()
        try archive.save(session)
        #expect(archive.allSessions() == [session])
    }

    @Test func deleteRemovesOnlyTheGivenSession() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        let a = makeSession(recordedAt: 100)
        let b = makeSession(recordedAt: 200)
        try archive.save(a)
        try archive.save(b)
        try archive.delete(id: a.id)
        #expect(archive.allSessions() == [b])
    }

    @Test func deleteAllEmptiesArchive() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        try archive.save(makeSession())
        try archive.save(makeSession())
        try archive.deleteAll()
        #expect(archive.allSessions().isEmpty)
    }

    @Test func allSessionsAreSortedByRecordedAt() throws {
        let archive = FileTrainingDataArchive(directory: makeTempDir())
        let older = makeSession(recordedAt: 100)
        let newer = makeSession(recordedAt: 200)
        try archive.save(newer)
        try archive.save(older)
        #expect(archive.allSessions().map(\.id) == [older.id, newer.id])
    }
}
