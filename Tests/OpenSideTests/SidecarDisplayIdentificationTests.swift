import XCTest
import CoreGraphics
@testable import OpenSideCore

/// Rules to identify which display is a Sidecar display.
///
/// While mirroring, NSScreen may not expose the display so its name cannot be read.
/// In the past, unnamed mirrored displays were assumed to be Sidecar, but this led to
/// HDMI-connected mirrored external monitors being incorrectly identified as an iPad.
final class SidecarDisplayIdentificationTests: XCTestCase {

    /// Counts how many times the session status was queried.
    private final class SessionSpy: SidecarConnecting, @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var asked: Int { lock.withLock { count } }

        func currentSessionInfo() -> SidecarSessionInfo? {
            lock.withLock { count += 1 }
            return nil
        }
        func getAvailableDevices() -> [SidecarDeviceInfo] { [] }
        func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
        func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
    }

    /// If the name contains "iPad", the session status is not queried. The name is accessible during extended mode.
    func testANamedSidecarScreenIsRecognisedWithoutASession() {
        XCTAssertTrue(SidecarDisplayRule.isSidecar(
            name: "iPad", isBuiltin: false, isOurs: false,
            isMirrored: false, hasSidecarSession: false
        ))
    }

    /// While a session is active, an unnamed mirrored display is recognized as Sidecar. This preserves legacy behavior.
    func testAnUnnamedMirroredScreenIsSidecarWhileASessionRuns() {
        XCTAssertTrue(SidecarDisplayRule.isSidecar(
            name: "External Display 9", isBuiltin: false, isOurs: false,
            isMirrored: true, hasSidecarSession: true
        ))
    }

    /// If no iPad is connected and an external monitor is used in mirrored mode, it is not a Sidecar display.
    ///
    /// Before the fix, this evaluated to true. Mirroring to a projector or HDMI monitor resulted in that display
    /// being recognized as an iPad, causing resolution rows and arrangement targets to point to the wrong screen.
    func testAMirroredMonitorIsNotSidecarWhenNoSessionExists() {
        XCTAssertFalse(SidecarDisplayRule.isSidecar(
            name: "DELL U2720Q", isBuiltin: false, isOurs: false,
            isMirrored: true, hasSidecarSession: false
        ))
    }

    /// Built-in displays are never Sidecar under any circumstance.
    func testTheBuiltInScreenIsNeverSidecar() {
        for mirrored in [true, false] {
            for session in [true, false] {
                XCTAssertFalse(SidecarDisplayRule.isSidecar(
                    name: "iPad", isBuiltin: true, isOurs: false,
                    isMirrored: mirrored, hasSidecarSession: session
                ))
            }
        }
    }

    /// Virtual displays created by this app are not Sidecar, even though they are non-built-in and unnamed.
    func testOurOwnScreenIsNeverSidecar() {
        XCTAssertFalse(SidecarDisplayRule.isSidecar(
            name: "External Display 9", isBuiltin: false, isOurs: true,
            isMirrored: true, hasSidecarSession: true
        ))
    }

    /// The detector must actually query whether a session is running.
    ///
    /// Testing the rule alone does not verify what values the detector passes to it.
    /// Even if the detector did not query the session or passed arbitrary values, isolated rule tests would still pass.
    func testTheDetectorAsksWhetherASessionIsRunning() {
        let spy = SessionSpy()
        _ = CoreGraphicsDisplayDetector(sidecar: spy).getActiveDisplays()
        XCTAssertEqual(spy.asked, 1, "Session was not queried or was queried repeatedly per display")
    }

    /// The session status is queried only once per display list refresh. If queried per display, state changes
    /// mid-enumeration could lead to inconsistent decisions across displays within the same refresh.
    func testTheSessionIsReadOncePerRefresh() {
        let spy = SessionSpy()
        let detector = CoreGraphicsDisplayDetector(sidecar: spy)
        _ = detector.getActiveDisplays()
        _ = detector.getActiveDisplays()
        XCTAssertEqual(spy.asked, 2)
    }

    /// Names containing "AirPlay" or "Sidecar" are also recognized, as macOS uses both.
    func testTheOtherNamesMacOSUsesAreRecognised() {
        for name in ["Sidecar Display (AirPlay)", "AirPlay Display", "iPad Pro"] {
            XCTAssertTrue(SidecarDisplayRule.isSidecar(
                name: name, isBuiltin: false, isOurs: false,
                isMirrored: false, hasSidecarSession: false
            ), "Failed to recognize \(name)")
        }
    }
}
