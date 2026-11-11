import Darwin
import Foundation

/// Stops Kopia processes a previous agent left behind.
///
/// Children run in their own process group so terminal and launchd signals reach only the owner, which
/// stops them deliberately. If the owner dies without that (crash, SIGKILL, launchd exit timeout), the
/// children are reparented to launchd and keep running: Kopia 0.23.1 retries an unreachable or rejecting
/// WebDAV destination for hours. A process qualifies only when it is ours (same user), orphaned (parent
/// launchd), runs exactly the pinned executable and names a configuration file inside this home's
/// MacKopia repository directory. Identity is re-read before every signal to rule out PID reuse.
package struct KopiaOrphanReaper: Sendable {
    package struct Candidate: Equatable, Sendable {
        let pid: pid_t
        let started: timeval

        package static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.pid == rhs.pid && lhs.started.tv_sec == rhs.started.tv_sec
                && lhs.started.tv_usec == rhs.started.tv_usec
        }
    }

    private let executable: String
    private let configurationPrefix: String
    private let grace: Duration

    package init(executable: URL, homeDirectory: URL, grace: Duration = .seconds(5)) {
        self.executable = executable.resolvingSymlinksInPath().path
        configurationPrefix =
            "--config-file="
            + homeDirectory.appendingPathComponent("Library/Application Support/MacKopia/Repositories")
            .resolvingSymlinksInPath().path + "/"
        self.grace = grace
    }

    /// Returns the number of orphans that were stopped.
    @discardableResult
    package func reap() async -> Int {
        let orphans = candidates()
        guard !orphans.isEmpty else { return 0 }
        // SIGINT is Kopia's graceful stop: it closes the repository and releases its maintenance lease.
        for orphan in orphans where matches(orphan) { kill(orphan.pid, SIGINT) }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: grace)
        while clock.now < deadline, orphans.contains(where: matches) {
            try? await clock.sleep(for: .milliseconds(50))
        }
        for orphan in orphans where matches(orphan) { kill(orphan.pid, SIGKILL) }
        return orphans.count
    }

    package func candidates() -> [Candidate] {
        processes().compactMap { info in
            let candidate = Candidate(pid: info.kp_proc.p_pid, started: info.kp_proc.p_starttime)
            return qualifies(info) ? candidate : nil
        }
    }

    private func matches(_ candidate: Candidate) -> Bool {
        guard let info = Self.process(candidate.pid), qualifies(info) else { return false }
        return Candidate(pid: candidate.pid, started: info.kp_proc.p_starttime) == candidate
    }

    private func qualifies(_ info: kinfo_proc) -> Bool {
        let pid = info.kp_proc.p_pid
        guard pid > 1, info.kp_eproc.e_ppid == 1, info.kp_eproc.e_ucred.cr_uid == getuid(),
            Self.path(of: pid) == executable, let arguments = Self.arguments(of: pid)
        else { return false }
        return arguments.dropFirst().contains {
            $0.hasPrefix(configurationPrefix)
                && !$0.dropFirst(configurationPrefix.count).split(separator: "/").contains("..")
        }
    }

    private func processes() -> [kinfo_proc] {
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(bitPattern: getuid())]
        for _ in 0..<3 {
            var size = 0
            guard sysctl(&name, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }
            // Room for processes that start between the size query and the read.
            var list = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride + 16)
            size = list.count * MemoryLayout<kinfo_proc>.stride
            if sysctl(&name, 4, &list, &size, nil, 0) == 0 {
                return Array(list.prefix(size / MemoryLayout<kinfo_proc>.stride))
            }
            guard errno == ENOMEM else { return [] }
        }
        return []
    }

    private static func process(_ pid: pid_t) -> kinfo_proc? {
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&name, 4, &info, &size, nil, 0) == 0, size == MemoryLayout<kinfo_proc>.stride,
            info.kp_proc.p_pid == pid
        else { return nil }
        return info
    }

    private static func path(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return URL(
            fileURLWithPath: String(
                decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                as: UTF8.self)
        ).resolvingSymlinksInPath().path
    }

    /// KERN_PROCARGS2: argc, the executable path, padding, then argc NUL-terminated arguments.
    private static func arguments(of pid: pid_t) -> [String]? {
        var maximum: Int32 = 0
        var size = MemoryLayout<Int32>.size
        var limit: [Int32] = [CTL_KERN, KERN_ARGMAX]
        guard sysctl(&limit, 2, &maximum, &size, nil, 0) == 0, maximum > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: Int(maximum))
        var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        size = buffer.count
        guard sysctl(&name, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        let count = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }
        var arguments: [String] = []
        while arguments.count < count, index < size {
            let end = buffer[index..<size].firstIndex(of: 0) ?? size
            arguments.append(String(decoding: buffer[index..<end], as: UTF8.self))
            index = end + 1
        }
        return arguments.count == Int(count) ? arguments : nil
    }
}
