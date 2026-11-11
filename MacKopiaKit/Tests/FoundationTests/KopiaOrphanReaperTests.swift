import Darwin
import Foundation
import Testing

@testable import KopiaCLI

@Suite(
    "Orphaned Kopia processes", .tags(.integration),
    .enabled(if: FileManager.default.isExecutableFile(atPath: NativeKopiaFixture.binary.path)))
struct KopiaOrphanReaperTests {
    @Test func stopsOnlyOrphansOfThisExecutableAndHome() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // A connect to a closed loopback port keeps Kopia 0.23.1 retrying until it is signalled.
        let executable = NativeKopiaFixture.binary.resolvingSymlinksInPath()
        let repositories = root.appendingPathComponent("Library/Application Support/MacKopia/Repositories").path
        let owned = "--config-file=\(repositories)/\(UUID().uuidString)/repository.config"
        let other = root.appendingPathComponent("other")
        try FileManager.default.copyItem(at: executable, to: other)

        let orphan = try orphaned(executable, owned, root: root)
        let foreignHome = try orphaned(
            executable, "--config-file=\(root.path)/elsewhere/repository.config", root: root)
        let escaping = try orphaned(
            executable, "--config-file=\(repositories)/../../escape/repository.config", root: root)
        let otherBinary = try orphaned(other, owned, root: root)
        let child = Process()
        child.executableURL = executable
        child.arguments = arguments(owned, root: root)
        child.environment = environment(root)
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        try child.run()
        defer {
            for pid in [orphan, foreignHome, escaping, otherBinary] { kill(pid, SIGKILL) }
            child.terminate()
        }

        let reaper = KopiaOrphanReaper(executable: executable, homeDirectory: root, grace: .seconds(2))
        #expect(reaper.candidates().map(\.pid) == [orphan])
        #expect(await reaper.reap() == 1)
        #expect(try await exited(orphan))
        for survivor in [foreignHome, escaping, otherBinary, child.processIdentifier] {
            #expect(kill(survivor, 0) == 0)
        }
        #expect(await reaper.reap() == 0)
    }

    /// Starts the executable through a shell that exits at once, so launchd adopts it as an orphan would be.
    private func orphaned(_ executable: URL, _ configuration: String, root: URL) throws -> pid_t {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments =
            ["-c", "\"$0\" \"$@\" < /dev/null > /dev/null 2>&1 & echo $!", executable.path]
            + arguments(configuration, root: root)
        shell.environment = environment(root)
        let output = Pipe()
        shell.standardOutput = output
        try shell.run()
        shell.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let pid = try #require(pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        // Adoption by launchd follows the shell's exit; wait until the kernel reports it.
        for _ in 0..<100 where parent(of: pid) != 1 { usleep(10_000) }
        #expect(parent(of: pid) == 1)
        return pid
    }

    private func arguments(_ configuration: String, root: URL) -> [String] {
        [
            "repository", "connect", "webdav", "--url=http://127.0.0.1:9/", configuration,
            "--log-dir=\(root.appendingPathComponent("logs").path)",
        ]
    }

    private func environment(_ root: URL) -> [String: String] {
        ["HOME": root.path, "KOPIA_CHECK_FOR_UPDATES": "false", "KOPIA_PASSWORD": UUID().uuidString]
    }

    private func parent(of pid: pid_t) -> pid_t? {
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&name, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    private func exited(_ pid: pid_t) async throws -> Bool {
        for _ in 0..<100 {
            if kill(pid, 0) != 0 { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return false
    }
}
