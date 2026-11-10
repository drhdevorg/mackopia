import BackupDomain
import Foundation
import Testing

@Suite struct ActivityEntryTests {
    let repository = UUID()
    let planA = UUID()
    let planB = UUID()

    func run(_ plan: UUID, at seconds: TimeInterval, _ outcome: JobRun.Outcome) -> JobRun {
        JobRun(
            id: UUID(), planID: plan, repositoryID: repository, trigger: .manual,
            startedAt: Date(timeIntervalSince1970: seconds), endedAt: Date(timeIntervalSince1970: seconds + 1),
            outcome: outcome, sources: [], issues: [])
    }

    func check(
        _ plan: UUID, _ kind: VerificationResult.Kind, at seconds: TimeInterval, failed: Bool
    )
        -> VerificationResult
    {
        VerificationResult(
            planID: plan, repositoryID: repository, kind: kind, startedAt: Date(timeIntervalSince1970: seconds),
            endedAt: Date(timeIntervalSince1970: seconds + 5), dueAt: Date(timeIntervalSince1970: seconds + 99),
            outcome: failed ? .failed : .succeeded)
    }

    func runtime(
        _ plan: UUID, verification: VerificationResult? = nil, testRestore: VerificationResult? = nil,
        maintenance: MaintenanceResult? = nil
    ) -> PlanRuntimeState {
        PlanRuntimeState(
            planID: plan, nextRun: nil, pause: nil,
            health: HealthAssessment(planID: plan, lastSuccessfulBackup: nil, reasons: []),
            verification: verification, testRestore: testRestore, maintenance: maintenance)
    }

    @Test func failedChecksAppearNextToRunsNewestFirst() {
        let backup = run(planA, at: 100, .succeeded)
        let entries = ActivityEntry.entries(
            runs: [backup],
            plans: [
                runtime(
                    planA, verification: check(planA, .snapshotVerify, at: 300, failed: true),
                    testRestore: check(planA, .testRestore, at: 200, failed: false))
            ])
        #expect(entries.map(\.kind) == [.verification, .testRestore, .backup])
        #expect(entries.map(\.result) == [.failed, .succeeded, .run(.succeeded)])
        #expect(entries[0].result.isFailure && !entries[1].result.isFailure)
        #expect(entries.allSatisfy { $0.planID == planA })
    }

    @Test func sharedMaintenanceAppearsOnceWithoutPlan() {
        let shared = MaintenanceResult(
            repositoryID: repository, endedAt: Date(timeIntervalSince1970: 50), outcome: .failed)
        let own = MaintenanceResult(
            repositoryID: repository, endedAt: Date(timeIntervalSince1970: 40), outcome: .succeeded)
        let entries = ActivityEntry.entries(
            runs: [], plans: [runtime(planA, maintenance: shared), runtime(planB, maintenance: shared)])
        #expect(entries.count == 1)
        #expect(entries.first?.planID == nil && entries.first?.result == .failed)
        let single = ActivityEntry.entries(runs: [], plans: [runtime(planA, maintenance: own)])
        #expect(single.first?.planID == planA)
    }

    @Test func emptyStateHasNoEntries() {
        #expect(ActivityEntry.entries(runs: [], plans: [runtime(planA)]).isEmpty)
        #expect(ActivityEntry.Result.run(.failed).isFailure)
        #expect(!ActivityEntry.Result.run(.cancelled).isFailure)
    }

    @Test func activeWorkDefaultsToBackupOnlyWhileAPlanIsActive() {
        #expect(LocalServiceState(configuration: nil, activePlanID: planA).activeWork == .backup)
        #expect(
            LocalServiceState(configuration: nil, activePlanID: planA, activeWork: .verification).activeWork
                == .verification)
        #expect(LocalServiceState(configuration: nil, activeWork: .verification).activeWork == nil)
    }
}
