import Testing

@testable import AgentProtocol

@MainActor
private final class FakeService: AgentServiceManaging {
    var status: AgentServiceRegistration.Status = .notRegistered
    var registerCalls = 0
    var unregisterCalls = 0
    var unregisterFailure: AgentServiceError?
    var settingsCalls = 0
    var failure: AgentServiceError?
    var afterRegister: AgentServiceRegistration.Status = .enabled

    func register() throws {
        registerCalls += 1
        status = afterRegister
        if let failure { throw failure }
    }

    func unregister() async throws {
        unregisterCalls += 1
        if let unregisterFailure { throw unregisterFailure }
        status = .notRegistered
    }

    func openLoginItemsSettings() { settingsCalls += 1 }
}

@Test @MainActor func readingServiceStatusDoesNotRegister() {
    let service = FakeService()
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    #expect(registration.status == .notRegistered)
    #expect(service.registerCalls == 0)
    registration.openLoginItemsSettings()
    #expect(service.settingsCalls == 1)
}

@Test @MainActor func signatureFailureNeverReachesServiceManager() {
    let service = FakeService()
    let registration = AgentServiceRegistration(service: service) { throw AgentServiceError.signingRequired }
    #expect(throws: AgentServiceError.signingRequired) { try registration.register() }
    #expect(service.registerCalls == 0)
}

@Test @MainActor func enabledOrPendingRegistrationIsNotRepeated() throws {
    let service = FakeService()
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    try registration.register()
    #expect(registration.status == .enabled)
    try registration.register()
    #expect(service.registerCalls == 1)
    service.status = .requiresApproval
    try registration.register()
    #expect(service.registerCalls == 1)
}

@Test @MainActor func pendingApprovalRemainsActionableAfterLaunchDenial() throws {
    let service = FakeService()
    service.afterRegister = .requiresApproval
    service.failure = .unavailable
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    try registration.register()
    #expect(registration.status == .requiresApproval)
    #expect(service.registerCalls == 1)
}

@Test @MainActor func missingJobAndRegistrationFailuresAreTyped() {
    let service = FakeService()
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    service.status = .notRegistered
    service.afterRegister = .notRegistered
    service.failure = .invalidReply
    #expect(throws: AgentServiceError.registrationFailed) { try registration.register() }
    #expect(service.registerCalls == 1)
}

@Test @MainActor func missingStatusStillAllowsExplicitRegistration() throws {
    let service = FakeService()
    service.status = .notFound
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    try registration.register()
    #expect(service.registerCalls == 1)
    #expect(registration.status == .enabled)
}

@Test @MainActor func missingServiceRegistrationStillReportsSystemFailure() {
    let service = FakeService()
    service.status = .notFound
    service.afterRegister = .notFound
    service.failure = .unavailable
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    #expect(throws: AgentServiceError.registrationFailed) { try registration.register() }
    #expect(service.registerCalls == 1)
}

@Test @MainActor func backgroundApprovalIsReportedForExistingAndNewRegistrations() throws {
    let service = FakeService()
    service.status = .requiresApproval
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    #expect(try registration.register() == .requiresApproval)
    #expect(service.registerCalls == 0)
    service.status = .notRegistered
    service.afterRegister = .requiresApproval
    #expect(try registration.register() == .requiresApproval)
    service.afterRegister = .enabled
    service.status = .notRegistered
    #expect(try registration.register() == .enabled)
}

@Test @MainActor func repairReregistersOnlyAnEnabledService() async throws {
    let service = FakeService()
    service.status = .enabled
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    #expect(try await registration.repair() == .enabled)
    #expect(service.unregisterCalls == 1)
    #expect(service.registerCalls == 1)

    service.status = .requiresApproval
    #expect(try await registration.repair() == .requiresApproval)
    #expect(service.unregisterCalls == 1)
    #expect(service.registerCalls == 1)
}

@Test @MainActor func repairChecksSignatureAndTypesUnregisterFailure() async {
    let service = FakeService()
    service.status = .enabled
    let unsigned = AgentServiceRegistration(service: service) { throw AgentServiceError.signingRequired }
    await #expect(throws: AgentServiceError.signingRequired) { try await unsigned.repair() }
    #expect(service.unregisterCalls == 0)

    service.unregisterFailure = .unavailable
    let registration = AgentServiceRegistration(service: service, validateSignature: {})
    await #expect(throws: AgentServiceError.registrationFailed) { try await registration.repair() }
    #expect(service.registerCalls == 0)
}
