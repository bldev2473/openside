import XCTest
import AppKit
@testable import OpenSideCore

final class MenuBarIconTests: XCTestCase {

    /// Menu bar images must be templates; otherwise macOS cannot tint them,
    /// leaving them as solid black blobs on light menu bars.
    func testIsATemplateImage() {
        XCTAssertTrue(MenuBarIcon.image(showsSidecar: false).isTemplate)
        XCTAssertTrue(MenuBarIcon.image(showsSidecar: true).isTemplate)
    }

    /// Must fit the menu bar height; oversized icons get clipped.
    func testFitsTheMenuBar() {
        let size = MenuBarIcon.image(showsSidecar: true).size
        XCTAssertLessThanOrEqual(size.height, 18)
        XCTAssertLessThanOrEqual(size.width, 26)
    }

    /// Must actually render content; an empty image merely consumes space in the menu bar.
    func testDrawsSomething() {
        for connected in [false, true] {
            let image = MenuBarIcon.image(showsSidecar: connected)
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else {
                XCTFail("Failed to obtain bitmap"); return
            }
            var painted = 0
            for x in 0..<bitmap.pixelsWide {
                for y in 0..<bitmap.pixelsHigh where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    painted += 1
                }
            }
            XCTAssertGreaterThan(painted, 20, "Too few pixels painted for connected=\(connected)")
        }
    }

    /// Must paint more pixels when connected since an additional iPad screen is rendered.
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
