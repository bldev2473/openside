import Foundation

/// OpenSide 애플리케이션 지원 언어 정의
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"

    public var id: String { rawValue }

    /// 맥이 선호한다고 알려 온 목록에서 우리가 지원하는 첫 언어를 고릅니다.
    ///
    /// macOS 는 ko 가 아니라 ko-KR, zh-Hans-CN 처럼 지역과 표기까지 붙여 줍니다. 앞부분만
    /// 보고 맞춥니다. 하나도 못 맞추면 영어로 둡니다 — 한국어보다 읽을 수 있는 사람이 많습니다.
    public static func matching(_ preferredLanguages: [String]) -> AppLanguage {
        for tag in preferredLanguages {
            let code = tag.split(separator: "-").first.map(String.init) ?? tag
            if let language = AppLanguage(rawValue: code) { return language }
        }
        return .english
    }

    /// 메뉴 및 UI에 표시될 언어 고유 명칭(Autonyms)
    public var displayName: String {
        switch self {
        case .korean:
            return "한국어"
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .chinese:
            return "简体中文"
        }
    }
}
