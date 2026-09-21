import XCTest
@testable import OpenSideCore

/// 조작이 실패했을 때 화면에 무엇이 뜨는지 본다.
///
/// 예전에는 뷰 모델이 한국어 문장을 그대로 들고 있었다. 언어를 영어로 바꿔도 그 줄만
/// 한국어로 남아, 영어권 사용자는 무엇이 잘못됐는지 읽지 못했다. 실패는 갈래로 들고
/// 문장은 화면이 고르게 한다.
final class OperationFailureTests: XCTestCase {

    /// 화면이 하나도 없는 상태. 사이드카도 메인도 못 찾는다.
    private struct EmptyDetector: DisplayDetecting {
        func getActiveDisplays() -> [DisplayInfo] { [] }
        func getSidecarDisplay() -> DisplayInfo? { nil }
        func getMainDisplay() -> DisplayInfo? { nil }
    }

    /// 맥 화면만 있는 상태. iPad 를 붙이지 않은 평소 모습이다.
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

    /// 네 언어 모두 문구를 갖춰야 한다. 하나라도 비면 그 언어에서 빈 줄이 보인다.
    func testEveryLanguageWordsEveryFailure() {
        for language in AppLanguage.allCases {
            let strings = language.strings
            for failure in [DisplayOperationFailure.noSidecarDisplay, .noMainDisplay] {
                let text = failure.message(strings)
                XCTAssertFalse(text.isEmpty, "\(language.rawValue) 에 \(failure) 문구가 없다")
            }
        }
    }

    /// 언어마다 다른 문장이어야 한다. 번역을 빠뜨리고 한국어를 복사해 두면 여기서 걸린다.
    func testFailuresAreTranslatedNotCopied() {
        let texts = AppLanguage.allCases.map {
            DisplayOperationFailure.noSidecarDisplay.message($0.strings)
        }
        XCTAssertEqual(Set(texts).count, AppLanguage.allCases.count, "언어별 문구가 겹친다")
    }

    /// 두 실패를 구분해야 한다. 같은 문장을 돌려주면 사용자가 원인을 가릴 수 없다.
    func testTwoFailuresReadDifferently() {
        for language in AppLanguage.allCases {
            let strings = language.strings
            XCTAssertNotEqual(
                DisplayOperationFailure.noSidecarDisplay.message(strings),
                DisplayOperationFailure.noMainDisplay.message(strings),
                "\(language.rawValue) 에서 두 실패가 같은 문장"
            )
        }
    }

    /// CoreGraphics 가 거부한 것도 네 언어로 읽혀야 한다. 코드 번호는 어느 언어에서나 남는다.
    func testConfigurationFailureIsWordedAndKeepsItsCode() {
        let failure = DisplayOperationFailure.configuration(.configureOriginFailed(code: 1002))
        var seen: Set<String> = []
        for language in AppLanguage.allCases {
            let text = failure.message(language.strings)
            XCTAssertTrue(text.contains("1002"), "\(language.rawValue) 에 오류 코드가 빠졌다")
            seen.insert(text)
        }
        XCTAssertEqual(seen.count, AppLanguage.allCases.count, "언어별 문구가 겹친다")
    }

    /// 네 단계를 구분해야 한다. 어느 단계에서 막혔는지가 원인을 가린다.
    func testEveryConfigurationStepReadsDifferently() {
        let steps: [DisplayConfigurationError] = [
            .beginConfigurationFailed(code: 1), .configureOriginFailed(code: 1),
            .completeConfigurationFailed(code: 1), .configureMirroringFailed(code: 1)
        ]
        for language in AppLanguage.allCases {
            let texts = steps.map { DisplayOperationFailure.configuration($0).message(language.strings) }
            XCTAssertEqual(Set(texts).count, steps.count, "\(language.rawValue) 에서 단계가 겹친다")
        }
    }

    /// 시스템이 낸 오류는 그대로 보여준다. macOS 가 이미 사용자 언어로 적어 준다.
    func testSystemFailureKeepsItsOwnWording() {
        let failure = DisplayOperationFailure.system("The display is busy.")
        for language in AppLanguage.allCases {
            XCTAssertEqual(failure.message(language.strings), "The display is busy.")
        }
    }

    /// iPad 가 없으면 그 갈래를 든다. 문장이 아니라 갈래다.
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

    /// 맥 화면조차 못 읽으면 다른 갈래를 든다. 두 실패를 뭉뚱그리면 원인이 사라진다.
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
