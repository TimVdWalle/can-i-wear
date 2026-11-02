import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct AsyncTestSupportTests {
    @Test func alreadySatisfiedWaitReturnsWithoutSuspending() async throws {
        try await waitUntil("an already satisfied condition", timeout: .zero) { true }
    }

    @Test func waitObservesAnAsynchronousStateChange() async throws {
        var completed = false
        let update = Task { @MainActor in
            try await Task.sleep(for: .milliseconds(10))
            completed = true
        }
        defer { update.cancel() }
        try await waitUntil("the scheduled update") { completed }
        try await update.value
        #expect(completed)
    }

    @Test(arguments: [Duration.zero, .milliseconds(10)])
    func unsatisfiedWaitThrowsADescriptiveTimeout(timeout: Duration) async {
        let error = TestWaitError.timedOut("a missing callback")
        await #expect(throws: error) {
            try await waitUntil("a missing callback", timeout: timeout) { false }
        }
        #expect(error.description == "Timed out waiting for a missing callback")
    }

    @Test(arguments: [false, true])
    func cancelledWaitExitsWithoutWaitingForItsDeadline(beforeWaiting: Bool) async throws {
        var started = false
        let wait = Task {
            try await waitUntil("a missing callback", timeout: .seconds(60)) {
                started = true
                return false
            }
        }
        defer { wait.cancel() }
        if !beforeWaiting {
            try await waitUntil("the cancellable wait to start") { started }
        }
        wait.cancel()
        await #expect(throws: CancellationError.self) { try await wait.value }
    }

    @Test func testDiagnosticsIgnoreTheStandardDebugPreference() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: DebugSettings.enabledKey)
        defer {
            if let original { defaults.set(original, forKey: DebugSettings.enabledKey) }
            else { defaults.removeObject(forKey: DebugSettings.enabledKey) }
        }
        // No suspension while temporarily editing the shared preference domain.
        defaults.set(true, forKey: DebugSettings.enabledKey)
        let diagnostics = makeTestDiagnostics()
        diagnostics.refreshSetting()
        #expect(!diagnostics.isEnabled)
        #expect(diagnostics.events.isEmpty)
    }
}
