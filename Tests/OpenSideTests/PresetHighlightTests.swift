import XCTest
import CoreGraphics
@testable import OpenSideCore

/// 눌러 둔 프리셋 표시는 저장된 값이 아니라 실제 배치를 따라야 한다.
/// 배치는 시스템 설정이나 다른 빌드에서도 바뀌므로, 저장값만 믿으면 엉뚱한 칸이 켜진다.
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

    /// 저장된 값이 있어도 실제 자리가 다르면 아무 칸도 켜지 않는다.
    @MainActor
    func testHighlightsNothingWhenTheLayoutMatchesNoPreset() {
        // iPad 가 주 화면 오른쪽 (1512, 240). leftBottom 이면 (-1112, 148) 이어야 한다.
        let viewModel = makeViewModel(sidecarOrigin: CGPoint(x: 1512, y: 240), stored: .leftBottom)
        XCTAssertNil(viewModel.lastAppliedPreset, "저장값이 실제와 다르면 켜면 안 된다")
    }

    /// 실제 자리가 프리셋과 맞으면 그 칸을 켠다.
    @MainActor
    func testHighlightsThePresetTheLayoutActuallyMatches() {
        // leftBottom: x = -1112, y = 982 - 834 = 148
        let viewModel = makeViewModel(sidecarOrigin: CGPoint(x: -1112, y: 148), stored: nil)
        XCTAssertEqual(viewModel.lastAppliedPreset, .leftBottom,
                       "저장값이 없어도 자리가 맞으면 켜야 한다")
    }
}
