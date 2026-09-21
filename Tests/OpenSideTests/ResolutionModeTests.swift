import XCTest
@testable import OpenSideCore

/// 디스플레이 해상도 모델 및 정렬 로직 단위 테스트 클래스
final class ResolutionModeTests: XCTestCase {

    /// 해상도 텍스트 포맷팅 검증 (일반 해상도 vs HiDPI)
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

    // MARK: - 보여줄 모드 고르기
    //
    // 아래 시험들은 제품 코드를 부릅니다. 예전에는 시험 안에서 직접 sorted 와 filter 를
    // 돌려 놓고 그 결과를 확인했는데, 그러면 제품 쪽 기준을 바꿔도 초록으로 남았습니다.

    private func raw(_ w: Int, _ h: Int, px: Int? = nil, py: Int? = nil) -> RawDisplayMode {
        RawDisplayMode(width: w, height: h,
                       pixelWidth: px ?? w, pixelHeight: py ?? h, refreshRate: 60)
    }

    /// 800x600 미만은 쓰기 어려워 목록에서 뺀다. 경계값은 남는다.
    func testDropsModesBelowTheUsableFloor() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(400, 300), raw(640, 480), raw(800, 600), raw(1024, 768)],
            current: nil
        )
        XCTAssertEqual(picked.map(\.width), [800, 1024])
    }

    /// 가로가 모자란 것도, 세로가 모자란 것도 뺀다.
    func testDropsModesShortOnEitherSide() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(1024, 500), raw(700, 900), raw(1024, 768)],
            current: nil
        )
        XCTAssertEqual(picked.map(\.width), [1024])
        XCTAssertEqual(picked.first?.height, 768)
    }

    /// 논리 해상도가 같으면 하나만 남기고, 픽셀이 많은 쪽(HiDPI)을 고른다.
    func testKeepsOneEntryPerLogicalSizeAndPrefersHiDPI() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(1112, 834), raw(1112, 834, px: 2224, py: 1668)],
            current: nil
        )
        XCTAssertEqual(picked.count, 1)
        XCTAssertEqual(picked[0].pixelWidth, 2224)
        XCTAssertTrue(picked[0].isHiDPI)
    }

    /// 지금 쓰는 모드는 픽셀이 적어도 이긴다. 목록에서 현재 값이 사라지면 안 된다.
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

    /// 가로 오름차순, 가로가 같으면 세로 오름차순.
    func testSortsByWidthThenHeight() {
        let picked = CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(1280, 960), raw(800, 600), raw(1112, 834), raw(1280, 1024)],
            current: nil
        )
        XCTAssertEqual(picked.map { "\($0.width)x\($0.height)" },
                       ["800x600", "1112x834", "1280x960", "1280x1024"])
    }

    /// 아무것도 못 고르면 빈 목록. 호출한 쪽이 nil 과 빈 것을 가려 다루지 않아도 되게.
    func testReturnsNothingWhenEverythingIsTooSmall() {
        XCTAssertTrue(CoreGraphicsDisplayModeManager.usableModes(
            from: [raw(640, 480), raw(400, 300)], current: nil).isEmpty)
    }
}
