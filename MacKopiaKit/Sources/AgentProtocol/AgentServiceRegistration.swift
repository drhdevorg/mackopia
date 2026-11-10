import ServiceManagement

/// App-side lifecycle boundary. Registration is explicit, never a side effect of reading status.
@MainActor
public struct AgentServiceRegistration {
    public enum Status: Sendable, Equatable { case notRegistered, enabled, requiresApproval, notFound }
    private let service: any AgentServiceManaging
    private let validateSignature: () throws -> Void

    public init(identity: AgentServiceIdentity) {
        service = SystemAgentService(service: .agent(plistName: identity.plistName))
        validateSignature = { _ = try AgentSigningIdentity.peerRequirement(identity: identity, role: .app) }
    }

    // Internal injection is only for tests; the public initializer always verifies the running signature.
    init(service: any AgentServiceManaging, validateSignature: @escaping () throws -> Void) {
        self.service = service
        self.validateSignature = validateSignature
    }

    public var status: Status { service.status }

    /// Returns the resulting status. `.requiresApproval` means macOS keeps the service off until the user
    /// allows it under Login Items; callers must say so instead of treating the request as done.
    @discardableResult public func register() throws -> Status {
        try validateSignature()
        switch status {
        case .enabled, .requiresApproval: return status
        case .notRegistered, .notFound:
            // macOS can report a missing BTM record before the first registration even when the
            // sealed bundle contains the service. Let SMAppService validate the explicit request.
            do { try service.register() } catch {
                // SMAppService may report launch denial after recording a request for user approval.
                guard status == .requiresApproval else { throw AgentServiceError.registrationFailed }
            }
            return status
        }
    }

    /// Explicit repair for an "enabled" record whose launchd job is missing or cannot start (observed on
    /// macOS 27 after the user re-allowed background activity: launchd reported EX_CONFIG because the job had
    /// lost its bundle association). Only an already enabled service is re-registered; other states keep the
    /// normal path. The caller invokes this solely on an explicit user action while the service is unreachable.
    @discardableResult public func repair() async throws -> Status {
        try validateSignature()
        guard status == .enabled else { return try register() }
        do { try await service.unregister() } catch { throw AgentServiceError.registrationFailed }
        return try register()
    }

    public func openLoginItemsSettings() { service.openLoginItemsSettings() }
}
