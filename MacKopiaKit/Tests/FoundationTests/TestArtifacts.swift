import Foundation

/// Keeps the secret-free diagnostics of a remote lifecycle run when CI asks for them.
///
/// CI sets `MACKOPIA_TEST_ARTIFACTS` and uploads that folder only when the job fails. Copied are Kopia's own log
/// files (the lifecycle tests already assert that no file under their root contains a test secret) and the fixture
/// server's stderr. Locally nothing is copied and the temporary root is still removed.
enum TestArtifacts {
    static func preserveLogs(from root: URL, as name: String) {
        guard let base = ProcessInfo.processInfo.environment["MACKOPIA_TEST_ARTIFACTS"], !base.isEmpty else { return }
        let manager = FileManager.default
        let target = URL(fileURLWithPath: base).appendingPathComponent("\(name)-\(UUID().uuidString)")
        guard let files = manager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return }
        while let file = files.nextObject() as? URL {
            let path = file.resolvingSymlinksInPath().path
            let inLogs = path.contains("/Library/Logs/")
            guard (inLogs && file.pathExtension == "log") || file.lastPathComponent == "fixture-stderr.log",
                (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            else { continue }
            let relative = String(path.dropFirst(root.resolvingSymlinksInPath().path.count + 1))
            let destination = target.appendingPathComponent(relative)
            try? manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? manager.copyItem(at: file, to: destination)
        }
    }
}
