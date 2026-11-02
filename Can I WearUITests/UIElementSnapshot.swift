import XCTest

extension XCUIElement {
    /// Keep XCTest's bounded wait for late elements, without its polling delay for an existing one.
    @MainActor
    func existsOrWait(timeout: TimeInterval) -> Bool {
        exists || waitForExistence(timeout: timeout)
    }
}

/// A single public XCTest snapshot for assertions on an unchanged screen.
/// Create a new value after navigation, scrolling, rotation or any other UI change.
@MainActor
struct UIElementSnapshot {
    let root: any XCUIElementSnapshot
    private let descendants: [any XCUIElementSnapshot]

    init(_ scope: XCUIElement) throws {
        self.init(try scope.snapshot())
    }

    /// Re-scope an already captured screen without another accessibility round trip.
    init(_ root: any XCUIElementSnapshot) {
        self.root = root
        var pending = root.children
        var descendants: [any XCUIElementSnapshot] = []
        while let child = pending.popLast() {
            descendants.append(child)
            pending.append(contentsOf: child.children)
        }
        self.descendants = descendants
    }

    func element(
        _ identifier: String, file: StaticString = #filePath, line: UInt = #line
    ) throws -> any XCUIElementSnapshot {
        let matches = descendants.filter { $0.identifier == identifier }
        // Retain the live query's existence and unique-match requirements, not just its first match.
        XCTAssertEqual(matches.count, 1, "Expected exactly one \(identifier) in this scope", file: file, line: line)
        return try XCTUnwrap(matches.first, "Missing \(identifier) in this scope", file: file, line: line)
    }

    func contains(_ identifier: String) -> Bool {
        descendants.contains { $0.identifier == identifier }
    }
}
