import Foundation

/// 화면을 다루다 실패한 까닭.
///
/// 뷰 모델은 완성된 문장이 아니라 갈래를 들고, 문장은 화면이 고른 언어로 만듭니다.
/// 뷰 모델이 한국어 문장을 들고 있으면 언어를 바꿔도 그 줄만 한국어로 남습니다.
public enum DisplayOperationFailure: Equatable, Sendable {
    /// 사이드카 화면을 찾지 못함.
    case noSidecarDisplay
    /// 메인 화면을 찾지 못함.
    case noMainDisplay
    /// CoreGraphics 가 화면 구성을 거부함.
    case configuration(DisplayConfigurationError)
    /// 시스템이 낸 오류. 이미 사용자 언어로 적혀 있으므로 그대로 보여줍니다.
    case system(String)

    /// 고른 언어로 읽을 문장.
    public func message(_ strings: LocalizedUIStrings) -> String {
        switch self {
        case .noSidecarDisplay: return strings.noSidecarDisplayError
        case .noMainDisplay: return strings.noMainDisplayError
        case .configuration(let error): return strings.displayConfigurationError(error)
        case .system(let description): return description
        }
    }
}
