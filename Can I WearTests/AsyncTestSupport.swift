import Foundation
@testable import Can_I_Wear

enum TestWaitError: Error, Equatable, CustomStringConvertible {
    case timedOut(String)

    var description: String {
        switch self {
        case .timedOut(let condition): "Timed out waiting for \(condition)"
        }
    }
}

/// Predicates only inspect state; the deadline bounds synchronization, not app behavior.
@MainActor
func waitUntil(
    _ description: String,
    timeout: Duration = .seconds(5),
    _ condition: @MainActor () async -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while true {
        try Task.checkCancellation()
        if await condition() { return }
        guard ContinuousClock.now < deadline else { throw TestWaitError.timedOut(description) }
        try await Task.sleep(for: .milliseconds(1))
    }
}

@MainActor
struct StubGeocodingResolver: LocalityResolving, PlaceResolving {
    func locality(for location: LocationIdentity) async -> String? { "Test locality" }
    func place(for location: LocationIdentity) async -> String? { "Test place" }
}

/// No standard-domain settings, disk-backed event store, or system place resolver.
@MainActor
func makeTestDiagnostics() -> DebugDiagnostics {
    // Only registered defaults are used: this suite writes no persistent preferences.
    let defaults = UserDefaults(suiteName: "TestDiagnostics.\(UUID().uuidString)")!
    return DebugDiagnostics(
        settings: DebugSettings(defaults: defaults), eventStore: StubDiagnosticEventStore(),
        placeResolver: StubGeocodingResolver()
    )
}

@MainActor
private final class StubDiagnosticEventStore: DiagnosticEventPersisting {
    func load() -> [DiagnosticEvent] { [] }
    func save(_ events: [DiagnosticEvent]) {}
    func clear() {}
}
