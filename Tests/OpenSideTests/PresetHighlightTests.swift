import XCTest
import CoreGraphics
@testable import OpenSideCore

/// Active preset highlight must track the actual arrangement rather than a cached storage value.
/// Displays can be repositioned via System Settings or other tools, so trusting storage alone highlights wrong cells.
final class PresetHighlightTests: XCTestCase {

    final class LayoutDetector: DisplayDetecting, @unchecked Sendable {
        var sidecarOrigin: CGPoint
        init(sidecarOrigin: CGPoint) { self.sidecarOrigin = sidecarOrigin }

        var main: DisplayInfo {
            DisplayInfo(id: 1, uuid: "M", name: "Built-in",
                        bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
                        isMain: true, isBuiltin: true, isSidecar: false)
        }
        var sidecar: DisplayInfo {
            DisplayInfo(id: 2, uuid: "S", name: "Sidecar Display (AirPlay)",
                        bounds: CGRect(x: sidecarOrigin.x, y: sidecarOrigin.y, width: 1112, height: 834),
                        isMain: false, isBuiltin: false, isSidecar: true)
        }
        func getActiveDisplays() -> [DisplayInfo] { [main, sidecar] }
        func getSidecarDisplay() -> DisplayInfo? { sidecar }
        func getMainDisplay() -> DisplayInfo? { main }
    }

    @MainActor
    private func makeViewModel(sidecarOrigin: CGPoint, stored: DisplayArrangementPreset?)
        -> DisplayManagerViewModel {
        let presets = CustomArrangementPersistenceTests.SpyPresetManager()
        presets.stored = stored
        return DisplayManagerViewModel(
            detector: LayoutDetector(sidecarOrigin: sidecarOrigin),
            presetManager: presets,
            readinessChecker: ManagedDisplayTests.QuietChecker()
        )
    }

    /// Highlights nothing when actual layout matches no preset even if storage has a value.
    @MainActor
    func testHighlightsNothingWhenTheLayoutMatchesNoPreset() {
        // iPad placed at right (1512, 240); leftBottom requires (-1112, 148).
        let viewModel = makeViewModel(sidecarOrigin: CGPoint(x: 1512, y: 240), stored: .leftBottom)
        XCTAssertNil(viewModel.lastAppliedPreset, "Must not highlight if stored value differs from actual layout")
    }

    /// Highlights the preset that the layout actually matches.
    @MainActor
    func testHighlightsThePresetTheLayoutActuallyMatches() {
        // leftBottom: x = -1112, y = 982 - 834 = 148
        let viewModel = makeViewModel(sidecarOrigin: CGPoint(x: -1112, y: 148), stored: nil)
        XCTAssertEqual(viewModel.lastAppliedPreset, .leftBottom,
                       "Must highlight matching layout even without stored preset")
    }
}
