import BackupDomain
import Foundation
import KopiaServer

/// Resolves every selection through a fresh snapshot manifest and its directory ancestry.
/// No caller-supplied object ID or original source path becomes a local write target.
struct RestoreBrowser: Sendable {
    let service: any KopiaRestoreServing
    static let maximumSources = 1024
    static let maximumSnapshots = 10_000

    func snapshots() async throws -> [RestoreSnapshot] {
        let sources = try await service.sources().sources ?? []
        guard sources.count <= Self.maximumSources else { throw LocalServiceIssue.invalidRequest }
        var result: [RestoreSnapshot] = []
        for source in sources {
            try Task.checkCancellation()
            guard let source = source.source, let user = source.userName, let host = source.host,
                let path = source.path
            else { continue }
            let selector = try KopiaSnapshotSource(userName: user, host: host, path: path)
            for item in try await service.snapshotManifests(source: selector).snapshots ?? [] {
                guard let id = item.id, item.rootID != nil else { continue }
                result.append(
                    RestoreSnapshot(
                        id: id, sourcePath: path, user: user, host: host, date: item.startTime ?? "",
                        bytes: item.summary?.size ?? 0, files: item.summary?.files ?? 0,
                        retention: item.retention ?? [], pins: item.pins ?? [], description: item.description ?? "",
                        isIncomplete: !(item.incomplete ?? "").isEmpty || (item.summary?.numFailed ?? 0) > 0))
                guard result.count <= Self.maximumSnapshots else { throw LocalServiceIssue.invalidRequest }
            }
        }
        guard try JSONEncoder().encode(result).count <= 8 * 1024 * 1024 else {
            throw LocalServiceIssue.invalidRequest
        }
        return result.sorted { $0.date > $1.date }
    }

    /// `catalog` reuses a listing the caller already read, so one browse request reads the sources once.
    func resolve(
        snapshotID: String, components: [String], catalog: [RestoreSnapshot]? = nil
    ) async throws -> (id: String, directory: Bool, selector: String) {
        try RestoreSelection.validate(snapshotID: snapshotID, components: components)
        let listing: [RestoreSnapshot]
        if let catalog { listing = catalog } else { listing = try await snapshots() }
        guard let selected = listing.first(where: { $0.id == snapshotID }) else {
            throw LocalServiceIssue.invalidRequest
        }
        let source = try KopiaSnapshotSource(userName: selected.user, host: selected.host, path: selected.sourcePath)
        guard
            let snapshot = try await service.snapshotManifests(source: source).snapshots?.first(where: {
                $0.id == snapshotID
            }), let root = snapshot.rootID
        else { throw LocalServiceIssue.invalidRequest }
        var current = (id: root, directory: true, selector: snapshotID)
        for component in components {
            try Task.checkCancellation()
            guard current.directory else { throw LocalServiceIssue.invalidRequest }
            let matches = try await service.directory(id: current.id).entries?.filter { $0.name == component } ?? []
            guard matches.count == 1, let entry = matches.first, let name = entry.name,
                let object = entry.obj, entry.type == "f" || entry.type == "d"
            else {
                throw LocalServiceIssue.invalidRequest
            }
            // Kopia 0.23.1 / Go compares filename bytes; Swift equality allows NFC/NFD equivalents.
            // Use the manifest's spelling, and reject ambiguous equivalent names from foreign filesystems.
            current = (object, entry.type == "d", current.selector + "/" + name)
        }
        return current
    }

    /// The whole directory in display order; callers page it with `page(_:offset:)`.
    func entries(
        snapshotID: String, components: [String], catalog: [RestoreSnapshot]? = nil
    ) async throws -> [RestoreEntry] {
        let object = try await resolve(snapshotID: snapshotID, components: components, catalog: catalog)
        guard object.directory else { throw LocalServiceIssue.invalidRequest }
        let entries = try await service.directory(id: object.id).entries ?? []
        guard entries.count <= RestoreState.maximumDirectoryEntries else { throw LocalServiceIssue.invalidRequest }
        return try entries.compactMap { entry in
            guard let name = entry.name, RestoreSelection.validComponent(name) else {
                throw LocalServiceIssue.invalidRequest
            }
            guard entry.type == "d" || entry.type == "f" else { return nil }
            return RestoreEntry(name: name, isDirectory: entry.type == "d", bytes: entry.size ?? 0)
        }.sorted { ($0.isDirectory ? 0 : 1, $0.name) < ($1.isDirectory ? 0 : 1, $1.name) }
    }
    /// A page that starts past the end is rejected rather than shown empty; an empty directory has page 0 only.
    static func page(_ entries: [RestoreEntry], offset: Int) throws -> ArraySlice<RestoreEntry> {
        guard RestoreSelection.validEntryOffset(offset), offset == 0 || offset < entries.count else {
            throw LocalServiceIssue.invalidRequest
        }
        return entries[offset..<min(offset + RestoreState.entryPageSize, entries.count)]
    }

    /// The start of the page that holds `name`; a name that is not in the folder is rejected.
    static func offset(revealing name: String, in entries: [RestoreEntry]) throws -> Int {
        guard let index = entries.firstIndex(where: { $0.name == name }) else { throw LocalServiceIssue.invalidRequest }
        return index - index % RestoreState.entryPageSize
    }

    func search(snapshotID: String, query: String) async throws -> ([RestoreSearchMatch], Bool) {
        guard !query.isEmpty, query.utf8.count <= 256 else { throw LocalServiceIssue.invalidRequest }
        let root = try await resolve(snapshotID: snapshotID, components: [])
        var pending: [(String, [String])] = [(root.id, [])]
        var matches: [RestoreSearchMatch] = []
        var visited = 0
        var inspected = 0
        var limited = false
        while let (id, path) = pending.popLast() {
            try Task.checkCancellation()
            visited += 1
            if visited > 256 { return (matches, true) }
            let entries = try await service.directory(id: id).entries ?? []
            guard entries.count <= RestoreState.maximumDirectoryEntries else { return (matches, true) }
            for entry in entries {
                inspected += 1
                if inspected > 10_000 { return (matches, true) }
                guard let name = entry.name, RestoreSelection.validComponent(name), let object = entry.obj else {
                    throw LocalServiceIssue.invalidRequest
                }
                guard entry.type == "d" || entry.type == "f" else { continue }
                let components = path + [name]
                if name.localizedCaseInsensitiveContains(query) {
                    matches.append(RestoreSearchMatch(components: components, isDirectory: entry.type == "d"))
                    if matches.count >= 500 { return (matches, true) }
                }
                if entry.type == "d" {
                    if components.count >= 64 {
                        limited = true
                    } else {
                        guard pending.count < 2000 else { return (matches, true) }
                        pending.append((object, components))
                    }
                }
            }
        }
        return (matches, limited)
    }

}
