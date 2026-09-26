import XCTest
@testable import OpenSideCore

/// Verifies what is displayed on screen when an operation fails.
///
/// Previously the view model retained formatted Korean strings directly. Even when language switched
/// to English, that single line remained in Korean, leaving English-speaking users unable to read the error.
/// Failures are stored as typed cases, allowing UI to format them according to selected language.
final class OperationFailureTests: XCTestCase {

    /// State with no displays found. Neither Sidecar nor main display detected.
    private struct EmptyDetector: DisplayDetecting {
        func getActiveDisplays() -> [DisplayInfo] { [] }
        func getSidecarDisplay() -> DisplayInfo? { nil }
        func getMainDisplay() -> DisplayInfo? { nil }
    }

    /// Normal state with both Mac and iPad present.
    private struct BothDisplaysDetector: DisplayDetecting {
        static let main = DisplayInfo(
            id: 1, uuid: "main", name: "Built-in",
            bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
            isMain: true, isBuiltin: true, isSidecar: false
        )
        static let sidecar = DisplayInfo(
            id: 2, uuid: "pad", name: "iPad",
            bounds: CGRect(x: 1512, y: 0, width: 1112, height: 834),
            isMain: false, isBuiltin: false, isSidecar: true
        )
        func getActiveDisplays() -> [DisplayInfo] { [Self.main, Self.sidecar] }
        func getSidecarDisplay() -> DisplayInfo? { Self.sidecar }
        func getMainDisplay() -> DisplayInfo? { Self.main }
    }

    /// Scenario where CoreGraphics rejects origin modification.
    private struct RefusingConfigurator: DisplayConfiguring {
        func configureDisplayOrigin(
            displayID: CGDirectDisplayID, origin: TargetDisplayOrigin
        ) -> Result<Void, DisplayConfigurationError> {
            .failure(.configureOriginFailed(code: 1002))
        }
        func configureMirroring(
            displayID: CGDirectDisplayID, mirrorOf masterID: CGDirectDisplayID?,
            persistence: DisplayConfigurationPersistence
        ) -> Result<Void, DisplayConfigurationError> { .success(()) }
        func isMirroring(displayID: CGDirectDisplayID) -> Bool { false }
    }

    /// Configurator capable of toggling between rejection and acceptance.
    private final class SwitchableConfigurator: DisplayConfiguring, @unchecked Sendable {
        var refuses = true
        func configureDisplayOrigin(
            displayID: CGDirectDisplayID, origin: TargetDisplayOrigin
        ) -> Result<Void, DisplayConfigurationError> {
            refuses ? .failure(.configureOriginFailed(code: 1002)) : .success(())
        }
        func configureMirroring(
            displayID: CGDirectDisplayID, mirrorOf masterID: CGDirectDisplayID?,
            persistence: DisplayConfigurationPersistence
        ) -> Result<Void, DisplayConfigurationError> { .success(()) }
        func isMirroring(displayID: CGDirectDisplayID) -> Bool { false }
    }

    /// State with Mac display only (typical standalone state without iPad).
    private struct MainOnlyDetector: DisplayDetecting {
        static let main = DisplayInfo(
            id: 1, uuid: "main", name: "Built-in",
            bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
            isMain: true, isBuiltin: true, isSidecar: false
        )
        func getActiveDisplays() -> [DisplayInfo] { [Self.main] }
        func getSidecarDisplay() -> DisplayInfo? { nil }
        func getMainDisplay() -> DisplayInfo? { Self.main }
    }

    private struct SilentChecker: SidecarReadinessChecking {
        func currentIssues() -> [SidecarReadinessIssue] { [] }
    }

