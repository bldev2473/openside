import XCTest
import CoreGraphics
@testable import OpenSideCore

final class DisplayAnchorTests: XCTestCase {

    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)

    /// Display attached to the left edge and vertically centered.
    func testReadsTheLeftEdgeAndTheSpotAlongIt() {
        let target = CGRect(x: -1112, y: 74, width: 1112, height: 834)
        let anchor = DisplayAnchor.from(mainBounds: main, targetBounds: target)
        XCTAssertEqual(anchor.edge, .left)
        XCTAssertEqual(anchor.ratio, 0.5, accuracy: 0.01)
    }

    /// Must return to the same relative position even when screen size changes. Using raw coordinates misaligns.
    func testKeepsTheSameSpotWhenTheScreenGrows() {
        let small = CGRect(x: -1112, y: 74, width: 1112, height: 834)
        let anchor = DisplayAnchor.from(mainBounds: main, targetBounds: small)

        let big = CGRect(x: 0, y: 0, width: 1920, height: 1440)
        let origin = anchor.origin(mainBounds: main, targetBounds: big)

        XCTAssertEqual(origin.x, -1920, "Must attach to the left edge")
        XCTAssertEqual(Double(origin.y) + 1440 / 2, 982 * 0.5, accuracy: 1,
                       "Center must align with the same height on the main screen")
    }

    /// Position along the edge must also be preserved regardless of size.
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
