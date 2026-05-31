import Foundation

/// Aday pencerelerini imleç + çakışmaya göre eleyen saf filtre.
public enum CandidateFilter {
    /// Yalnızca `cursor`'dan sonra başlayan, birbiriyle çakışmayan adayları
    /// (başlangıca göre sıralı) döndürür.
    public static func filter(_ candidates: [CandidateWindow], after cursor: Date) -> [CandidateWindow] {
        let sorted = candidates.sorted { $0.start < $1.start }
        var result: [CandidateWindow] = []
        for c in sorted where c.start > cursor {
            if let last = result.last, c.start < last.end { continue }
            result.append(c)
        }
        return result
    }
}
