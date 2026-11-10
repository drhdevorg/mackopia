import BackupDomain
import Foundation
import Testing

struct SourceListEditTests {
    private func source(_ path: String) throws -> BackupSource {
        try BackupSource(
            path: path,
            volume: VolumeIdentity(uuid: UUID().uuidString, name: "Test", isRemovable: false, isNetwork: false))
    }

    @Test func addingKeepsOrderAndIgnoresDuplicatePaths() throws {
        let a = try source("/A"), b = try source("/B")
        let result = SourceListEdit.adding([try source("/A"), b, try source("/B"), try source("/C")], to: [a])
        #expect(result.map(\.path) == ["/A", "/B", "/C"])
        #expect(result.first == a)
    }

    @Test func addingStopsAtPlanLimit() throws {
        let existing = try (0..<SourceListEdit.maximumSources).map { try source("/S\($0)") }
        #expect(SourceListEdit.adding([try source("/Extra")], to: existing).count == SourceListEdit.maximumSources)
    }

    @Test func removingNeverLeavesPlanEmpty() throws {
        let a = try source("/A"), b = try source("/B")
        #expect(SourceListEdit.removing([a.id, b.id], from: [a, b]) == nil)
        #expect(SourceListEdit.removing([a.id], from: [a]) == nil)
        #expect(SourceListEdit.removing([UUID()], from: [a, b]) == nil)
        #expect(SourceListEdit.removing([], from: [a, b]) == nil)
    }

    @Test func undoRestoresFormerPositions() throws {
        let sources = try ["/A", "/B", "/C", "/D"].map(source)
        let edit = try #require(SourceListEdit.removing([sources[0].id, sources[2].id], from: sources))
        #expect(edit.sources.map(\.path) == ["/B", "/D"])
        #expect(edit.removals.map(\.index) == [0, 2])
        #expect(SourceListEdit.restoring(edit.removals.reversed(), into: edit.sources) == sources)
    }

    @Test func undoDoesNotDuplicateReaddedPathAndClampsIndex() throws {
        let sources = try ["/A", "/B", "/C"].map(source)
        let edit = try #require(SourceListEdit.removing([sources[2].id], from: sources))
        let readded = SourceListEdit.adding([try source("/C")], to: edit.sources)
        #expect(SourceListEdit.restoring(edit.removals, into: readded).map(\.path) == ["/A", "/B", "/C"])
        let shrunk = [sources[0]]
        #expect(SourceListEdit.restoring(edit.removals, into: shrunk).map(\.path) == ["/A", "/C"])
    }
}
