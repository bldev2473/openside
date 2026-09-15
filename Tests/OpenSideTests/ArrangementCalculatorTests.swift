import XCTest
@testable import OpenSideCore

/// 디스플레이 정렬 좌표 계산기 단위 테스트 클래스
final class ArrangementCalculatorTests: XCTestCase {
    private var calculator: StandardArrangementCalculator!

    override func setUp() {
        super.setUp()
        calculator = StandardArrangementCalculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    /// 맥북 14인치(1512x982) 및 아이패드 프로 11인치(1112x834) 기준 정렬 좌표 무결성 검증
    func testMacBookAndiPadArrangementCalculation() {
        let macBounds = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let ipadBounds = CGRect(x: 0, y: 0, width: 1112, height: 834)

        // 1. 좌측 상단 맞춤: x = -1112, y = 0
        let leftTop = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .leftTop)
        XCTAssertEqual(leftTop.x, -1112)
        XCTAssertEqual(leftTop.y, 0)

        // 2. 좌측 수직 중앙 맞춤: x = -1112, y = (982 - 834) / 2 = 74
        let leftCenter = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .leftCenter)
        XCTAssertEqual(leftCenter.x, -1112)
        XCTAssertEqual(leftCenter.y, 74)

        // 3. 좌측 하단 맞춤: x = -1112, y = 982 - 834 = 148
        let leftBottom = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .leftBottom)
        XCTAssertEqual(leftBottom.x, -1112)
        XCTAssertEqual(leftBottom.y, 148)

        // 4. 우측 상단 맞춤: x = 1512, y = 0
        let rightTop = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .rightTop)
        XCTAssertEqual(rightTop.x, 1512)
        XCTAssertEqual(rightTop.y, 0)

        // 5. 우측 수직 중앙 맞춤: x = 1512, y = 74
        let rightCenter = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .rightCenter)
        XCTAssertEqual(rightCenter.x, 1512)
        XCTAssertEqual(rightCenter.y, 74)

        // 6. 우측 하단 맞춤: x = 1512, y = 148
        let rightBottom = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .rightBottom)
        XCTAssertEqual(rightBottom.x, 1512)
        XCTAssertEqual(rightBottom.y, 148)

        // 7. 상단 수평 중앙 맞춤: x = (1512 - 1112) / 2 = 200, y = -834
        let topCenter = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .topCenter)
        XCTAssertEqual(topCenter.x, 200)
        XCTAssertEqual(topCenter.y, -834)

        // 8. 하단 수평 중앙 맞춤: x = 200, y = 982
        let bottomCenter = calculator.calculateOrigin(mainBounds: macBounds, targetBounds: ipadBounds, preset: .bottomCenter)
        XCTAssertEqual(bottomCenter.x, 200)
        XCTAssertEqual(bottomCenter.y, 982)
    }

    /// 동일한 해상도의 디스플레이(1920x1080) 정렬 계산 검증
    func testIdenticalResolutionCalculation() {
        let mainBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let targetBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let leftCenter = calculator.calculateOrigin(mainBounds: mainBounds, targetBounds: targetBounds, preset: .leftCenter)
        XCTAssertEqual(leftCenter.x, -1920)
        XCTAssertEqual(leftCenter.y, 0)

        let rightCenter = calculator.calculateOrigin(mainBounds: mainBounds, targetBounds: targetBounds, preset: .rightCenter)
        XCTAssertEqual(rightCenter.x, 1920)
        XCTAssertEqual(rightCenter.y, 0)

        let topCenter = calculator.calculateOrigin(mainBounds: mainBounds, targetBounds: targetBounds, preset: .topCenter)
        XCTAssertEqual(topCenter.x, 0)
        XCTAssertEqual(topCenter.y, -1080)

        let bottomCenter = calculator.calculateOrigin(mainBounds: mainBounds, targetBounds: targetBounds, preset: .bottomCenter)
        XCTAssertEqual(bottomCenter.x, 0)
        XCTAssertEqual(bottomCenter.y, 1080)
    }
}
