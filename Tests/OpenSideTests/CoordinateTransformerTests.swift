import XCTest
@testable import OpenSideCore

/// Unit test class for miniature coordinate transformer.
final class CoordinateTransformerTests: XCTestCase {
    private var transformer: MiniatureCoordinateTransformer!

    override func setUp() {
        super.setUp()
        transformer = MiniatureCoordinateTransformer()
    }

    override func tearDown() {
        transformer = nil
        super.tearDown()
    }

    /// Verifies conversion of drag translation coordinates into global system coordinates given canvas scale.
    func testTransformDragToTargetOrigin() {
        let initialOrigin = CGPoint(x: 1512, y: 635)
        let scale: CGFloat = 0.1 // 10x canvas downscale factor
        let dragTranslation = CGSize(width: 20.0, height: -15.0)

        // Expected delta: dx = 20 / 0.1 = +200, dy = -15 / 0.1 = -150
        // Expected target origin: (1512 + 200, 635 - 150) = (1712, 485)
        let result = transformer.transformDragToTargetOrigin(
            currentOrigin: initialOrigin,
            dragTranslation: dragTranslation,
            scale: scale
        )

        XCTAssertEqual(result.x, 1712)
        XCTAssertEqual(result.y, 485)
    }

    /// Verifies original origin preservation when drag translation is zero.
    func testZeroDragTranslationPreservesOrigin() {
        let initialOrigin = CGPoint(x: -1112, y: 74)
        let scale: CGFloat = 0.08
        let dragTranslation = CGSize.zero

        let result = transformer.transformDragToTargetOrigin(
            currentOrigin: initialOrigin,
            dragTranslation: dragTranslation,
            scale: scale
        )

        XCTAssertEqual(result.x, -1112)
        XCTAssertEqual(result.y, 74)
    }
}
