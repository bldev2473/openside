import XCTest
@testable import OpenSide

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

    /// 해상도 목록 오름차순 정렬 로직 검증
    func testResolutionSorting() {
        let mode1 = DisplayResolutionMode(width: 1280, height: 960, pixelWidth: 1280, pixelHeight: 960, refreshRate: 60.0, isHiDPI: false)
        let mode2 = DisplayResolutionMode(width: 800, height: 600, pixelWidth: 800, pixelHeight: 600, refreshRate: 60.0, isHiDPI: false)
        let mode3 = DisplayResolutionMode(width: 1112, height: 834, pixelWidth: 1112, pixelHeight: 834, refreshRate: 60.0, isHiDPI: false)

        let modes = [mode1, mode2, mode3]
        let sortedModes = modes.sorted { m1, m2 in
            if m1.width != m2.width {
                return m1.width < m2.width
            }
            return m1.height < m2.height
        }

        XCTAssertEqual(sortedModes[0].width, 800)
        XCTAssertEqual(sortedModes[1].width, 1112)
        XCTAssertEqual(sortedModes[2].width, 1280)
    }

    /// 800x600 미만의 사용 불가능한 극단적 저해상도 필터링 검증
    func testLowResolutionFiltering() {
        let sampleModes = [
            (w: 400, h: 300),
            (w: 512, h: 384),
            (w: 640, h: 480),
            (w: 672, h: 504),
            (w: 800, h: 600),
            (w: 1024, h: 768),
            (w: 1112, h: 834)
        ]

        let filtered = sampleModes.filter { $0.w >= 800 && $0.h >= 600 }

        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered[0].w, 800)
        XCTAssertEqual(filtered[1].w, 1024)
        XCTAssertEqual(filtered[2].w, 1112)
    }
}
