import XCTest
import CoreGraphics
@testable import OpenSideCore

final class DisplayAnchorTests: XCTestCase {

    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)

    /// 왼쪽에 붙여 세로 가운데에 둔 화면.
    func testReadsTheLeftEdgeAndTheSpotAlongIt() {
        let target = CGRect(x: -1112, y: 74, width: 1112, height: 834)
        let anchor = DisplayAnchor.from(mainBounds: main, targetBounds: target)
        XCTAssertEqual(anchor.edge, .left)
        XCTAssertEqual(anchor.ratio, 0.5, accuracy: 0.01)
    }

    /// 크기가 달라져도 같은 자리로 돌아와야 한다. 좌표를 그대로 쓰면 어긋난다.
    func testKeepsTheSameSpotWhenTheScreenGrows() {
        let small = CGRect(x: -1112, y: 74, width: 1112, height: 834)
        let anchor = DisplayAnchor.from(mainBounds: main, targetBounds: small)

        let big = CGRect(x: 0, y: 0, width: 1920, height: 1440)
        let origin = anchor.origin(mainBounds: main, targetBounds: big)

        XCTAssertEqual(origin.x, -1920, "왼쪽 변에 붙어야 한다")
        XCTAssertEqual(Double(origin.y) + 1440 / 2, 982 * 0.5, accuracy: 1,
                       "중심이 주 화면의 같은 높이에 와야 한다")
    }

    /// 변을 따라간 위치도 크기와 무관하게 유지되어야 한다.
    func testKeepsAnOffCentreSpot() {
        let target = CGRect(x: -1112, y: 0, width: 1112, height: 834)
        let anchor = DisplayAnchor.from(mainBounds: main, targetBounds: target)

        let big = CGRect(x: 0, y: 0, width: 1920, height: 1440)
        let origin = anchor.origin(mainBounds: main, targetBounds: big)

        XCTAssertEqual(Double(origin.y) + 1440 / 2, 982 * anchor.ratio, accuracy: 1)
    }

    func testReadsTheRightEdge() {
        let target = CGRect(x: 1512, y: 100, width: 1112, height: 834)
        XCTAssertEqual(DisplayAnchor.from(mainBounds: main, targetBounds: target).edge, .right)
    }

    func testReadsTheBottomEdge() {
        let target = CGRect(x: 200, y: 982, width: 1112, height: 834)
        XCTAssertEqual(DisplayAnchor.from(mainBounds: main, targetBounds: target).edge, .bottom)
    }

    func testReadsTheTopEdge() {
        let target = CGRect(x: 200, y: -834, width: 1112, height: 834)
        XCTAssertEqual(DisplayAnchor.from(mainBounds: main, targetBounds: target).edge, .top)
    }
}
