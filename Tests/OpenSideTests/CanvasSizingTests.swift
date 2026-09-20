import XCTest
import CoreGraphics
@testable import OpenSideCore

/// 캔버스를 쓰는 동안에도 메뉴바에서 해상도를 고를 수 있어야 한다.
/// 다만 고르는 것은 iPad 의 모드가 아니라 캔버스의 크기다.
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

    /// 캔버스를 안 비추면 이 목록은 비어 있어야 한다. iPad 자기 모드를 고르는 칸이 따로 있다.
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
