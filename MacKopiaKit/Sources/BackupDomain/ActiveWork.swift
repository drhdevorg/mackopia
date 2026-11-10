/// What the service is doing for `LocalServiceState.activePlanID`, so the UI never calls a check a backup.
public enum ActiveWork: String, Codable, Sendable, Equatable {
    /// A backup run owns the plan.
    case backup
    /// An explicitly requested integrity check is running.
    case verification
    /// Post-backup checks, test restore or maintenance run after a backup.
    case finishing
    /// Work is queued and waits for the single drain owner.
    case queued
}
