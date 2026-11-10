import BackupDomain
import SwiftUI

struct ActivityView: View {
    @Environment(AgentConnection.self) private var connection

    var body: some View {
        let entries = ActivityEntry.entries(runs: connection.state?.runs ?? [], plans: connection.state?.plans ?? [])
        Table(entries) {
            TableColumn("Zeitpunkt") { entry in Text(entry.date, format: .dateTime) }
            TableColumn("Vorgang") { entry in Text(Self.title(entry.kind)) }
            TableColumn("Backup-Plan") { entry in Text(planName(entry)) }
            TableColumn("Ergebnis") { entry in
                Label(Self.result(entry.result), systemImage: Self.symbol(entry.result))
                    .foregroundStyle(entry.result.isFailure ? Color(.systemRed) : .primary)
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Noch keine Sicherungen", systemImage: "clock",
                    description: Text("Starte dein erstes Backup über „Jetzt sichern“."))
            }
        }
    }

    private func planName(_ entry: ActivityEntry) -> String {
        let configuration = connection.state?.configuration
        if let id = entry.planID, let plan = configuration?.plans.first(where: { $0.id == id }) { return plan.name }
        if let repository = configuration?.repositories.first(where: { $0.id == entry.repositoryID }) {
            return repository.name
        }
        return String(localized: "Gelöscht")
    }

    static func title(_ kind: ActivityEntry.Kind) -> String {
        switch kind {
        case .backup: String(localized: "Backup")
        case .verification: String(localized: "Integritätsprüfung")
        case .testRestore: String(localized: "Testwiederherstellung")
        case .maintenance: String(localized: "Wartung")
        }
    }

    static func result(_ result: ActivityEntry.Result) -> String {
        switch result {
        case .run(let outcome): AgentConnection.outcome(outcome)
        case .succeeded: String(localized: "Erfolgreich")
        case .failed: String(localized: "Fehlgeschlagen")
        }
    }

    private static func symbol(_ result: ActivityEntry.Result) -> String {
        switch result {
        case .succeeded, .run(.succeeded): "checkmark.circle"
        case .failed, .run(.failed): "xmark.octagon"
        case .run(.running): "arrow.triangle.2.circlepath"
        case .run(.succeededWithWarnings): "exclamationmark.triangle"
        case .run(.skipped), .run(.cancelled): "minus.circle"
        }
    }
}

#Preview { ActivityView().environment(PreviewData.connection(critical: true)) }
#Preview("Leer") { ActivityView().environment(PreviewData.connection(empty: true)) }
