import BackupDomain
import Foundation

package enum AutomaticBackupState: Sendable, Equatable {
    case idle, starting, running, stopping, stopped, monitorUnavailable, controlStateUnavailable,
        configurationUnavailable
}

/// Fixed codes only; arbitrary adapter diagnostics never reach the runtime's event boundary.
package enum AutomaticBackupIssue: Sendable, Equatable {
    case controlStateUnavailable, monitorUnavailable, configurationUnavailable
    case backupFailed(planID: UUID), admissionRejected(planID: UUID)
    case testRestoreFailed(planID: UUID), verificationFailed(planID: UUID), maintenanceFailed(planID: UUID)
    case ejectionFailed(planID: UUID)
    /// An explicit check that never ran, with the fixed reason the user can act on.
    case checkNotStarted(planID: UUID, reason: LocalServiceIssue)
    case suspiciousSnapshot(planID: UUID, runID: UUID)
}
