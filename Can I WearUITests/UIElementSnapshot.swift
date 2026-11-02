import XCTest

/// A single public XCTest snapshot for assertions on an unchanged screen.
/// Create a new value after navigation, scrolling, rotation or any other UI change.
@MainActor
struct UIElementSnapshot {
    private let descendants: [any XCUIElementSnapshot]

    init(_ scope: XCUIElement) throws {
        let root = try scope.snapshot()
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
