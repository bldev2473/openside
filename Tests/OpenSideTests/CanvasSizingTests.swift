import XCTest
import CoreGraphics
@testable import OpenSideCore

/// Users should be able to select resolutions from the menu bar even while using a canvas.
/// However, what is selected is the canvas size rather than the iPad's display mode.
final class CanvasSizingTests: XCTestCase {

    static let small = DisplayResolutionMode(
        width: 1112, height: 834, pixelWidth: 2224, pixelHeight: 1668,
        refreshRate: 60, isHiDPI: true, isCurrent: true)
    static let large = DisplayResolutionMode(
        width: 1920, height: 1440, pixelWidth: 3840, pixelHeight: 2880,
        refreshRate: 60, isHiDPI: true, isCurrent: false)

    final class StubSizing: CanvasSizing, @unchecked Sendable {
        var chosen: DisplayResolutionMode?
        var availableCanvasSizes: [DisplayResolutionMode] { [CanvasSizingTests.small, CanvasSizingTests.large] }
        var currentCanvasSize: DisplayResolutionMode? { CanvasSizingTests.small }
        func selectCanvasSize(_ mode: DisplayResolutionMode) { chosen = mode }
    }

    @MainActor
    private func makeViewModel(
        detector: DisplayDetecting,
        sizing: CanvasSizing?,
        managed: CGDirectDisplayID?
    ) -> DisplayManagerViewModel {
        DisplayManagerViewModel(
            detector: detector,
            readinessChecker: ManagedDisplayTests.QuietChecker(),
            managedDisplays: ManagedDisplayTests.StubManaged(managed),
            canvasSizing: sizing
        )
    }

    @MainActor
    func testOffersTheCanvasSizesWhileTheCanvasIsShowing() {
        let viewModel = makeViewModel(
            detector: ManagedDisplayTests.TwoDisplayDetector(), sizing: StubSizing(), managed: 3)
        XCTAssertTrue(viewModel.isShowingCanvas)
        XCTAssertEqual(viewModel.availableCanvasSizes.map(\.width), [1112, 1920])
        XCTAssertEqual(viewModel.currentCanvasSize?.width, 1112)
    }

    /// When not mirroring a canvas, this list should be empty. A separate control selects iPad native mode.
    @MainActor
    func testOffersNothingWhileTheCanvasIsNotShowing() {
        let viewModel = makeViewModel(
            detector: ManagedDisplayTests.UnmirroredCanvasDetector(), sizing: StubSizing(), managed: 3)
        XCTAssertFalse(viewModel.isShowingCanvas)
        XCTAssertTrue(viewModel.availableCanvasSizes.isEmpty)
    }

    @MainActor
    func testPassesTheChosenSizeToTheCanvas() {
        let sizing = StubSizing()
        let viewModel = makeViewModel(
            detector: ManagedDisplayTests.TwoDisplayDetector(), sizing: sizing, managed: 3)
        viewModel.changeCanvasSize(Self.large)
        XCTAssertEqual(sizing.chosen?.width, 1920)
    }
}
