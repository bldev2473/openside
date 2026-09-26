import XCTest
@testable import OpenSideCore

final class SidecarSessionDefaultsTests: XCTestCase {

    /// This test modifies actual system preferences and restores them upon completion.
    func testWritingIsReadBack() throws {
        let store = SystemSidecarSessionDefaults()
        let originalTouchBar = store.showsTouchBar
        let originalSidebar = store.showsSidebar
        defer {
            if let originalTouchBar { store.setShowsTouchBar(originalTouchBar) }
            if let originalSidebar { store.setShowsSidebar(originalSidebar) }
        }

        for value in [true, false] {
            store.setShowsTouchBar(value)
            XCTAssertEqual(store.showsTouchBar, value, "The written value should match the value read back")
            store.setShowsSidebar(value)
            XCTAssertEqual(store.showsSidebar, value)
        }
    }
}