    private struct SilentConnector: SidecarConnecting {
        func currentSessionInfo() -> SidecarSessionInfo? { nil }
        func getAvailableDevices() -> [SidecarDeviceInfo] { [] }
        func connect(to device: SidecarDeviceInfo, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
        func disconnect(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {}
    }

    /// All four languages must define failure wording. Missing any results in blank lines.
    func testEveryLanguageWordsEveryFailure() {
        for language in AppLanguage.allCases {
            let strings = language.strings
            for failure in [DisplayOperationFailure.noSidecarDisplay, .noMainDisplay] {
                let text = failure.message(strings)
                XCTAssertFalse(text.isEmpty, "Missing wording for \(failure) in \(language.rawValue)")
            }
        }
    }

    /// Strings must differ across languages. Catches untranslated copies.
    func testFailuresAreTranslatedNotCopied() {
        let texts = AppLanguage.allCases.map {
            DisplayOperationFailure.noSidecarDisplay.message($0.strings)
        }
        XCTAssertEqual(Set(texts).count, AppLanguage.allCases.count, "Wording overlaps across languages")
    }

    /// Two distinct failures must be distinguishable; identical messages prevent diagnosing cause.
    func testTwoFailuresReadDifferently() {
        for language in AppLanguage.allCases {
            let strings = language.strings
            XCTAssertNotEqual(
                DisplayOperationFailure.noSidecarDisplay.message(strings),
                DisplayOperationFailure.noMainDisplay.message(strings),
                "Two failures share identical message in \(language.rawValue)"
            )
        }
    }

    /// CoreGraphics rejections must be readable across all four languages while preserving error code numbers.
    func testConfigurationFailureIsWordedAndKeepsItsCode() {
        let failure = DisplayOperationFailure.configuration(.configureOriginFailed(code: 1002))
        var seen: Set<String> = []
        for language in AppLanguage.allCases {
            let text = failure.message(language.strings)
            XCTAssertTrue(text.contains("1002"), "Error code missing in \(language.rawValue)")
            seen.insert(text)
        }
        XCTAssertEqual(seen.count, AppLanguage.allCases.count, "Wording overlaps across languages")
    }

    /// All four configuration steps must be distinguished to pinpoint exact failure point.
    func testEveryConfigurationStepReadsDifferently() {
        let steps: [DisplayConfigurationError] = [
            .beginConfigurationFailed(code: 1), .configureOriginFailed(code: 1),
            .completeConfigurationFailed(code: 1), .configureMirroringFailed(code: 1)
        ]
        for language in AppLanguage.allCases {
            let texts = steps.map { DisplayOperationFailure.configuration($0).message(language.strings) }
            XCTAssertEqual(Set(texts).count, steps.count, "Configuration step descriptions overlap in \(language.rawValue)")
        }
    }


    /// Reports missing Sidecar as a typed enum case rather than a formatted string.
    @MainActor
    func testMissingSidecarIsReportedAsItsOwnCase() {
        let viewModel = DisplayManagerViewModel(
            detector: MainOnlyDetector(),
            sidecarConnector: SilentConnector(),
            readinessChecker: SilentChecker()
        )
        viewModel.applyPreset(.rightTop)
        XCTAssertEqual(viewModel.failure, .noSidecarDisplay)
    }

    /// When CoreGraphics rejects configuration, that typed case must propagate to the UI.
    ///
    /// Verifying text existence alone is insufficient; if view model drops type info and passes
    /// formatted English strings, Korean users would see untranslated English lines.
    @MainActor
    func testARefusedConfigurationReachesTheUser() {
        let viewModel = DisplayManagerViewModel(
            detector: BothDisplaysDetector(),
            configurator: RefusingConfigurator(),
            sidecarConnector: SilentConnector(),
            readinessChecker: SilentChecker()
        )
        viewModel.applyPreset(.rightTop)
        XCTAssertEqual(viewModel.failure, .configuration(.configureOriginFailed(code: 1002)))

        let korean = viewModel.failure?.message(AppLanguage.korean.strings) ?? ""
        XCTAssertTrue(korean.contains("1002"))
        XCTAssertFalse(korean.contains("Could not"), "English text found in Korean output")
    }

    /// Successful retry must dismiss the error notice.
    ///
    /// Leaving it active continues reporting already-resolved errors, preventing users from seeing current status.
    @MainActor
    func testASuccessfulRetryClearsTheFailure() {
        let configurator = SwitchableConfigurator()
        let viewModel = DisplayManagerViewModel(
            detector: BothDisplaysDetector(),
            configurator: configurator,
            sidecarConnector: SilentConnector(),
            readinessChecker: SilentChecker()
        )

        viewModel.applyPreset(.rightTop)
        XCTAssertNotNil(viewModel.failure, "Nothing recorded despite rejection")

        configurator.refuses = false
        viewModel.applyPreset(.rightTop)
        XCTAssertNil(viewModel.failure, "Error notice persists despite success")
    }

    /// Reports missing main display as a distinct case. Grouping both failures would obscure root cause.
    @MainActor
    func testMissingMainDisplayIsReportedSeparately() {
        let viewModel = DisplayManagerViewModel(
            detector: EmptyDetector(),
            sidecarConnector: SilentConnector(),
            readinessChecker: SilentChecker()
        )
        viewModel.applyPreset(.rightTop)
        XCTAssertEqual(viewModel.failure, .noMainDisplay)
    }
}
