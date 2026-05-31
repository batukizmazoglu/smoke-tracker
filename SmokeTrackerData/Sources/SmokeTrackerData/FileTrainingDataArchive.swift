import Foundation
import SmokeTrackerCore

/// Eğitim seanslarını disk üzerinde bir dizinde, seans başına bir JSON dosyası
/// (`<id>.json`) olarak saklar. iPhone tarafında, kullanıcı izniyle kullanılır.
///
/// NOT: Tek bir iş parçacığından/aktörden (uygulamada MainActor) kullanılmalıdır.
public final class FileTrainingDataArchive: TrainingDataArchiving {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save(_ session: TrainingSession) throws {
        let url = directory.appendingPathComponent("\(session.id.uuidString).json")
        let data = try JSONEncoder().encode(session)
        try data.write(to: url, options: .atomic)
    }

    public func allSessions() -> [TrainingSession] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> TrainingSession? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(TrainingSession.self, from: data)
            }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    public func delete(id: UUID) throws {
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func deleteAll() throws {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
    }
}
