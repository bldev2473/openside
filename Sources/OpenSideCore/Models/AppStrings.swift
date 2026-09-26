import Foundation

/// Localized UI string definitions
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
    /// When registered but requires user approval in System Settings
    public let launchAtLoginNeedsApproval: String
    public let languagePicker: String
    public let settingsTitle: String
    /// iPad battery badge tooltip. Argument is formatted last updated timestamp
    public let iPadBatteryTooltip: @Sendable (String) -> String
    /// Shown when no connectable Sidecar devices are found
    public let noSidecarDevices: String
    /// Title for the resolution row
    public let resolution: String
    /// Main display resolution label during mirroring. Both displays change together.
    public let mainResolution: String
    /// Session info section
    public let sessionInfoSection: String
    public let sessionFramerate: String
    public let sessionBitrate: String
    public let sessionSize: String
    public let sessionHDR: String
    public let onWord: String
    public let offWord: String
    /// Extended display mode label
    public let extendDisplay: String
    /// Mirrored display mode label
    public let mirrorDisplay: String
    /// Estimated remaining usage time. Argument is formatted duration string
    public let approximateRemaining: @Sendable (String) -> String
    /// Explanation when devices are not found
    public let readinessHint: @Sendable (SidecarReadinessIssue) -> String
    /// Call to action suggesting enabling prerequisites
    public let readinessCallToAction: String
    /// When Sidecar display is not found during an operation
    public let noSidecarDisplayError: String
    /// When main display is not found during an operation
    public let noMainDisplayError: String
    /// When CoreGraphics rejects display reconfiguration. Argument is the error
    public let displayConfigurationError: @Sendable (DisplayConfigurationError) -> String
    public let presetLabels: @Sendable (DisplayArrangementPreset) -> String
}

extension AppLanguage {
    /// Returns the localized string bundle for the selected language
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
                launchAtLoginNeedsApproval: "시스템 설정 > 일반 > 로그인 항목에서 켜 주세요",
                languagePicker: "언어",
                settingsTitle: "설정",
                iPadBatteryTooltip: { "iPad 배터리 · 마지막 갱신 \($0)" },
                noSidecarDevices: "연결 가능한 기기 없음",
                resolution: "해상도",
                mainResolution: "메인 해상도",
                sessionInfoSection: "세션 정보",
                sessionFramerate: "프레임레이트",
                sessionBitrate: "전송률",
                sessionSize: "크기",
                sessionHDR: "HDR",
                onWord: "켜짐",
                offWord: "꺼짐",
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
                noSidecarDisplayError: "연결된 Sidecar 디스플레이가 없습니다",
                noMainDisplayError: "메인 디스플레이를 찾을 수 없습니다",
                displayConfigurationError: { error in
                    switch error {
                    case .beginConfigurationFailed: return "디스플레이 구성을 시작하지 못했습니다 (코드 \(error.code))"
                    case .configureOriginFailed: return "디스플레이를 옮기지 못했습니다 (코드 \(error.code))"
                    case .completeConfigurationFailed: return "디스플레이 구성을 적용하지 못했습니다 (코드 \(error.code))"
                    case .configureMirroringFailed: return "디스플레이 복제를 설정하지 못했습니다 (코드 \(error.code))"
                    }
                },
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
                launchAtLoginNeedsApproval: "Turn it on in System Settings > General > Login Items",
                languagePicker: "Language",
                settingsTitle: "Settings",
                iPadBatteryTooltip: { "iPad battery · Last updated \($0)" },
                noSidecarDevices: "No devices available",
                resolution: "Resolution",
                mainResolution: "Main resolution",
                sessionInfoSection: "Session",
                sessionFramerate: "Frame rate",
                sessionBitrate: "Bit rate",
                sessionSize: "Size",
                sessionHDR: "HDR",
                onWord: "On",
                offWord: "Off",
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
                noSidecarDisplayError: "No Sidecar display is connected",
                noMainDisplayError: "The main display could not be found",
                displayConfigurationError: { error in
                    switch error {
                    case .beginConfigurationFailed: return "Could not begin the display configuration (code \(error.code))"
                    case .configureOriginFailed: return "Could not move the display (code \(error.code))"
                    case .completeConfigurationFailed: return "Could not apply the display configuration (code \(error.code))"
                    case .configureMirroringFailed: return "Could not set up display mirroring (code \(error.code))"
                    }
                },
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
                launchAtLoginNeedsApproval: "システム設定 > 一般 > ログイン項目 で有効にしてください",
                languagePicker: "言語",
                settingsTitle: "設定",
                iPadBatteryTooltip: { "iPad バッテリー · 最終更新 \($0)" },
                noSidecarDevices: "利用可能なデバイスなし",
                resolution: "解像度",
                mainResolution: "メインの解像度",
                sessionInfoSection: "セッション",
                sessionFramerate: "フレームレート",
                sessionBitrate: "ビットレート",
                sessionSize: "サイズ",
                sessionHDR: "HDR",
                onWord: "オン",
                offWord: "オフ",
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
                noSidecarDisplayError: "接続されているSidecarディスプレイがありません",
                noMainDisplayError: "メインディスプレイが見つかりません",
                displayConfigurationError: { error in
                    switch error {
                    case .beginConfigurationFailed: return "ディスプレイ構成を開始できませんでした (コード \(error.code))"
                    case .configureOriginFailed: return "ディスプレイを移動できませんでした (コード \(error.code))"
                    case .completeConfigurationFailed: return "ディスプレイ構成を適用できませんでした (コード \(error.code))"
                    case .configureMirroringFailed: return "ディスプレイのミラーリングを設定できませんでした (コード \(error.code))"
                    }
                },
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
                launchAtLoginNeedsApproval: "请在系统设置 > 通用 > 登录项中开启",
                languagePicker: "语言",
                settingsTitle: "设置",
                iPadBatteryTooltip: { "iPad 电量 · 最后更新 \($0)" },
                noSidecarDevices: "无可用设备",
                resolution: "分辨率",
                mainResolution: "主屏幕分辨率",
                sessionInfoSection: "会话",
                sessionFramerate: "帧率",
                sessionBitrate: "码率",
                sessionSize: "尺寸",
                sessionHDR: "HDR",
                onWord: "开",
                offWord: "关",
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
                noSidecarDisplayError: "没有已连接的“随航”显示器",
                noMainDisplayError: "找不到主显示器",
                displayConfigurationError: { error in
                    switch error {
                    case .beginConfigurationFailed: return "无法开始显示器配置 (代码 \(error.code))"
                    case .configureOriginFailed: return "无法移动显示器 (代码 \(error.code))"
                    case .completeConfigurationFailed: return "无法应用显示器配置 (代码 \(error.code))"
                    case .configureMirroringFailed: return "无法设置显示器镜像 (代码 \(error.code))"
                    }
                },
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
