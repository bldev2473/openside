import XCTest
import AppKit
@testable import OpenSideCore

final class MenuBarIconTests: XCTestCase {

    /// 메뉴바 이미지는 템플릿이어야 한다. 아니면 macOS 가 칠하지 못해
    /// 밝은 메뉴바에서 검은 덩어리로 남는다.
    func testIsATemplateImage() {
        XCTAssertTrue(MenuBarIcon.image(showsSidecar: false).isTemplate)
        XCTAssertTrue(MenuBarIcon.image(showsSidecar: true).isTemplate)
    }

    /// 메뉴바 높이에 맞아야 한다. 너무 크면 잘린다.
    func testFitsTheMenuBar() {
        let size = MenuBarIcon.image(showsSidecar: true).size
        XCTAssertLessThanOrEqual(size.height, 18)
        XCTAssertLessThanOrEqual(size.width, 26)
    }

    /// 실제로 뭔가 그려져야 한다. 빈 이미지는 메뉴바에서 자리만 차지한다.
    func testDrawsSomething() {
        for connected in [false, true] {
            let image = MenuBarIcon.image(showsSidecar: connected)
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else {
                XCTFail("비트맵을 못 얻었다"); return
            }
            var painted = 0
            for x in 0..<bitmap.pixelsWide {
                for y in 0..<bitmap.pixelsHigh where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    painted += 1
                }
            }
            XCTAssertGreaterThan(painted, 20, "연결=\(connected) 에서 그려진 점이 너무 적다")
        }
    }

    /// 붙어 있을 때 iPad 화면이 하나 더 그려지므로 칠해진 점이 더 많아야 한다.
    func testShowsMoreWhenTheSidecarIsAttached() {
        func painted(_ connected: Bool) -> Int {
            let image = MenuBarIcon.image(showsSidecar: connected)
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else { return 0 }
            var count = 0
            for x in 0..<bitmap.pixelsWide {
                for y in 0..<bitmap.pixelsHigh where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    count += 1
                }
            }
            return count
        }
        XCTAssertGreaterThan(painted(true), painted(false))
    }
}
