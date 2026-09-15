import XCTest
@testable import OpenSideCore

/// 미니어처 좌표 변환기 단위 테스트 클래스
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

    /// 캔버스 스케일에 따른 드래그 변위 좌표의 글로벌 시스템 좌표 변환 무결성 검증
    func testTransformDragToTargetOrigin() {
        let initialOrigin = CGPoint(x: 1512, y: 635)
        let scale: CGFloat = 0.1 // 캔버스 10배 축소 비율
        let dragTranslation = CGSize(width: 20.0, height: -15.0)

        // 예상 이동량: dx = 20 / 0.1 = +200, dy = -15 / 0.1 = -150
        // 예상 목표 좌표: (1512 + 200, 635 - 150) = (1712, 485)
        let result = transformer.transformDragToTargetOrigin(
            currentOrigin: initialOrigin,
            dragTranslation: dragTranslation,
            scale: scale
        )

        XCTAssertEqual(result.x, 1712)
        XCTAssertEqual(result.y, 485)
    }

    /// 이동량이 0일 때 원래 좌표 유지 검증
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
