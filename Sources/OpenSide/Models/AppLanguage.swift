import Foundation

/// OpenSide 애플리케이션 지원 언어 정의
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"

    public var id: String { rawValue }

    /// 메뉴 및 UI에 표시될 언어 명칭
    public var displayName: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "영어"
        case .japanese:
            return "일본어"
        case .chinese:
            return "중국어"
        }
    }
}
