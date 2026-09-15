import Foundation

/// 다국어 지원 UI 텍스트 정의 모델
public struct LocalizedUIStrings: Sendable {
    public let disconnect: String
    public let connectDevice: @Sendable (String) -> String
    public let connected: String
    public let disconnected: String
    public let rearrange: String
    public let quit: String
    public let about: String
    public let settings: String
    public let languageSettings: String
    public let quitOpenSide: String
    public let generalSection: String
    public let launchAtLogin: String
    public let languagePicker: String
    public let settingsTitle: String
    public let presetLabels: @Sendable (DisplayArrangementPreset) -> String
}

extension AppLanguage {
    /// 선택된 언어에 따른 UI 텍스트 번들 반환
    public var strings: LocalizedUIStrings {
        switch self {
        case .korean:
            return LocalizedUIStrings(
                disconnect: "연결 해제",
                connectDevice: { "\($0) 연결" },
                connected: "연결됨",
                disconnected: "연결 안 됨",
                rearrange: "재정렬",
                quit: "종료",
                about: "정보",
                settings: "설정",
                languageSettings: "언어 설정",
                quitOpenSide: "OpenSide 종료",
                generalSection: "일반",
                launchAtLogin: "로그인 시 자동 실행",
                languagePicker: "언어",
                settingsTitle: "설정",
                presetLabels: { preset in
                    switch preset {
                    case .topCenter: return "상단 중앙"
                    case .bottomCenter: return "하단 중앙"
                    case .leftTop: return "좌측 상단"
                    case .leftCenter: return "좌측 중앙"
                    case .leftBottom: return "좌측 하단"
                    case .rightTop: return "우측 상단"
                    case .rightCenter: return "우측 중앙"
                    case .rightBottom: return "우측 하단"
                    }
                }
            )
        case .english:
            return LocalizedUIStrings(
                disconnect: "Disconnect",
                connectDevice: { "Connect \($0)" },
                connected: "Connected",
                disconnected: "Disconnected",
                rearrange: "Rearrange",
                quit: "Quit",
                about: "About",
                settings: "Settings",
                languageSettings: "Language",
                quitOpenSide: "Quit OpenSide",
                generalSection: "General",
                launchAtLogin: "Launch at Login",
                languagePicker: "Language",
                settingsTitle: "Settings",
                presetLabels: { preset in
                    switch preset {
                    case .topCenter: return "Top Center"
                    case .bottomCenter: return "Bottom Center"
                    case .leftTop: return "Top Left"
                    case .leftCenter: return "Center Left"
                    case .leftBottom: return "Bottom Left"
                    case .rightTop: return "Top Right"
                    case .rightCenter: return "Center Right"
                    case .rightBottom: return "Bottom Right"
                    }
                }
            )
        case .japanese:
            return LocalizedUIStrings(
                disconnect: "接続解除",
                connectDevice: { "\($0)に接続" },
                connected: "接続中",
                disconnected: "未接続",
                rearrange: "再配置",
                quit: "終了",
                about: "情報",
                settings: "設定",
                languageSettings: "言語設定",
                quitOpenSide: "OpenSideを終了",
                generalSection: "一般",
                launchAtLogin: "ログイン時に自動起動",
                languagePicker: "言語",
                settingsTitle: "設定",
                presetLabels: { preset in
                    switch preset {
                    case .topCenter: return "上中央"
                    case .bottomCenter: return "下中央"
                    case .leftTop: return "左上"
                    case .leftCenter: return "左中央"
                    case .leftBottom: return "左下"
                    case .rightTop: return "右上"
                    case .rightCenter: return "右中央"
                    case .rightBottom: return "右下"
                    }
                }
            )
        case .chinese:
            return LocalizedUIStrings(
                disconnect: "断开连接",
                connectDevice: { "连接 \($0)" },
                connected: "已连接",
                disconnected: "未连接",
                rearrange: "重新排列",
                quit: "退出",
                about: "关于",
                settings: "设置",
                languageSettings: "语言设置",
                quitOpenSide: "退出 OpenSide",
                generalSection: "通用",
                launchAtLogin: "开机自动启动",
                languagePicker: "语言",
                settingsTitle: "设置",
                presetLabels: { preset in
                    switch preset {
                    case .topCenter: return "上中"
                    case .bottomCenter: return "下中"
                    case .leftTop: return "左上"
                    case .leftCenter: return "左中"
                    case .leftBottom: return "左下"
                    case .rightTop: return "右上"
                    case .rightCenter: return "右中"
                    case .rightBottom: return "右下"
                    }
                }
            )
        }
    }
}
