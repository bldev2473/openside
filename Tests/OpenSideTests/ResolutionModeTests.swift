import XCTest
@testable import OpenSideCore

/// Unit test class for display resolution model and sorting logic.
final class ResolutionModeTests: XCTestCase {

    /// Verifies resolution text formatting (standard vs HiDPI).
    func testResolutionFormatting() {
        let standardMode = DisplayResolutionMode(
            width: 1024,
            height: 768,
            pixelWidth: 1024,
            pixelHeight: 768,
            refreshRate: 60.0,
            isHiDPI: false,
            isCurrent: false
        )
        XCTAssertEqual(standardMode.formattedText, "1024 × 768")

        let hidpiMode = DisplayResolutionMode(
            width: 1112,
            height: 834,
            pixelWidth: 2224,
            pixelHeight: 1668,
            refreshRate: 60.0,
            isHiDPI: true,
            isCurrent: true
        )
        XCTAssertEqual(hidpiMode.formattedText, "1112 × 834 (HiDPI)")
        XCTAssertTrue(hidpiMode.isCurrent)
    }

    // MARK: - Display Mode Selection
    //
    // The tests below invoke production logic directly. Previously, sorted and filter operations
    // were duplicated inside test code, causing tests to remain green even if production rules changed.

    private func raw(_ w: Int, _ h: Int, px: Int? = nil, py: Int? = nil) -> RawDisplayMode {
        RawDisplayMode(width: w, height: h,
                       pixelWidth: px ?? w, pixelHeight: py ?? h, refreshRate: 60)
    }

    /// Drops modes below 800x600 floor as unusable; boundary values are preserved.
    func testDropsModesBelowTheUsableFloor() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(400, 300), raw(640, 480), raw(800, 600), raw(1024, 768)],
            current: nil
        )
        XCTAssertEqual(picked.map(\.width), [800, 1024])
    }

    /// Drops modes insufficient on either width or height.
    func testDropsModesShortOnEitherSide() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(1024, 500), raw(700, 900), raw(1024, 768)],
            current: nil
        )
        XCTAssertEqual(picked.map(\.width), [1024])
        XCTAssertEqual(picked.first?.height, 768)
    }

    /// Deduplicates identical logical sizes and prefers higher pixel counts (HiDPI).
    func testKeepsOneEntryPerLogicalSizeAndPrefersHiDPI() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(1112, 834), raw(1112, 834, px: 2224, py: 1668)],
            current: nil
        )
        XCTAssertEqual(picked.count, 1)
        XCTAssertEqual(picked[0].pixelWidth, 2224)
        XCTAssertTrue(picked[0].isHiDPI)
    }

    /// Current active mode takes priority even with fewer pixels; active value must not disappear from list.
    func testTheCurrentModeWinsEvenWithFewerPixels() {
        let current = raw(1112, 834)
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(1112, 834, px: 2224, py: 1668), current],
            current: current
        )
        XCTAssertEqual(picked.count, 1)
        XCTAssertEqual(picked[0].pixelWidth, 1112)
        XCTAssertTrue(picked[0].isCurrent)
        XCTAssertFalse(picked[0].isHiDPI)
    }

    /// Sorts ascending by width, then ascending by height.
    func testSortsByWidthThenHeight() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(1280, 960), raw(800, 600), raw(1112, 834), raw(1280, 1024)],
            current: nil
        )
        XCTAssertEqual(picked.map { "\($0.width)x\($0.height)" },
                       ["800x600", "1112x834", "1280x960", "1280x1024"])
    }

    /// Returns empty list if no modes qualify, avoiding optional handling at call sites.
    func testReturnsNothingWhenEverythingIsTooSmall() {
        XCTAssertTrue(CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(640, 480), raw(400, 300)], current: nil).isEmpty)
    }
}
