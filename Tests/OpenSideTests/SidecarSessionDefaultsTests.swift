import XCTest
@testable import OpenSideCore

final class SidecarSessionDefaultsTests: XCTestCase {

    /// 실제 시스템 값을 건드리는 시험이다. 끝나면 원래대로 돌려놓는다.
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
            XCTAssertEqual(store.showsTouchBar, value, "쓴 값이 그대로 읽혀야 한다")
            store.setShowsSidebar(value)
            XCTAssertEqual(store.showsSidebar, value)
        }
    }
}
