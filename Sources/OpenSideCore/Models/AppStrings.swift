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
    /// iPad 배터리 배지 툴팁. 인자는 마지막 갱신 시각 표기
    public let iPadBatteryTooltip: @Sendable (String) -> String
    /// 연결 가능한 사이드카 기기를 찾지 못했을 때 안내
    public let noSidecarDevices: String
    /// 해상도 행 제목
    public let resolution: String
    /// 복제 중 메인 화면 해상도 라벨. 두 화면이 함께 바뀝니다.
    public let mainResolution: String
    /// 확장 표시 모드 라벨
    public let extendDisplay: String
    /// 메인 화면 복제 모드 라벨
    public let mirrorDisplay: String
    /// 남은 사용 시간 추정. 인자는 시간 표기
    public let approximateRemaining: @Sendable (String) -> String
    /// 기기를 찾지 못한 원인 안내
    public let readinessHint: @Sendable (SidecarReadinessIssue) -> String
    /// 전제 조건 활성화를 권하는 안내 문구
    public let readinessCallToAction: String
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
                iPadBatteryTooltip: { "iPad 배터리 · 마지막 갱신 \($0)" },
                noSidecarDevices: "연결 가능한 기기 없음",
                resolution: "해상도",
                mainResolution: "메인 해상도",
                extendDisplay: "확장",
                mirrorDisplay: "복제",
                approximateRemaining: { "약 \($0)" },
                readinessHint: { issue in
                    switch issue {
                    case .wifiOff: return "이 Mac의 Wi-Fi가 꺼져 있습니다"
                    case .handoffOff: return "이 Mac의 Handoff가 꺼져 있습니다"
                    }
                },
                readinessCallToAction: "원활한 동작을 위해 활성화해주세요",
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
                iPadBatteryTooltip: { "iPad battery · Last updated \($0)" },
                noSidecarDevices: "No devices available",
                resolution: "Resolution",
                mainResolution: "Main resolution",
                extendDisplay: "Extend",
                mirrorDisplay: "Mirror",
                approximateRemaining: { "about \($0)" },
                readinessHint: { issue in
                    switch issue {
                    case .wifiOff: return "Wi-Fi is off on this Mac"
                    case .handoffOff: return "Handoff is off on this Mac"
                    }
                },
                readinessCallToAction: "Enable it for reliable operation",
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
                iPadBatteryTooltip: { "iPad バッテリー · 最終更新 \($0)" },
                noSidecarDevices: "利用可能なデバイスなし",
                resolution: "解像度",
                mainResolution: "メインの解像度",
                extendDisplay: "拡張",
                mirrorDisplay: "ミラーリング",
                approximateRemaining: { "約 \($0)" },
                readinessHint: { issue in
                    switch issue {
                    case .wifiOff: return "この Mac の Wi-Fi がオフです"
                    case .handoffOff: return "この Mac の Handoff がオフです"
                    }
                },
                readinessCallToAction: "安定した動作のために有効にしてください",
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
                iPadBatteryTooltip: { "iPad 电量 · 最后更新 \($0)" },
                noSidecarDevices: "无可用设备",
                resolution: "分辨率",
                mainResolution: "主屏幕分辨率",
                extendDisplay: "扩展",
                mirrorDisplay: "镜像",
                approximateRemaining: { "约 \($0)" },
                readinessHint: { issue in
                    switch issue {
                    case .wifiOff: return "此 Mac 的 Wi-Fi 已关闭"
                    case .handoffOff: return "此 Mac 的 Handoff 已关闭"
                    }
                },
                readinessCallToAction: "请启用以确保正常运行",
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
