import AgentProtocol
import BackupDomain

extension AppRoute {
    /// Window-level problems that are fixed elsewhere in the app get a direct way there.
    static func route(for issue: LocalServiceIssue?) -> AppRoute? {
        switch issue {
        case .destination: .destinations
        case .backupFailed, .verificationFailed, .maintenanceFailed, .automationUnavailable: .activity
        default: nil
        }
    }

    var issueActionTitle: String {
        self == .destinations ? String(localized: "Speicherziele anzeigen") : String(localized: "Aktivität anzeigen")
    }
}
