import Foundation

/// Pure source-list edits shared by the plan editor's picker, Finder drop, Delete key and Undo.
/// Plans need at least one source and unique paths (`BackupPlan` validation), so edits never break that.
public enum SourceListEdit {
    public static let maximumSources = 1024

    /// One removed source and its former position, so undo restores the exact order.
    public struct Removal: Sendable, Equatable {
        public let index: Int
        public let source: BackupSource
    }

    /// Appends new paths in order; duplicates of existing or earlier candidates are ignored.
    public static func adding(_ candidates: [BackupSource], to sources: [BackupSource]) -> [BackupSource] {
        var result = sources
        var paths = Set(sources.map(\.path))
        for candidate in candidates where result.count < maximumSources && paths.insert(candidate.path).inserted {
            result.append(candidate)
        }
        return result
    }

    /// Removes the selected sources unless that would leave the plan without any source.
    /// Returns `nil` when nothing may be removed; removals are ordered by ascending former index.
    public static func removing(
        _ ids: Set<UUID>, from sources: [BackupSource]
    ) -> (
        sources: [BackupSource], removals: [Removal]
    )? {
        let removals = sources.enumerated().filter { ids.contains($0.element.id) }.map {
            Removal(index: $0.offset, source: $0.element)
        }
        guard !removals.isEmpty, removals.count < sources.count else { return nil }
        return (sources.filter { !ids.contains($0.id) }, removals)
    }

    /// Reinserts removed sources at their former positions. Paths added again meanwhile stay single.
    public static func restoring(_ removals: [Removal], into sources: [BackupSource]) -> [BackupSource] {
        var result = sources
        for removal in removals.sorted(by: { $0.index < $1.index }) {
            guard !result.contains(where: { $0.path == removal.source.path || $0.id == removal.source.id }) else {
                continue
            }
            result.insert(removal.source, at: min(removal.index, result.count))
        }
        return result
    }
}
