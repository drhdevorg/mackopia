import Foundation

/// One row of the activity list: backup runs plus the latest trust checks and maintenance per plan.
/// Holds only fixed facts that already cross XPC; no paths or diagnostics.
public struct ActivityEntry: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable { case backup, verification, testRestore, maintenance }
    public enum Result: Sendable, Hashable {
        case run(JobRun.Outcome)
        case succeeded, failed

        public var isFailure: Bool {
            switch self {
            case .failed, .run(.failed): true
            default: false
            }
        }
    }

    public let id: UUID
    public let kind: Kind
    public let date: Date
    /// Nil for maintenance shared by several plans of one destination.
    public let planID: UUID?
    public let repositoryID: UUID
    public let result: Result

    public init(id: UUID, kind: Kind, date: Date, planID: UUID?, repositoryID: UUID, result: Result) {
        self.id = id; self.kind = kind; self.date = date; self.planID = planID
        self.repositoryID = repositoryID; self.result = result
    }

    /// Newest first. Maintenance belongs to a destination, so one result reported by several plans appears once.
    public static func entries(runs: [JobRun], plans: [PlanRuntimeState]) -> [ActivityEntry] {
        var entries = runs.map {
            ActivityEntry(
                id: $0.id, kind: .backup, date: $0.startedAt, planID: $0.planID, repositoryID: $0.repositoryID,
                result: .run($0.outcome))
        }
        var seen = Set(entries.map(\.id))
        func append(_ entry: ActivityEntry) { if seen.insert(entry.id).inserted { entries.append(entry) } }
        for plan in plans {
            for check in [plan.verification, plan.testRestore].compactMap(\.self) {
                append(
                    ActivityEntry(
                        id: check.id, kind: check.kind == .snapshotVerify ? .verification : .testRestore,
                        date: check.startedAt, planID: check.planID, repositoryID: check.repositoryID,
                        result: check.outcome == .succeeded ? .succeeded : .failed))
            }
            if let maintenance = plan.maintenance {
                let sharing = plans.filter { $0.maintenance?.id == maintenance.id }.count
                append(
                    ActivityEntry(
                        id: maintenance.id, kind: .maintenance, date: maintenance.endedAt,
                        planID: sharing == 1 ? plan.planID : nil, repositoryID: maintenance.repositoryID,
                        result: maintenance.outcome == .succeeded ? .succeeded : .failed))
            }
        }
        return entries.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date > $1.date }
    }
}
