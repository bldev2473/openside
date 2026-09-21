import Foundation
import ServiceManagement

/// 로그인 항목으로서 지금 어떤 상태인지.
public enum LoginItemState: Equatable, Sendable {
    /// 등록되어 있지 않음.
    case off
    /// 등록되어 있고 로그인 때 실행됨.
    case on
    /// 등록은 받아들여졌지만 사용자가 시스템 설정에서 켜 줘야 함.
    ///
    /// macOS 는 이때 오류를 내지 않습니다. 이것을 off 로 뭉뚱그리면 켜도 꺼지는 것처럼 보이고
    /// 왜 그런지 알 길이 없습니다.
    case needsApproval
}

/// 로그인할 때 앱을 띄울지 다루는 인터페이스.
public protocol LoginItemManaging: Sendable {
    /// 지금 상태. 저장해 둔 값이 아니라 시스템에 물어봅니다.
    var state: LoginItemState { get }

    /// 등록하거나 해제합니다. 시스템이 거부하면 던집니다.
    func setEnabled(_ enabled: Bool) throws
}

/// macOS 의 로그인 항목으로 등록하는 구현체.
///
/// 사용자가 시스템 설정 > 일반 > 로그인 항목에서 직접 끌 수 있으므로, 상태는 언제나
/// 시스템에서 읽습니다. 우리가 적어 둔 값을 믿으면 실제와 어긋난 채로 남습니다.
public struct SMAppServiceLoginItem: LoginItemManaging {
    public init() {}

    public var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        default: return .off
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// 설정창의 '로그인 시 자동 실행' 칸이 보는 상태.
///
/// 요청이 먹었다고 가정하지 않습니다. 등록을 시도한 뒤 시스템에 다시 물어서 그 답을 보여줍니다.
/// 서명되지 않은 빌드에서는 등록이 거부될 수 있는데, 그때 칸만 켜져 있으면 거짓말이 됩니다.
@MainActor
public final class LoginItemToggle: ObservableObject {
    @Published public private(set) var state: LoginItemState

    /// 마지막 시도가 실패했다면 그 이유. 성공하면 지웁니다.
    @Published public private(set) var failure: String?

    /// 칸을 켜 둘지. 승인 대기도 켜 둡니다 — 등록 자체는 받아들여졌습니다.
    public var isOn: Bool { state != .off }

    /// 사용자가 시스템 설정에서 켜 줘야 하는지.
    public var needsApproval: Bool { state == .needsApproval }

    private let service: any LoginItemManaging

    public init(service: any LoginItemManaging = SMAppServiceLoginItem()) {
        self.service = service
        self.state = service.state
    }

    /// 시스템 설정에서 바뀌었을 수 있으므로 창을 열 때마다 다시 읽습니다.
    public func refresh() {
        state = service.state
    }

    public func set(_ wanted: Bool) {
        do {
            try service.setEnabled(wanted)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
        state = service.state
    }
}
